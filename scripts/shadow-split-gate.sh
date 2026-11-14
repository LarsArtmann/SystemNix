#!/usr/bin/env bash
# Shadow-split deploy gate (pre-deploy §18; storage.md ready row 1).
#
# A hot-tier mount landing over a NON-empty service data dir must be caught
# BEFORE the switch: wave 6 (entries.postgres, 2026-10-19 04:37) mounted an
# EMPTY /hot/postgres over live /var/lib/postgresql, PG initdb'd a blank
# cluster, and four co-tenant DBs ran empty for 2.5 days undetected
# (docs/status/2026-10-21_01-55_immich-wizard-pg-cluster-shadow-split.md).
#
# For every hot entry in the to-be-deployed config the gate first asks
# whether the shadow path (the path the subvolume will mount over) is
# ALREADY a live mountpoint — because a content probe through a live
# mount reads the SUBVOL through the mount and compares it to itself:
#   mounted, fsroot == declared subvol
#                       -> PASS — the subvol is demonstrably serving; the
#                          shadow dir is hidden beneath the mount and no
#                          content probe applies (before 2026-11-14 every
#                          steady-state line was a self-comparison PASS
#                          that read like "data on both disks")
#   mounted from a foreign fsroot
#                       -> FAIL (data class) / WARN (cache class) —
#                          something other than the declared subvol covers
#                          the service path; investigate before deploying
#   automount stack whose backing does not resolve (trigger + re-probe)
#                       -> WARN — hot root detached / backing broken;
#                          cannot-verify != verified-safe
#   NOT mounted          -> the wave-6 ladder against the REAL shadow dir
#                          (the only state where it has signal):
#   shadow empty/absent                  -> PASS (fresh service, nothing to lose)
#   shadow non-empty + subvol EMPTY      -> FAIL (data class) / WARN (cache class)
#                                           — the exact wave-6 signature
#   shadow PG_VERSION present, subvol's  -> FAIL (prepared copy absent)
#   missing
#   subvol non-empty but far smaller     -> WARN (parity band; live writes
#                                           between prepare and switch are
#                                           normal, so bands not equality)
#   probes unreadable (EACCES, no sudo)  -> WARN + manual recipe (cannot
#                                           verify != verified safe, but
#                                           also not proof of danger)
#   subvol dir missing                   -> WARN (mount fails fast+loud at
#                                           activation by module design —
#                                           service-down, not data-loss);
#                                           STRICT entries (nofail mounts,
#                                           today: the ~/projects subvol)
#                                           FAIL instead — their activation
#                                           does NOT fail, so §18 is the
#                                           only thing standing between a
#                                           pre-prepare deploy and a dead
#                                           mount over the only live copy
#
# Enumeration sources (all via nix eval on the pinned config; host override:
# SS_HOST):
#   services.hot-user-caches.caches       (class cache — automounts)
#   services.hot-db.entries               (class data — required mounts)
#   fileSystems."/home/lars/projects"     (class data, STRICT — the 2026-10-28
#                                          projects Samsung subvol; emitted
#                                          only while the mount is declared)
# Test hooks (fixtures set ALL of them; production never does):
#   SS_ENTRIES_JSON  inline entries document instead of nix eval
#   SS_SHADOW_ROOT   prefix for shadow paths (default "")
#   SS_HOT_ROOT      prefix for subvol paths  (default /mnt/hot)
#   SS_MOUNTS_FILE   space-separated mount table "target fstype source fsroot"
#                    replacing the findmnt probe (fixtures simulate
#                    mounted/foreign/automount states; production never sets it)
#   SS_PRIV          privilege prefix for root-owned probes (existence,
#                    readability, du, find — ALL of them); default
#                    auto-detects `sudo -n` and falls back to "" — the
#                    owner's interactive deploy shell has the ticket, bare
#                    agent shells degrade to WARN verdicts by design.
#
# Exit codes: 0 = no FAIL verdicts · 1 = at least one FAIL · 2 = enumeration
# failed (caller decides warn-vs-fail; the §18 wrapper warns).
# Run: bash scripts/shadow-split-gate.sh
set -uo pipefail

SS_HOST="${SS_HOST:-evo-x2}"
SS_SHADOW_ROOT="${SS_SHADOW_ROOT:-}"
SS_HOT_ROOT="${SS_HOT_ROOT:-/mnt/hot}"
# Exported: the jq filter reads both through $ENV (shadowprefix + subvol join).
export SS_SHADOW_ROOT SS_HOT_ROOT

if [ -z "${SS_PRIV+x}" ]; then
  if sudo -n true 2>/dev/null; then
    SS_PRIV="sudo -n"
  else
    SS_PRIV=""
  fi
