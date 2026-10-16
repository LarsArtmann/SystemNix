#!/usr/bin/env bash
# display-manager-heal — recognize session states that make display-manager
# logins fail, auto-fix the safe ones, and report the rest with the exact
# manual fix (What / Reassure / Why / Fix / Escape).
#
# Hooked into:
#   * display-manager.service ExecStartPre — every (re)start of the greeter
#   * sddm PAM auth phase — every login attempt, before the session starts
# Manual run: display-manager-heal [--storm-threshold N]
#
# Never fails the caller (exit 0 except on bad arguments): a heal hook must
# never block the greeter or a login. All findings go to the journal and,
# for heal/warn events, to every active terminal via wall.
set -euo pipefail

users=()
units=()
storm_threshold=50

while [[ $# -gt 0 ]]; do
	case "$1" in
	--user)
		users+=("$2")
		shift 2
		;;
	--unit)
		units+=("$2")
		shift 2
		;;
	--storm-threshold)
		storm_threshold="$2"
		shift 2
		;;
	*)
		printf 'display-manager-heal: unknown argument %s\n' "$1" >&2
		exit 2
		;;
	esac
done

note() {
	printf '[display-manager-heal] %s\n' "$*"
}

warn() {
	note "WARN: $*"
}

broadcast() {
	# Best-effort feedback to every active terminal (SSH/TTY). Never fatal.
	wall "$1" >/dev/null 2>&1 || true
}

graphical_session_of() {
	local user="$1"
	loginctl list-sessions --no-legend 2>/dev/null |
		awk -v u="$user" '$3 == u && $4 != "-" { print $1; exit }' || true
}

user_manager_running() {
	local uid="$1"
	[[ -d "/run/user/$uid" ]]
}

unit_active() {
	local uid="$1" unit="$2"
	XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user --quiet is-active "$unit" >/dev/null 2>&1
}

unit_stop() {
	local uid="$1" unit="$2"
	XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user --job-timeout=8s stop "$unit" >/dev/null 2>&1
}

check_restore_storm() {
	local user="$1" home="$2" file windows
	file="$home/.local/share/niri-session-manager/session.json"
	[[ -n $home && -r $file ]] || return 0
	windows="$(jq -r '.windows | length // 0' "$file" 2>/dev/null || true)"
	[[ $windows =~ ^[0-9]+$ ]] || windows=0
	if ((windows > storm_threshold)); then
		warn "niri-session-manager session.json holds $windows saved windows (threshold $storm_threshold) — the next login may spawn a restore storm. Reassure: your session file is not touched automatically. Why: the manager re-saves every 15 min and falls back to session-*.bak, so a poisoned file self-perpetuates. Fix: review with jq -c '.windows[] | .app_id' '$file' and clean up BEFORE relying on a restore. Escape: logins still work; only the restore step misbehaves."
	fi
}

heal_user() {
	local user="$1" uid home graphical unit
	uid="$(id -u "$user" 2>/dev/null || true)"
	if [[ -z $uid ]]; then
		note "user '$user' does not exist — skipping"
		return 0
	fi
	home="$(getent passwd "$user" 2>/dev/null | cut -d: -f6 || true)"

	graphical="$(graphical_session_of "$user")"
	if [[ -n $graphical ]]; then
		note "user '$user' has an active graphical session ($graphical) — live session, leaving user units untouched"
		check_restore_storm "$user" "$home"
		return 0
	fi

	if ! user_manager_running "$uid"; then
		note "user '$user': no lingering session manager (/run/user/$uid absent) — nothing to heal"
		return 0
	fi

	local stale=()
	for unit in "${units[@]}"; do
		if unit_active "$uid" "$unit"; then
			stale+=("$unit")
		fi
	done

	if [[ ${#stale[@]} -eq 0 ]]; then
		note "user '$user': no stale session units — nothing to heal"
		check_restore_storm "$user" "$home"
		return 0
	fi

	# What + Why + Reassure before acting
	note "user '$user': stale headless session unit(s): ${stale[*]}"
	note "Why this blocks logins: a compositor running without a logind seat makes niri-session reject every new login with 'A niri session is already running'. Reassure: nothing visible is lost — the stale session has no outputs; saved windows restore at the next login. Stopping explicitly (an explicit stop does not trip Restart=on-failure; kill -9 would resurrect them headless)."

	for unit in "${stale[@]}"; do
		unit_stop "$uid" "$unit" || true
	done
	XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user reset-failed >/dev/null 2>&1 || true

	local survivors=()
	for unit in "${stale[@]}"; do
		if unit_active "$uid" "$unit"; then
			survivors+=("$unit")
		fi
	done

	if [[ ${#survivors[@]} -eq 0 ]]; then
		note "Healed: stopped ${stale[*]} for '$user' — logins will work again. Verify: journalctl -u display-manager | grep display-manager-heal"
		broadcast "display-manager-heal: fixed a stale graphical session for '$user' (stopped ${stale[*]}) — logins work again; no visible state was lost"
	else
		warn "Could not stop ${survivors[*]} for '$user' — the next login may bounce back to the greeter. Fix (do NOT kill -9: SIGKILL counts as a failure and Restart=on-failure resurrects them headless): sudo XDG_RUNTIME_DIR=/run/user/$uid systemctl --user stop ${survivors[*]}. Escape: the greeter stays up either way; only the login step is affected."
		broadcast "display-manager-heal: could not fix a stale graphical session for '$user' (${survivors[*]}) — see journalctl -u display-manager for the manual fix"
	fi

	check_restore_storm "$user" "$home"
}

if [[ ${#users[@]} -eq 0 ]]; then
	note "no users configured — nothing to do"
	exit 0
fi

for user in "${users[@]}"; do
	heal_user "$user"
done

exit 0
