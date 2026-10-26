#!/usr/bin/env bash
# Shadow-split deploy gate (pre-deploy §18; storage.md ready row 1).
#
# A hot-tier mount landing over a NON-empty service data dir must be caught
# BEFORE the switch: wave 6 (entries.postgres, 2026-10-19 04:37) mounted an
# EMPTY /hot/postgres over live /var/lib/postgresql, PG initdb'd a blank
# cluster, and four co-tenant DBs ran empty for 2.5 days undetected
# (docs/status/2026-10-21_01-55_immich-wizard-pg-cluster-shadow-split.md).
#
# For every hot entry in the to-be-deployed config this gate checks the
# live shadow dir (the path the subvolume will mount over) against the
# target subvol content:
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
#                                           service-down, not data-loss)
#
# Enumeration reads the pinned config via nix eval (host override: SS_HOST).
# Test hooks (fixtures set ALL of them; production never does):
#   SS_ENTRIES_JSON  inline entries document instead of nix eval
#   SS_SHADOW_ROOT   prefix for shadow paths (default "")
#   SS_HOT_ROOT      prefix for subvol paths  (default /mnt/hot)
#   SS_PRIV          privilege prefix for root-owned probes; default
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
  if [ ! -d "$dir" ]; then
    # Permission-shaped absence: an unreadable PARENT makes -d false for a
    # dir that exists (root-owned 700 trees like /var/lib/private/*). Report
    # unknown, never absent, when the parent cannot be read.
    local parent
    parent=$(dirname "$dir")
    if [ -d "$parent" ] && [ ! -r "$parent" ]; then
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

emit_entry_verdict() {
  # $1 class (data|cache) · $2 name · $3 shadow dir · $4 subvol dir
  local class="$1" name="$2" shadow="$3" subvol="$4"
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
    local uc_enable hdb_enable uc hdb
    uc_enable=$(nix eval --json ".#nixosConfigurations.$SS_HOST.config.services.hot-user-caches.enable" 2>/dev/null || echo "null")
    hdb_enable=$(nix eval --json ".#nixosConfigurations.$SS_HOST.config.services.hot-db.enable" 2>/dev/null || echo "null")
    uc=$(nix eval --json ".#nixosConfigurations.$SS_HOST.config.services.hot-user-caches.caches" 2>/dev/null || echo "{}")
    hdb=$(nix eval --json ".#nixosConfigurations.$SS_HOST.config.services.hot-db.entries" 2>/dev/null || echo "{}")
    doc=$(printf '{"ucEnable":%s,"hdbEnable":%s,"uc":%s,"hdb":%s}\n' \
      "${uc_enable:-null}" "${hdb_enable:-null}" "$uc" "$hdb")
  fi
  # Single stdin-form jq (direnv shells misparse file-argument jq — AGENTS.md
  # 2026-10-17); emit one TSV row {class,name,shadow,subvol} per enabled entry.
  printf '%s' "$doc" | jq -r '
    def shadowprefix: if $ENV.SS_SHADOW_ROOT == "" then "" else $ENV.SS_SHADOW_ROOT end;
    (if .ucEnable == true then
       .uc | to_entries[] | {class: "cache", name: .key, shadow: (shadowprefix + .value.mountPoint), subvol: ($ENV.SS_HOT_ROOT + "/" + .value.subvol)}
     else empty end),
    (if .hdbEnable == true then
       .hdb | to_entries[] | {class: "data", name: .key, shadow: (shadowprefix + .value.path), subvol: ($ENV.SS_HOT_ROOT + "/hot/" + .key)}
     else empty end
    )
    | [.class, .name, .shadow, .subvol]
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
  while IFS=$'\t' read -r class name shadow subvol; do
    [ -n "$class" ] || continue
    emit_entry_verdict "$class" "$name" "$shadow" "$subvol"
  done <<<"$entries"

  echo "shadow-split gate: $PASSES passed, $WARNS warned, $FAILS failed"
  if [ "$FAILS" -gt 0 ]; then
    exit 1
  fi
  exit 0
}

main