fi

FAILS=0
WARNS=0
PASSES=0

ss_fail() {
  FAILS=$((FAILS + 1))
  echo "FAIL: $*"
}
ss_warn() {
  WARNS=$((WARNS + 1))
  echo "WARN: $*"
}
ss_pass() {
  PASSES=$((PASSES + 1))
  echo "PASS: $*"
}

# dir_size <path> -> echoes "bytes files" or "unknown unknown" when unreadable
dir_size() {
  local dir="$1"
  # The existence test runs through $SS_PRIV too: root-owned 0700 parents
  # (the DynamicUser /var/lib/private/* trees) make an unprivileged -d false
  # for a dir that EXISTS — if only the du leg is privileged, a live sudo
  # ticket never reaches the probe and the "re-run with a sudo ticket"
  # recipe can never clear the WARN (2026-11-13: browser-history/gatus
  # warned WITH a working ticket for exactly this reason).
  if ! $SS_PRIV test -d "$dir" 2>/dev/null; then
    # Permission-shaped absence: an unreadable PARENT makes -d false for a
    # dir that exists (root-owned 700 trees like /var/lib/private/*). Report
    # unknown, never absent, when the parent cannot be read — including by
    # the privilege prefix (a dead mid-run ticket degrades to WARN, by
    # design). Under a WORKING prefix the -r fallback is always true, so a
    # genuinely absent dir reports absent (root's -d is authoritative).
    local parent
    parent=$(dirname "$dir")
    if [ -d "$parent" ] && [ ! -r "$parent" ] && ! $SS_PRIV test -r "$parent" 2>/dev/null; then
      echo "unknown unknown"
    else
      echo "absent absent"
    fi
    return 0
  fi
  local out
  if out=$($SS_PRIV du -sb "$dir" 2>/dev/null) && [ -n "$out" ]; then
    local bytes
    bytes=${out%%$'\t'*}
    local count
    count=$($SS_PRIV find "$dir" -xdev -mindepth 1 2>/dev/null | wc -l | tr -d ' ')
    echo "$bytes $count"
  else
    echo "unknown unknown"
  fi
}

# mount_rows <path> [phase] -> one "fstype source fsroot" line per mount
# whose TARGET is exactly <path> (an automounted path legitimately yields
# TWO rows: the autofs mount plus the real fs it triggers). Test hook:
# SS_MOUNTS_FILE replaces findmnt with a space-separated table — same
# output shape, no findmnt dependency inside the Nix sandbox. Rows whose
# target is prefixed "after:" belong to phase 2 (post-trigger): they model
# a backing fs that only becomes visible once the automount is triggered,
# which a static table otherwise cannot express.
# NOTE: no awk here on purpose — unit scripts must list every binary they
# exec, and awk has caused two phantom-green incidents (storage.md
# 2026-08-18 findings) when it silently went missing.
mount_rows() {
  local path="$1" phase="${2:-1}"
  if [ -n "${SS_MOUNTS_FILE:-}" ]; then
    local target fstype source fsroot
    while read -r target fstype source fsroot; do
      [ -n "$target" ] || continue
      if [ "${target#after:}" != "$target" ]; then
        [ "$phase" = "2" ] || continue
        target="${target#after:}"
      fi
      [ "$target" = "$path" ] || continue
      printf '%s %s %s\n' "$fstype" "$source" "$fsroot"
    done < "$SS_MOUNTS_FILE"
  else
    # Loud, not silent: a missing findmnt would make every mount-state
    # probe return empty and silently degrade to the shadow ladder —
    # the exact phantom-green class storage.md 2026-08-18 documents.
    if ! command -v findmnt >/dev/null 2>&1; then
      echo "ERROR: findmnt not available — cannot probe mount state" >&2
      exit 2
    fi
    findmnt -n -o FSTYPE,SOURCE,FSROOT "$path" 2>/dev/null || true
  fi
}

