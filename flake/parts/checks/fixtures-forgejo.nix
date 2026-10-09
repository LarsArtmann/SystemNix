# Behavioral fixtures for the forgejo staged-primary scripts and subvol
# migration (stubbed curl/gh/sqlite3 harnesses; see the original comments).
# Split out of flake.nix 2026-10-08.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    {
      checks = {
        # Behavioral fixture tests for the forgejo staged-primary
        # scripts (plan M05/M06/M07): push-mirror attach, repo flip,
        # dead-mirror notice parsing. The scripts are
        # writeShellApplication outputs, whose runtimeInputs dirs sit
        # FIRST on PATH — plain PATH stubs CANNOT shadow them (the
        # DMS lesson). Fixtures therefore copy each wrapper and
        # sed-inject a stub dir at the FRONT of its PATH line.
        forgejo-scripts-fixture =
          let
            forgejoScripts = import (root + "/modules/nixos/services/_forgejo-scripts.nix") {
              inherit pkgs lib;
              config = {
                services = { };
              };
              primaryUser = "lars";
              cfg = {
                sshKeys = { };
              };
              forgejoPkg = pkgs.hello;
              forgejoUrl = "http://localhost:3000";
              stateDir = "/var/lib/forgejo";
              hostName = "fixture";
              runnerLabels = [ ];
              runnerConfigFile = pkgs.writeText "runner-config" "";
            };
          in
          pkgs.runCommand "forgejo-scripts-fixture"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils
                gnused
                gnugrep
                jq
              ];
            }
            ''
              set -euo pipefail
              FIX=$(mktemp -d)
              STUB_BIN="$FIX/stub-bin"; mkdir -p "$STUB_BIN"
              STUB_HTTP="$FIX/http"; mkdir -p "$STUB_HTTP"
              STUB_STATE="$FIX/state"; mkdir -p "$STUB_STATE"
              export STUB_HTTP STUB_STATE

              # ---- curl stub: METHOD+URL keyed responses under
              # $STUB_HTTP; per-key sequential counters serve
              # stateful scenarios (repo state changes across a flip).
              cat > "$STUB_BIN/curl" <<'STUBEOF'
              #!${pkgs.bash}/bin/bash
              method=GET; url=; out=; wcode=; data=; fail=0; payload=
              while [ $# -gt 0 ]; do
                case "$1" in
                  -X) method="$2"; shift 2 ;;
                  -o) out="$2"; shift 2 ;;
                  -w) wcode="$2"; shift 2 ;;
                  -d) data=1; payload="$2"; shift 2 ;;
                  -sf|-s|-f|-k|-L|--compressed) case "$1" in *f*) fail=1;; esac; shift ;;
                  -H|--connect-timeout|--max-time) shift 2 ;;
                  http*) url="$1"; shift ;;
                  *) shift ;;
                esac
              done
              [ -n "$data" ] && [ "$method" = GET ] && method=POST
              key=$(printf '%s' "$url" | sed 's|https\{0,1\}://||; s|[^A-Za-z0-9._-]|_|g')
              base="$STUB_HTTP/''${key}.''${method}"
              n=0
              [ -f "$STUB_STATE/n.''${key}.''${method}" ] && n=$(cat "$STUB_STATE/n.''${key}.''${method}")
              n=$((n + 1)); echo "$n" > "$STUB_STATE/n.''${key}.''${method}"
              printf '%s' "''${payload:-}" > "$STUB_STATE/req.''${key}.''${method}.$n.json"
              code_file=""; body_file=""
              if [ -f "$base.$n.code" ]; then code_file="$base.$n.code"; body_file="$base.$n.body"
              elif [ -f "$base.code" ]; then code_file="$base.code"; body_file="$base.body"
              fi
              code=404
              [ -n "$code_file" ] && code=$(cat "$code_file")
              if [ "$code" -ge 400 ] && [ "$fail" = 1 ]; then exit 22; fi
              if [ -n "$out" ]; then [ -n "$body_file" ] && cat "$body_file" > "$out"
              elif [ -z "$wcode" ]; then [ -n "$body_file" ] && cat "$body_file"
              fi
              [ -n "$wcode" ] && printf '%s' "$code"
              exit 0
              STUBEOF
              chmod +x "$STUB_BIN/curl"

              # ---- gh stub: serves $STUB_HTTP/gh_<sanitized>.body
              cat > "$STUB_BIN/gh" <<'STUBEOF'
              #!${pkgs.bash}/bin/bash
              [ "''${1:-}" = "api" ] || { echo "gh stub: only api" >&2; exit 1; }
              key=gh_$(printf '%s' "''${2:-}" | sed 's|[^A-Za-z0-9._-]|_|g')
              if [ -f "$STUB_HTTP/$key.body" ]; then cat "$STUB_HTTP/$key.body"; exit 0; fi
              echo '{"message":"Not Found"}'
              exit 1
              STUBEOF
              chmod +x "$STUB_BIN/gh"

              # ---- sqlite3 stub: cats $STUB_SQLITE_OUT (env)
              cat > "$STUB_BIN/sqlite3" <<'STUBEOF'
              #!${pkgs.bash}/bin/bash
              [ -n "''${STUB_SQLITE_OUT:-}" ] && [ -f "$STUB_SQLITE_OUT" ] && cat "$STUB_SQLITE_OUT"
              exit 0
              STUBEOF
              chmod +x "$STUB_BIN/sqlite3"

              # PATH-inject the stub dir into a copy of a
              # writeShellApplication wrapper (runtimeInputs dirs
              # come first in the original PATH line).
              inject() {
                cp "$1" "$2"
                sed -i 's#^export PATH="#export PATH="'"$STUB_BIN"':#' "$2"
                chmod +x "$2"
              }
              PUSH="$FIX/forgejo-push-mirror"
              FLIP="$FIX/forgejo-flip-repo"
              MIRROR="$FIX/forgejo-mirror-github"
              RECON="$FIX/forgejo-reconcile-mirrors"
              HEALTH="$FIX/forgejo-mirror-health"
              CENSUS="$FIX/forgejo-census"
              inject ${lib.getExe forgejoScripts.pushMirrorScript} "$PUSH"
              inject ${lib.getExe forgejoScripts.flipRepoScript} "$FLIP"
              inject ${lib.getExe forgejoScripts.mirrorGithubScript} "$MIRROR"
              inject ${lib.getExe forgejoScripts.reconcileMirrorsScript} "$RECON"
              inject ${lib.getExe forgejoScripts.mirrorHealthScript} "$HEALTH"
              inject ${lib.getExe forgejoScripts.censusScript} "$CENSUS"

              export FORGEJO_TOKEN=fxtok GITHUB_TOKEN=gxtok GITHUB_USER=LarsArtmann
              rc=0; capt=""
              # NOTE: capture var is `capt` — `out` is RESERVED (the
              # derivation output path); shadowing it made the final
              # `echo PASS > "$out"` redirect into a garbage filename.
              run() { capt=$("$@" 2>&1) && rc=0 || rc=$?; }
              need_rc() { [ "$rc" = "$2" ] || { echo "FAIL $1: rc=$rc want $2"; printf '%s\n' "$capt"; exit 1; }; }
              need_has() { printf '%s\n' "$capt" | grep -qF "$2" || { echo "FAIL $1: missing text: $2"; printf '%s\n' "$capt"; exit 1; }; }

              # ============ push-mirror (M05) ============
              export FORGEJO_CANONICAL_REPOS="push-happy"
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy.GET.code"
              printf '{"mirror":false}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy.GET.body"
              printf '[]' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.GET.code"
              printf '[]' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.GET.body"
              printf 201 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.POST.code"
              run "$PUSH"; need_rc push-happy 0; need_has push-happy "push mirror attached"
              # The M05 lesson, asserted: the POST MUST carry the
              # interval field (the old code 400'd 18/18 without it).
              grep -q '"interval": "8h"' "$STUB_STATE/req.localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.POST.1.json" \
                || { echo "FAIL push-happy: POST payload lacks interval 8h"; cat "$STUB_STATE/req.localhost_3000_api_v1_repos_lars_push-happy_push_mirrors.POST.1.json"; exit 1; }

              export FORGEJO_CANONICAL_REPOS="push-stuck"
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-stuck.GET.code"
              printf '{"mirror":true}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-stuck.GET.body"
              run "$PUSH"; need_rc push-stuck 1; need_has push-stuck "still a PULL mirror"

              export FORGEJO_CANONICAL_REPOS="push-done"
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-done.GET.code"
              printf '{"mirror":false}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-done.GET.body"
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-done_push_mirrors.GET.code"
              printf '[{"id":1}]' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-done_push_mirrors.GET.body"
              run "$PUSH"; need_rc push-done 0; need_has push-done "already attached"

              export FORGEJO_CANONICAL_REPOS="push-ghost"
              printf 404 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_push-ghost.GET.code"
              run "$PUSH"; need_rc push-ghost 1; need_has push-ghost "not found on forgejo"
              unset FORGEJO_CANONICAL_REPOS

              # ============ flip (M06) ============
              BASE=gh_repos_LarsArtmann_flip-pilot.body
              printf '{"default_branch":"main","open_issues_count":3,"private":true,"description":"d"}' > "$STUB_HTTP/$BASE"
              FJ=localhost_3000_api_v1_repos_lars_flip-pilot
              # 3 sequential GET states: dry-run precondition (mirror),
              # happy-run precondition (mirror), post-migrate (native).
              printf 200 > "$STUB_HTTP/$FJ.GET.1.code"
              printf '{"owner":{"login":"lars"},"mirror":true}' > "$STUB_HTTP/$FJ.GET.1.body"
              printf 200 > "$STUB_HTTP/$FJ.GET.2.code"
              printf '{"owner":{"login":"lars"},"mirror":true}' > "$STUB_HTTP/$FJ.GET.2.body"
              printf 200 > "$STUB_HTTP/$FJ.GET.3.code"
              printf '{"owner":{"login":"lars"},"mirror":false,"default_branch":"main","open_issues_count":3}' > "$STUB_HTTP/$FJ.GET.3.body"
              printf 204 > "$STUB_HTTP/$FJ.DELETE.1.code"
              MIG=localhost_3000_api_v1_repos_migrate.POST
              printf 201 > "$STUB_HTTP/$MIG.1.code"
              PM="$FJ"_push_mirrors
              printf 200 > "$STUB_HTTP/$PM.GET.1.code"; printf '[]' > "$STUB_HTTP/$PM.GET.1.body"
              printf 201 > "$STUB_HTTP/$PM.POST.1.code"
              printf 200 > "$STUB_HTTP/$PM.GET.2.code"; printf '[{"id":7}]' > "$STUB_HTTP/$PM.GET.2.body"

              run "$FLIP" flip-pilot --dry-run; need_rc flip-dry 0; need_has flip-dry "DRY RUN"
              run "$FLIP" flip-pilot; need_rc flip-happy 0; need_has flip-happy "FLIPPED flip-pilot"
              # sequential counters advanced by the dry-run's GETs: the
              # happy path consumed .2 for the repo GET — re-arm both
              # for the failure scenarios with fresh names.

              # refuse: native repo
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_flip-native.GET.1.code"
              printf '{"owner":{"login":"lars"},"mirror":false}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_flip-native.GET.1.body"
              run "$FLIP" flip-native; need_rc flip-native 1; need_has flip-native "NOT a pull mirror"

              # refuse: pending reconcile verdict
              RD="$FIX/reconcile"; mkdir -p "$RD"
              printf 'flip-pending\n' > "$RD/pending-deletes.txt"
              export FORGEJO_RECONCILE_STATE_DIR="$RD"
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_flip-pending.GET.1.code"
              printf '{"owner":{"login":"lars"},"mirror":true}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_flip-pending.GET.1.body"
              run "$FLIP" flip-pending; need_rc flip-pending 1; need_has flip-pending "pending reconcile verdict"
              unset FORGEJO_RECONCILE_STATE_DIR

              # mid-flip failure: migrate 422 AFTER the delete
              printf '{"default_branch":"main","open_issues_count":0,"private":false,"description":""}' \
                > "$STUB_HTTP/gh_repos_LarsArtmann_flip-mid.body"
              FJM=localhost_3000_api_v1_repos_lars_flip-mid
              printf 200 > "$STUB_HTTP/$FJM.GET.1.code"
              printf '{"owner":{"login":"lars"},"mirror":true}' > "$STUB_HTTP/$FJM.GET.1.body"
              printf 204 > "$STUB_HTTP/$FJM.DELETE.1.code"
              printf 422 > "$STUB_HTTP/localhost_3000_api_v1_repos_migrate.POST.2.code"
              run "$FLIP" flip-mid; need_rc flip-mid 1; need_has flip-mid "mirror already deleted"
              # the migrate POST counter advanced — the mirror section
              # below continues it at .3 (flip used .1/.2).

              # ============ mirror-github (org-inclusive, 2026-10-02) ============
              GH_USER_REPOS=api.github.com_user_repos_visibility_all_affiliation_owner_per_page_100_page_1.GET
              GH_ORGS=api.github.com_user_orgs_per_page_100_page_1.GET
              GH_ARTM=api.github.com_orgs_Artmann-Minecraft_repos_type_all_per_page_100_page_1.GET
              GH_FRESH=api.github.com_orgs_fresh-org_repos_type_all_per_page_100_page_1.GET
              MIGR=localhost_3000_api_v1_repos_migrate.POST

              printf 200 > "$STUB_HTTP/$GH_USER_REPOS.1.code"
              cat > "$STUB_HTTP/$GH_USER_REPOS.1.body" <<'JEOF'
              [{"name":"SystemNix","clone_url":"https://github.com/LarsArtmann/SystemNix","private":true,"description":"d"},{"name":"new-repo","clone_url":"https://github.com/LarsArtmann/new-repo","private":false,"description":""}]
              JEOF
              printf 200 > "$STUB_HTTP/$GH_ORGS.1.code"
              printf '[{"login":"Artmann-Minecraft"},{"login":"fresh-org"}]' > "$STUB_HTTP/$GH_ORGS.1.body"
              printf 200 > "$STUB_HTTP/$GH_ARTM.1.code"
              printf '[{"name":"DarkBlocks","clone_url":"https://github.com/Artmann-Minecraft/DarkBlocks","private":true,"description":"x"}]' > "$STUB_HTTP/$GH_ARTM.1.body"
              printf 200 > "$STUB_HTTP/$GH_FRESH.1.code"
              printf '[{"name":"org-repo","clone_url":"https://github.com/fresh-org/org-repo","private":true,"description":""}]' > "$STUB_HTTP/$GH_FRESH.1.body"

              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_user.GET.code"
              printf '{"id":1}' > "$STUB_HTTP/localhost_3000_api_v1_user.GET.body"
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_SystemNix.GET.code"
              printf '{"id":2,"mirror":true}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_SystemNix.GET.body"
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_orgs_Artmann-Minecraft.GET.code"
              printf '{"id":7}' > "$STUB_HTTP/localhost_3000_api_v1_orgs_Artmann-Minecraft.GET.body"
              printf 404 > "$STUB_HTTP/localhost_3000_api_v1_orgs_fresh-org.GET.1.code"
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_orgs_fresh-org.GET.2.code"
              printf '{"id":9}' > "$STUB_HTTP/localhost_3000_api_v1_orgs_fresh-org.GET.2.body"
              printf 201 > "$STUB_HTTP/localhost_3000_api_v1_orgs.POST.code"
              printf '{}' > "$STUB_HTTP/localhost_3000_api_v1_orgs.POST.body"
              printf 201 > "$STUB_HTTP/$MIGR.3.code"
              printf '{}' > "$STUB_HTTP/$MIGR.3.body"
              printf 201 > "$STUB_HTTP/$MIGR.4.code"
              printf '{}' > "$STUB_HTTP/$MIGR.4.body"
              printf 201 > "$STUB_HTTP/$MIGR.5.code"
              printf '{}' > "$STUB_HTTP/$MIGR.5.body"

              run "$MIRROR"; need_rc mirror-happy 0
              need_has mirror-happy "Already mirrored: lars/SystemNix"
              need_has mirror-happy "Created mirror: lars/new-repo"
              need_has mirror-happy "Created forgejo org: fresh-org"
              need_has mirror-happy "Created mirror: Artmann-Minecraft/DarkBlocks"
              need_has mirror-happy "Created mirror: fresh-org/org-repo"
              need_has mirror-happy "2 user + 2 org"
              # migrate payloads: user repo under uid 1, org repos under
              # the resolved org uids (7 / 9)
              grep -q '"uid": 1' "$STUB_STATE/req.$MIGR.3.json" || { echo "FAIL mirror: user migrate uid"; cat "$STUB_STATE/req.$MIGR.3.json"; exit 1; }
              grep -q '"uid": 7' "$STUB_STATE/req.$MIGR.4.json" || { echo "FAIL mirror: ArtM migrate uid"; cat "$STUB_STATE/req.$MIGR.4.json"; exit 1; }
              grep -q '"uid": 9' "$STUB_STATE/req.$MIGR.5.json" || { echo "FAIL mirror: fresh-org migrate uid"; cat "$STUB_STATE/req.$MIGR.5.json"; exit 1; }
              grep -q '"username": "fresh-org"' "$STUB_STATE/req.localhost_3000_api_v1_orgs.POST.1.json" \
                || { echo "FAIL mirror: org create payload"; cat "$STUB_STATE/req.localhost_3000_api_v1_orgs.POST.1.json"; exit 1; }

              # rate limit: non-array user listing dies loud
              printf 200 > "$STUB_HTTP/$GH_USER_REPOS.2.code"
              printf '{"message":"rate limited"}' > "$STUB_HTTP/$GH_USER_REPOS.2.body"
              run "$MIRROR"; need_rc mirror-rl 1; need_has mirror-rl "did not return an array"

              # org listing failure dies loud too
              printf 200 > "$STUB_HTTP/$GH_USER_REPOS.3.code"
              printf '[]' > "$STUB_HTTP/$GH_USER_REPOS.3.body"
              printf 200 > "$STUB_HTTP/$GH_ORGS.2.code"
              printf '{"message":"bad credentials"}' > "$STUB_HTTP/$GH_ORGS.2.body"
              run "$MIRROR"; need_rc mirror-orgfail 1; need_has mirror-orgfail "org listing"

              # ============ reconcile (pair-keyed, org-aware) ============
              export XDG_STATE_HOME="$FIX/xdgstate"; rm -rf "$XDG_STATE_HOME"; mkdir -p "$XDG_STATE_HOME"
              TF_R="$FIX/tfr"; mkdir -p "$TF_R"
              export FORGEJO_MIRROR_TEXTFILE_DIR="$TF_R"

              # unnumbered fallbacks for every listing key (numbered
              # .1-.3 consumed above; reconcile runs use .4+)
              printf 200 > "$STUB_HTTP/$GH_USER_REPOS.code"
              cat > "$STUB_HTTP/$GH_USER_REPOS.body" <<'JEOF'
              [{"owner":{"login":"LarsArtmann"},"name":"SystemNix"},{"owner":{"login":"LarsArtmann"},"name":"new-repo"},{"owner":{"login":"LarsArtmann"},"name":"renamed-repo"}]
              JEOF
              printf 200 > "$STUB_HTTP/$GH_ORGS.code"
              printf '[{"login":"Artmann-Minecraft"},{"login":"fresh-org"}]' > "$STUB_HTTP/$GH_ORGS.body"
              printf 200 > "$STUB_HTTP/$GH_ARTM.code"
              printf '[{"name":"DarkBlocks"}]' > "$STUB_HTTP/$GH_ARTM.body"
              # reconcile lowercases org logins for its namespace map, so
              # its canonical org-repos fetches hit the lowercase URL key
              printf 200 > "$STUB_HTTP/api.github.com_orgs_artmann-minecraft_repos_type_all_per_page_100_page_1.GET.code"
              printf '[{"name":"DarkBlocks"}]' > "$STUB_HTTP/api.github.com_orgs_artmann-minecraft_repos_type_all_per_page_100_page_1.GET.body"
              printf 200 > "$STUB_HTTP/$GH_FRESH.code"
              printf '[{"name":"org-repo"}]' > "$STUB_HTTP/$GH_FRESH.body"

              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_user_repos_limit_50_page_1.GET.code"
              cat > "$STUB_HTTP/localhost_3000_api_v1_user_repos_limit_50_page_1.GET.body" <<'JEOF'
              [
                {"owner":{"login":"lars"},"mirror":true,"name":"SystemNix"},
                {"owner":{"login":"lars"},"mirror":true,"name":"new-repo"},
                {"owner":{"login":"lars"},"mirror":true,"name":"renamed-repo"},
                {"owner":{"login":"lars"},"mirror":true,"name":"old-name"},
                {"owner":{"login":"lars"},"mirror":true,"name":"moved-repo"},
                {"owner":{"login":"Artmann-Minecraft"},"mirror":true,"name":"DarkBlocks"},
                {"owner":{"login":"Artmann-Minecraft"},"mirror":true,"name":"ghost-repo"},
                {"owner":{"login":"starred"},"mirror":true,"name":"stranger-repo"}
              ]
              JEOF
              printf 'LarsArtmann/renamed-repo' > "$STUB_HTTP/gh_repos_LarsArtmann_old-name.body"
              printf 'SomeOrg/moved-repo' > "$STUB_HTTP/gh_repos_LarsArtmann_moved-repo.body"
              printf '{"id":5,"mirror":true}' > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_old-name.GET.body"
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_old-name.GET.code"
              printf 204 > "$STUB_HTTP/localhost_3000_api_v1_repos_lars_old-name.DELETE.code"

              run "$RECON"; need_rc recon1 0
              need_has recon1 "rename confirmed (1st pass, will delete next run): LarsArtmann/old-name"
              need_has recon1 "archived: Artmann-Minecraft/ghost-repo"
              need_has recon1 "transferred: LarsArtmann/moved-repo (SomeOrg/moved-repo)"
              need_has recon1 "out-of-scope skipped"
              grep -q '^forgejo_mirror_total 7$' "$TF_R/forgejo_mirror_reconcile.prom" \
                || { echo "FAIL recon1: total 7"; cat "$TF_R/forgejo_mirror_reconcile.prom"; exit 1; }
              grep -q '^forgejo_mirror_org_mirrors 2$' "$TF_R/forgejo_mirror_reconcile.prom" \
                || { echo "FAIL recon1: org_mirrors 2"; exit 1; }
              grep -q '^forgejo_mirror_upstream_deleted_archived 1$' "$TF_R/forgejo_mirror_reconcile.prom" \
                || { echo "FAIL recon1: archived 1"; exit 1; }
              grep -q '^forgejo_mirror_pending_deletes 1$' "$TF_R/forgejo_mirror_reconcile.prom" \
                || { echo "FAIL recon1: pending 1"; exit 1; }
              [ "$(wc -l < "$XDG_STATE_HOME/forgejo-mirror-reconcile/known-stale.txt")" = 3 ] \
                || { echo "FAIL recon1: known-stale flat lines"; cat "$XDG_STATE_HOME/forgejo-mirror-reconcile/known-stale.txt"; exit 1; }
              grep -qxF 'artmann-minecraft/ghost-repo' "$XDG_STATE_HOME/forgejo-mirror-reconcile/known-stale-pairs.txt" \
                || { echo "FAIL recon1: known-stale pairs"; exit 1; }

              run "$RECON"; need_rc recon2 0
              need_has recon2 "healed rename: deleted stale 'LarsArtmann/old-name'"
              grep -q '^forgejo_mirror_pending_deletes 0$' "$TF_R/forgejo_mirror_reconcile.prom" \
                || { echo "FAIL recon2: pending 0"; exit 1; }

              # ============ mirror-health (M07) ============
              TF="$FIX/tf"; mkdir -p "$TF"
              export FORGEJO_MIRROR_HEALTH_TEXTFILE_DIR="$TF"
              export FORGEJO_DB="$FIX/fake.db"; : > "$FORGEJO_DB"
              STALE="$FIX/known-stale.txt"
              export FORGEJO_KNOWN_STALE="$STALE"
              printf 'darkblocks\ndialogueswebinterface\n' > "$STALE"

              : > "$FIX/notices"
              export STUB_SQLITE_OUT="$FIX/notices"
              run "$HEALTH"; need_rc health-clean 0
              grep -q '^forgejo_mirror_dead_candidates 0$' "$TF/forgejo_mirror_health.prom" \
                || { echo "FAIL health-clean: prom missing dead_candidates 0"; exit 1; }

              cat > "$FIX/notices" <<NOTICESEOF
              Failed to update mirror repository '/var/lib/forgejo/data/gitea-repositories/lars/SystemNix.git': fatal: repository not found
              Failed to update mirror repository '/var/lib/forgejo/data/gitea-repositories/lars/DarkBlocks.git': fatal: repository not found
              Failed to update mirror repository wiki '/var/lib/forgejo/data/gitea-repositories/lars/SomeRepo.git.wiki': fatal: repository not found
              Failed to delete repository '/var/lib/forgejo/data/gitea-repositories/lars/Other.git': unrelated notice type text
              NOTICESEOF
              run "$HEALTH"; need_rc health-dead 0; need_has health-dead "dead candidate: SystemNix"
              grep -q '^forgejo_mirror_dead_candidates 1$' "$TF/forgejo_mirror_health.prom" \
                || { echo "FAIL health-dead: expected exactly 1 candidate (DarkBlocks stale-subtracted, wiki+foreign ignored)"; cat "$TF/forgejo_mirror_health.prom"; exit 1; }

              export FORGEJO_KNOWN_STALE="$FIX/does-not-exist.txt"
              run "$HEALTH"; need_rc health-nostale 0
              grep -q '^forgejo_mirror_health_scrape_errors 1$' "$TF/forgejo_mirror_health.prom" \
                || { echo "FAIL health-nostale: scrape_errors 1 expected"; exit 1; }
              if grep -q 'forgejo_mirror_dead_candidates' "$TF/forgejo_mirror_health.prom"; then
                echo "FAIL health-nostale: dead_candidates must be ABSENT on scrape error"; exit 1
              fi
              export FORGEJO_KNOWN_STALE="$STALE"

              # ============ census (M08) ============
              unset STUB_SQLITE_OUT
              printf 200 > "$STUB_HTTP/localhost_3000_api_v1_user_repos_limit_50_page_1.GET.code"
              cat > "$STUB_HTTP/localhost_3000_api_v1_user_repos_limit_50_page_1.GET.body" <<'CENSUSEOF'
              [
                {"owner":{"login":"lars"},"mirror":true},
                {"owner":{"login":"lars"},"mirror":false},
                {"owner":{"login":"starred"},"mirror":true}
              ]
              CENSUSEOF
              run "$CENSUS"; need_rc census 0
              census_out=$(printf '%s\n' "$capt" | sed -n '/===/,$p' | tail -n +2 | jq -s '.[0]')
              echo "$census_out" | jq -e '.total == 3 and .native == 1 and .mirror == 2' >/dev/null \
                || { echo "FAIL census: wrong counts"; printf '%s\n' "$capt"; exit 1; }
              echo "$census_out" | jq -e '(.per_owner | length) == 2' >/dev/null \
                || { echo "FAIL census: per_owner grouping"; printf '%s\n' "$capt"; exit 1; }

              echo "PASS: all forgejo staged-primary script fixtures" > "$out"
            '';

        # Fixture test for scripts/migrate-forgejo-subvol.sh guard
        # branches (plan M02 debt): the REAL script against stubbed
        # btrfs/systemctl/chown (plain bash script — PATH stubs work
        # directly) with env-overridden state/subvol dirs and REAL
        # rsync/checksum verification.
        migrate-forgejo-subvol-fixture =
          pkgs.runCommand "migrate-forgejo-subvol-fixture"
            {
              nativeBuildInputs = with pkgs; [
                bash
                rsync
                gawk
                coreutils
                gnused
                findutils
                gnugrep
                diffutils
              ];
            }
            ''
              set -euo pipefail
              FIX=$(mktemp -d)
              STUB_BIN="$FIX/stub-bin"; mkdir -p "$STUB_BIN"

              cat > "$STUB_BIN/btrfs" <<'STUBEOF'
              #!${pkgs.bash}/bin/bash
              # btrfs subvolume <show|create> <path>: path is $3
              cmd="''${1:-}/''${2:-}"; path="''${3:-}"
              case "$cmd" in
                subvolume/show) [ -f "$path.created" ] && exit 0; exit 1 ;;
                subvolume/create) mkdir -p "$path" && touch "$path.created"; exit 0 ;;
              esac
              exit 1
              STUBEOF
              chmod +x "$STUB_BIN/btrfs"

              cat > "$STUB_BIN/systemctl" <<'STUBEOF'
              #!${pkgs.bash}/bin/bash
              # is-active --quiet <unit>: mnt-hot.mount active unless
              # STUB_MOUNT_DOWN=1; family units active iff
              # STUB_FAMILY_ACTIVE=1; everything else inactive.
              if [ "''${1:-}" = "is-active" ]; then
                unit="''${3:-}"
                if [ "$unit" = "mnt-hot.mount" ]; then
                  [ "''${STUB_MOUNT_DOWN:-0}" = 1 ] && exit 3
                  exit 0
                fi
                case "$unit" in
                  forgejo*) [ "''${STUB_FAMILY_ACTIVE:-0}" = 1 ] && exit 0; exit 3 ;;
                esac
                exit 3
              fi
              exit 0
              STUBEOF
              chmod +x "$STUB_BIN/systemctl"

              printf '#!${pkgs.bash}/bin/bash\nexit 0\n' > "$STUB_BIN/chown"
              chmod +x "$STUB_BIN/chown"

              cat > "$STUB_BIN/findmnt" <<'STUBEOF'
              #!${pkgs.bash}/bin/bash
              # findmnt -n -o SOURCE --mountpoint <path>: mountpoint
              # iff STUB_STATE_MOUNTED=1 (the flip-deploy-live state).
              if [ "''${STUB_STATE_MOUNTED:-0}" = 1 ]; then
                echo "/dev/stub-nvme0n1p2[/hot/forgejo]"
                exit 0
              fi
              exit 1
              STUBEOF
              chmod +x "$STUB_BIN/findmnt"

              export PATH="$STUB_BIN:$PATH"
              SCRIPT=${root}/scripts/migrate-forgejo-subvol.sh
              rc=0; capt=""
              # NOTE: capture var is `capt` — `out` is RESERVED (the
              # derivation output path); shadowing it made the final
              # `echo PASS > "$out"` redirect into a garbage filename.
              run() { capt=$(env MIGRATE_FORGEJO_STATE_DIR="$STATE" MIGRATE_FORGEJO_SUBVOL="$SUBVOL" bash "$SCRIPT" "$@" 2>&1) && rc=0 || rc=$?; }
              need_rc() { [ "$rc" = "$2" ] || { echo "FAIL $1: rc=$rc want $2"; printf '%s\n' "$capt"; exit 1; }; }
              need_has() { printf '%s\n' "$capt" | grep -qF "$2" || { echo "FAIL $1: missing text: $2"; printf '%s\n' "$capt"; exit 1; }; }

              fresh() {
                ROOT="$FIX/''${1:-case}"
                rm -rf "$ROOT"
                STATE="$ROOT/var-lib-forgejo"
                SUBVOL="$ROOT/mnt-hot-hot-forgejo"
                mkdir -p "$STATE/data" "$SUBVOL"
                for i in $(seq 1 30); do
                  printf 'content-%s\n' "$i" > "$STATE/data/file-$i"
                done
              }

              # 1. mount down -> prepare refuses
              fresh mountdown
              export STUB_MOUNT_DOWN=1
              run prepare; need_rc mountdown 1; need_has mountdown "not mounted"
              unset STUB_MOUNT_DOWN

              # 2. prepare happy + idempotent
              fresh prep
              run prepare; need_rc prep 0; need_has prep "prepare done"
              run prepare; need_rc prep2 0; need_has prep2 "subvol already exists"

              # 2b. flip-deploy-live state (2026-10-02 class): STATE_DIR
              # is the mounted EMPTY subvol, real data shadowed -> prepare
              # refuses with the umount repair, never rsyncs the mount.
              fresh shadowed
              export STUB_STATE_MOUNTED=1
              run prepare; need_rc shadowed 1; need_has shadowed "MOUNTPOINT"
              printf '%s\n' "$capt" | grep -qF "umount $STATE" || { echo "FAIL shadowed: umount repair missing"; exit 1; }
              [ ! -e "$SUBVOL/data" ] || { echo "FAIL shadowed: rsync ran against the mount"; exit 1; }
              unset STUB_STATE_MOUNTED

              # 2c. already migrated (marker present + mounted) -> refuse
              fresh done
              touch "$SUBVOL/.subvol-migrated"
              export STUB_STATE_MOUNTED=1
              run prepare; need_rc done 1; need_has done "ALREADY COMPLETED"
              unset STUB_STATE_MOUNTED
              rm -f "$SUBVOL/.subvol-migrated"

              # 3. finalize without prepare (empty subvol) refuses
              fresh noprep
              run finalize; need_rc noprep 1; need_has noprep "run" # mentions prepare requirement
              printf '%s\n' "$capt" | grep -qi "prepare" || { echo "FAIL noprep: message lacks prepare hint"; exit 1; }

              # 4. finalize with family active refuses
              fresh fam
              run prepare >/dev/null
              export STUB_FAMILY_ACTIVE=1
              run finalize; need_rc fam 1; need_has fam "still active"
              unset STUB_FAMILY_ACTIVE

              # 5. dry-run: plan only, no swap
              fresh dry
              run prepare >/dev/null
              run finalize --dry-run; need_rc dry 0; need_has dry "DRY RUN"
              [ -d "$STATE/data" ] || { echo "FAIL dry: state mutated"; exit 1; }
              [ ! -e "$STATE.qlc-pre-subvol" ] || { echo "FAIL dry: safety copy created"; exit 1; }

              # 6. happy finalize: verify + swap
              fresh fin
              run prepare >/dev/null
              run finalize; need_rc fin 0; need_has fin "finalize DONE"
              [ -d "$STATE.qlc-pre-subvol/data" ] || { echo "FAIL fin: safety copy missing"; exit 1; }
              [ -d "$STATE" ] || { echo "FAIL fin: new mountpoint missing"; exit 1; }
              [ -z "$(ls -A "$STATE")" ] || { echo "FAIL fin: mountpoint not empty"; exit 1; }
              [ -f "$SUBVOL/.subvol-migrated" ] || { echo "FAIL fin: migration marker missing in subvol"; exit 1; }
              diff -r --exclude=.subvol-migrated "$STATE.qlc-pre-subvol" "$SUBVOL" >/dev/null || { echo "FAIL fin: safety copy != subvol"; exit 1; }

              # 7. verification guard: tamper the destination with
              # IDENTICAL size and mtime so rsync's quick-check SKIPS
              # the file — the sampled checksum must then catch it and
              # refuse the swap (a plain tamper would just be healed by
              # the delta rsync before verification runs).
              fresh corrupt
              run prepare >/dev/null
              printf 'content-X\n' > "$SUBVOL/data/file-1"
              touch -r "$STATE/data/file-1" "$SUBVOL/data/file-1"
              run finalize; need_rc corrupt 1; need_has corrupt "checksum mismatch"
              [ -d "$STATE/data" ] || { echo "FAIL corrupt: source was moved despite mismatch"; exit 1; }
              [ ! -e "$STATE.qlc-pre-subvol" ] || { echo "FAIL corrupt: swapped despite mismatch"; exit 1; }

              echo "PASS: migrate-forgejo-subvol guard branches" > "$out"
            '';

      };
    };
}