emit_entry_verdict() {
  # $1 class (data|cache) · $2 name · $3 shadow dir · $4 subvol dir
  # $5 strict ("true" for nofail mounts — missing subvol FAILs, see header)
  local class="$1" name="$2" shadow="$3" subvol="$4" strict="${5:-false}"

  # Mount-state prelude: if the shadow path is already a live mountpoint,
  # every content probe below would read the SUBVOL through the mount and
  # compare it to itself — so judge the mount itself instead (fsroot match
  # against the declared subvol path, device-independent) and only fall
  # through to the shadow ladder when nothing is mounted there.
  local rel="${subvol#"$SS_HOT_ROOT"}"
  local rows
  rows=$(mount_rows "$shadow")
  if [ -n "$rows" ]; then
    local fstype source fsroot matched=false matched_src="" autofs=false first_src="" first_fsroot=""
    while read -r fstype source fsroot; do
      [ -n "${fstype:-}" ] || continue
      if [ -z "$first_src" ]; then first_src="$source"; first_fsroot="$fsroot"; fi
      if [ "$fstype" = "autofs" ] || [ "$source" = "systemd-1" ]; then autofs=true; fi
      if [ "$fsroot" = "$rel" ]; then matched=true; matched_src="$source"; fi
    done <<<"$rows"
    if [ "$matched" = true ]; then
      ss_pass "$class/$name: $shadow is live-mounted on the declared hot-tier subvol (fsroot $rel, source $matched_src) — shadow dir hidden beneath the mount, no shadow-split exposure"
      return 0
    fi
    if [ "$autofs" = true ]; then
      # Automount stack whose real fs is not visible yet: trigger it (any
      # lookup through the autofs mounts the backing fs) and re-probe once
      # (phase 2 in fixture tables: rows marked "after:").
      $SS_PRIV test -d "$shadow" 2>/dev/null || true
      while read -r fstype source fsroot; do
        if [ "${fsroot:-}" = "$rel" ]; then matched=true; matched_src="$source"; fi
      done <<<"$(mount_rows "$shadow" 2)"
      if [ "$matched" = true ]; then
        ss_pass "$class/$name: $shadow is automounted on the declared hot-tier subvol (fsroot $rel, source $matched_src) — shadow dir hidden beneath the mount, no shadow-split exposure"
        return 0
      fi
      ss_warn "$class/$name: automount present at $shadow but the backing mount did not resolve to $subvol — hot root detached or backing broken; verify by hand before deploying"
      return 0
    fi
    if [ "$class" = "data" ]; then
      ss_fail "$class/$name: shadow path $shadow is mounted from $first_src (fsroot $first_fsroot), NOT the declared hot subvol $rel — a foreign mount covers the service path; investigate/unmount before deploying"
    else
      ss_warn "$class/$name: shadow path $shadow is mounted from $first_src (fsroot $first_fsroot), NOT the declared hot subvol $rel — cache class (regenerable), still a foreign mount over the cache path"
    fi
    return 0
  fi

  local s_bytes s_count
  read -r s_bytes s_count <<<"$(dir_size "$shadow")"
  if [ "$s_bytes" = "absent" ]; then
    ss_pass "$class/$name: shadow $shadow absent or empty — nothing to shadow-split"
    return 0
  fi
  if [ "$s_bytes" = "unknown" ]; then
    ss_warn "$class/$name: shadow $shadow unreadable (no privilege ticket) — verify by hand: prepare-state record + subvol parity, then re-run with a sudo ticket"
    return 0
  fi
  if [ "$s_count" = "0" ] || [ "$s_bytes" = "0" ]; then
    ss_pass "$class/$name: shadow $shadow empty (0 files) — fresh-service shape"
    return 0
  fi

  if [ ! -d "$subvol" ]; then
    if [ "$strict" = "true" ]; then
      ss_fail "$class/$name: STRICT entry — shadow $shadow holds $s_count files but the subvol $subvol does not exist yet AND the mount is nofail (activation will NOT fail; the deploy would ship a dead mount + fail-loud writers over the only live copy). Fix: run the migrate prepare phase (scripts/migrate-projects-subvol.sh) so the subvol demonstrably holds the copy, then deploy"
      return 0
    fi
    ss_warn "$class/$name: subvol dir $subvol MISSING while shadow $shadow holds $s_count files — the mount will fail fast+loud at activation (module design), but the entry is half-provisioned"
    return 0
  fi
  local v_bytes v_count
  read -r v_bytes v_count <<<"$(dir_size "$subvol")"
  if [ "$v_bytes" = "unknown" ]; then
    ss_warn "$class/$name: subvol $subvol unreadable — verify by hand (state record + parity) before deploying"
    return 0
  fi

  if [ "$v_count" = "0" ] || [ "$v_bytes" = "0" ]; then
    if [ "$class" = "data" ]; then
      ss_fail "$class/$name: WAVE-6 SIGNATURE — shadow $shadow holds $s_count files ($s_bytes bytes) but target subvol $subvol is EMPTY; switching now shadow-splits live service data onto a blank subvol (incident: docs/status/2026-10-21_01-55_immich-wizard-pg-cluster-shadow-split.md). Fix: run the prepare/cutover step so the subvol demonstrably holds the copy, then deploy"
    else
      ss_warn "$class/$name: shadow $shadow holds $s_count files but target subvol $subvol is EMPTY — cache class (regenerable), still the wave-6 shape: run the prepare step or expect re-churn"
    fi
    return 0
  fi

  if [ -e "$shadow/PG_VERSION" ]; then
    if [ ! -e "$subvol/PG_VERSION" ]; then
      ss_fail "$class/$name: shadow carries PG_VERSION but subvol $subvol does NOT — a postgres cluster was never copied into the subvol; switching mounts a foreign/empty cluster over the live one"
      return 0
    fi
  fi

  if [ "$v_bytes" -lt $((s_bytes / 4)) ]; then
    ss_warn "$class/$name: subvol $subvol ($v_bytes bytes) is <25% of shadow $shadow ($s_bytes bytes) — either the prepare ran long ago (live writes since) or the copy is incomplete; check the state record + biggest-file floor"
  else
    ss_pass "$class/$name: shadow $shadow (${s_count} files) and subvol $subvol ($v_bytes bytes) both populated — prepared-copy shape holds"
  fi
}

collect_entries() {
  local doc
  if [ -n "${SS_ENTRIES_JSON:-}" ]; then
    doc="$SS_ENTRIES_JSON"
  else
    local uc_enable hdb_enable uc hdb proj_mount proj_armed
    uc_enable=$(nix eval --json ".#nixosConfigurations.$SS_HOST.config.services.hot-user-caches.enable" 2>/dev/null || echo "null")
    hdb_enable=$(nix eval --json ".#nixosConfigurations.$SS_HOST.config.services.hot-db.enable" 2>/dev/null || echo "null")
    uc=$(nix eval --json ".#nixosConfigurations.$SS_HOST.config.services.hot-user-caches.caches" 2>/dev/null || echo "{}")
    hdb=$(nix eval --json ".#nixosConfigurations.$SS_HOST.config.services.hot-db.entries" 2>/dev/null || echo "{}")
    # Third source (2026-10-28 projects-subvol plan D4): the ~/projects
    # Samsung subvol — emitted only while the mount is declared, so the
    # gate is automatically blind again if the mount is ever removed.
    proj_mount=$(nix eval --json ".#nixosConfigurations.$SS_HOST.config.fileSystems.\"/home/lars/projects\".fsType" 2>/dev/null || echo "null")
    if [ "${proj_mount:-null}" != "null" ]; then proj_armed=true; else proj_armed=false; fi
    doc=$(printf '{"ucEnable":%s,"hdbEnable":%s,"uc":%s,"hdb":%s,"projectsMount":%s}\n' \
      "${uc_enable:-null}" "${hdb_enable:-null}" "$uc" "$hdb" "$proj_armed")
  fi
  # Single stdin-form jq (direnv shells misparse file-argument jq — AGENTS.md
  # 2026-10-17); emit one TSV row {class,name,shadow,subvol,strict} per
  # enabled entry.
  printf '%s' "$doc" | jq -r '
    def shadowprefix: if $ENV.SS_SHADOW_ROOT == "" then "" else $ENV.SS_SHADOW_ROOT end;
    (if .ucEnable == true then
       .uc | to_entries[] | {class: "cache", name: .key, shadow: (shadowprefix + .value.mountPoint), subvol: ($ENV.SS_HOT_ROOT + "/" + .value.subvol), strict: false}
     else empty end),
    (if .hdbEnable == true then
       .hdb | to_entries[] | {class: "data", name: .key, shadow: (shadowprefix + .value.path), subvol: ($ENV.SS_HOT_ROOT + "/hot/" + .key), strict: false}
     else empty end),
    (if .projectsMount == true then
       {class: "data", name: "projects", shadow: (shadowprefix + "/home/lars/projects"), subvol: ($ENV.SS_HOT_ROOT + "/users/lars/projects"), strict: true}
     else empty end)
    | [.class, .name, .shadow, .subvol, .strict]
    | @tsv'
}

main() {
  local entries
  if ! entries=$(collect_entries); then
    echo "ERROR: entry enumeration failed (nix eval / jq)" >&2
    exit 2
  fi
  if [ -z "$entries" ]; then
    echo "PASS: no enabled hot-tier entries in the to-be-deployed config — nothing to shadow-split"
    exit 0
  fi
  while IFS=$'\t' read -r class name shadow subvol strict; do
    [ -n "$class" ] || continue
    emit_entry_verdict "$class" "$name" "$shadow" "$subvol" "${strict:-false}"
  done <<<"$entries"

  echo "shadow-split gate: $PASSES passed, $WARNS warned, $FAILS failed"
  if [ "$FAILS" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main
