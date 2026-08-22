#!/usr/bin/env bash
# audit-go-deps.sh — cross-reference go.mod `require` lines of every pinned
# LarsArtmann flake input against the revs SystemNix actually pins in flake.lock.
#
# Failure class this catches: a consumer repo's go.mod requires
# github.com/larsartmann/<lib> vX.Y.Z, but the SystemNix flake input for <lib>
# pins a rev OLDER than the vX.Y.Z tag. mkPreparedSource replaces the dep with
# the pinned source, so the build compiles code older than the consumer's go.mod
# promises — undefined symbols or silent behavioral downgrades. (The inverse
# direction — browser-history go.mod requiring new cqrs-htmx tags BEFORE the
# SystemNix bump — is the documented gotcha this script automates.)
#
# Verdicts:
#   OK-EXACT    require resolves to exactly the pinned rev
#   OK-AHEAD    pinned rev contains the required commit (pin at-or-ahead)
#   OK-TREE     history diverged but the module's code tree is identical
#   WARN-DIVERGED pin does not contain the required commit AND the module tree
#               differs (this ecosystem rebases master, so direction is
#               unprovable — the build relies on API compatibility, not the
#               version the go.mod promises)
#   WARN-UNKNOWN  relation not decidable (no local clone / missing objects)
#   ERROR-MISSING required tag/pseudo-rev does not exist on the provider
#   INFO-UNPINNED  module is not a flake input (resolved via Go proxy at build)
#   SKIP-LOCAL  module is locally replaced in the consumer's go.mod
#
# Exit 1 on ERROR-MISSING. WARN-DIVERGED stays exit-0 because rebased history
# makes "pin older" unprovable and the tree currently deploys despite drift.
#
# Release-tag heuristic: this ecosystem cuts release commits ("strip replace
# directives") on tag-only commits that are NEVER on master, so for tag-resolved
# requires the comparison uses the tag commit's PARENT (the real code commit).
# Pseudo-version commits live on master directly and are compared as-is.
#
# Usage: bash scripts/audit-go-deps.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"

OK=0
WARN=0
ERR=0
INFO=0

say() { printf '%s\n' "$*"; }

# ── 1. Root input name → lock node (repo, rev) for LarsArtmann-owned inputs ──
declare -A PROVIDER_REV=() # repo (lowercase) -> pinned rev
declare -A INPUT_REPO=()   # root input name  -> repo (lowercase)
declare -A INPUT_REV=()    # root input name  -> pinned rev

while IFS=$'\t' read -r input repo rev; do
  [ -n "$input" ] || continue
  INPUT_REPO["$input"]="$repo"
  INPUT_REV["$input"]="$rev"
  # Multiple root inputs pointing at the same repo: last one wins, flagged below.
  if [ -n "${PROVIDER_REV[$repo]:-}" ] && [ "${PROVIDER_REV[$repo]}" != "$rev" ]; then
    say "WARN-AMBIG   repo $repo pinned by multiple inputs with DIFFERENT revs"
    WARN=$((WARN + 1))
  fi
  PROVIDER_REV["$repo"]="$rev"
done < <(
  jq -r '
    .nodes as $nodes
    | .nodes.root.inputs
    | to_entries[]
    | .key as $input
    | (.value | if type == "array" then .[0] else . end) as $nodeKey
    | $nodes[$nodeKey] as $node
    | (if $node.locked.type == "github" and (($node.locked.owner // "") | ascii_downcase) == "larsartmann"
       then {repo: $node.locked.repo, rev: $node.locked.rev}
       elif $node.locked.type == "git" and (($node.locked.url // "") | test("(?i)larsartmann"))
       then {repo: ($node.locked.url | sub("\\.git$"; "") | split("/") | .[-1]), rev: $node.locked.rev}
       else empty end)
    | [$input, (.repo | ascii_downcase), .rev] | @tsv
  ' "$REPO_ROOT/flake.lock"
)

if [ "${#INPUT_REPO[@]}" -eq 0 ]; then
  say "FATAL: no LarsArtmann inputs found in flake.lock — lock parse broken?"
  exit 2
fi

# ── 2. Store paths for all inputs (exact pinned sources, no network) ──
OUTPATHS=$(nix eval --impure --raw --expr \
  "let f = builtins.getFlake \"path:$REPO_ROOT\"; in builtins.toJSON (builtins.mapAttrs (n: i: i.outPath) f.inputs)" \
  2>/dev/null) || {
  say "FATAL: nix eval of input outPaths failed"
  exit 2
}

# ── 3. Tag/commit resolution helpers ──
# local_tags <repo> — dump "tag<TAB>commit" from the local clone (peeled), empty if absent.
local_clone() {
  local dir="$PROJECTS_DIR/$1"
  [ -d "$dir/.git" ] && printf '%s\n' "$dir"
}

declare -A TAG_CACHE=() # repo -> "tag commit" newline blob

resolve_tag() { # <repo> <tag> -> commit on stdout, empty if unresolvable
  local repo="$1" tag="$2"
  if [ -z "${TAG_CACHE[$repo]+x}" ]; then
    local blob=""
    local clone
    if clone=$(local_clone "$repo"); then
      blob=$(git -C "$clone" show-ref --tags -d 2>/dev/null |
        awk '/\^\{\}$/{tag=$2; sub("refs/tags/", "", tag); sub(/\^\{\}$/, "", tag); peeled[tag]=$1}
             !/\^\{\}$/{tag=$2; sub("refs/tags/", "", tag); direct[tag]=$1}
             END{for (t in direct) print t "\t" (peeled[t] != "" ? peeled[t] : direct[t])}')
    else
      blob=$(git ls-remote --tags "https://github.com/LarsArtmann/$repo" 2>/dev/null |
        awk '/\^\{\}$/{tag=$2; sub("refs/tags/", "", tag); sub(/\^\{\}$/, "", tag); peeled[tag]=$1}
             !/\^\{\}$/{tag=$2; sub("refs/tags/", "", tag); direct[tag]=$1}
             END{for (t in direct) print t "\t" (peeled[t] != "" ? peeled[t] : direct[t])}')
    fi
    TAG_CACHE[$repo]="$blob"
  fi
  awk -F'\t' -v tag="$2" '$1 == tag {print $2}' <<<"${TAG_CACHE[$repo]}"
}

is_ancestor() { # <repo> <commitA> <commitB> -> 0 if A is ancestor of B, 1 if not, 2 if undecidable
  local repo="$1" a="$2" b="$3"
  local clone
  clone=$(local_clone "$repo") || return 2
  git -C "$clone" cat-file -e "$a^{commit}" 2>/dev/null || return 2
  git -C "$clone" cat-file -e "$b^{commit}" 2>/dev/null || return 2
  if git -C "$clone" merge-base --is-ancestor "$a" "$b" 2>/dev/null; then
    return 0
  fi
  return 1
}

# ── 4. go.mod require/replace extraction ──
# Emits tab-separated: module, version, localreplace(0/1)
parse_gomod() {
  awk '
    # strip line comments for require parsing but remember "indirect"
    {
      line = $0
      sub(/\/\/.*$/, "", line)
      # split() with an explicit regex keeps leading whitespace as an empty
      # first field — trim it or require blocks (tab-indented) parse shifted.
      gsub(/^[[:space:]]+/, "", line)
    }
    line ~ /^[[:space:]]*require[[:space:]]*\(/ { inreq = 1; next }
    inreq && line ~ /^[[:space:]]*\)/ { inreq = 0; next }
    inreq && line ~ /[^[:space:]]/ {
      split(line, p, /[[:space:]]+/); req[p[1]] = p[2]; next
    }
    line ~ /^[[:space:]]*require[[:space:]]+[^(]/ {
      sub(/^[[:space:]]*require[[:space:]]+/, "", line)
      split(line, p, /[[:space:]]+/); req[p[1]] = p[2]; next
    }
    line ~ /^[[:space:]]*replace[[:space:]]*\(/ { inrep = 1; next }
    inrep && line ~ /^[[:space:]]*\)/ { inrep = 0; next }
    inrep && line ~ /=>/ { handle_replace(line); next }
    line ~ /^[[:space:]]*replace[[:space:]]/ && line ~ /=>/ { handle_replace(line); next }
    function handle_replace(l,   rhs, lhs, parts) {
      split(l, sides, "=>")
      rhs = sides[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", rhs)
      if (rhs ~ /^\.{0,2}\//) {
        lhs = sides[1]; gsub(/^[[:space:]]*replace[[:space:]]+/, "", lhs)
        split(lhs, parts, /[[:space:]]+/)
        localrep[parts[1]] = 1
      }
    }
    END {
      for (m in req)
        printf "%s\t%s\t%d\n", m, req[m], (m in localrep ? 1 : 0)
    }
  ' "$1"
}

# ── 5. Audit every LarsArtmann input's go.mod files ──
for input in "${!INPUT_REPO[@]}"; do
  src=$(jq -r --arg k "$input" '.[$k] // empty' <<<"$OUTPATHS")
  [ -n "$src" ] && [ -d "$src" ] || continue

  while IFS= read -r gomod; do
    rel="${gomod#"$src"/}"
    while IFS=$'\t' read -r mod ver localrep; do
      # Only LarsArtmann modules (either case)
      case "$mod" in
      github.com/larsartmann/* | github.com/LarsArtmann/*) ;;
      *) continue ;;
      esac
      rest="${mod#github.com/}"
      rest="${rest#[lL][aA][rR][sS][aA][rR][tT][mM][aA][nN][nN]/}"
      repo="$(cut -d/ -f1 <<<"$rest" | tr '[:upper:]' '[:lower:]')"
      subpath="$(cut -d/ -f2- -s <<<"$rest")"
      # Strip trailing /vN major suffix from the subpath for tag construction.
      # Root module with only a major suffix (gogenfilter/v3) → plain vX.Y.Z tag.
      case "$subpath" in
      v[0-9]*) tagprefix="" ;;
      *) tagprefix="$(sed -E 's|/v[0-9]+$||' <<<"$subpath")" ;;
      esac

      context="$input ($rel) requires $mod $ver"

      if [ "$localrep" = "1" ]; then
        say "SKIP-LOCAL   $context (local replace)"
        continue
      fi

      pinned="${PROVIDER_REV[$repo]:-}"
      if [ -z "$pinned" ]; then
        say "INFO-UNPINNED $context — no flake input for $repo (Go proxy resolves at build)"
        INFO=$((INFO + 1))
        continue
      fi

      # Resolve the required version to a commit. Pseudo-versions come in two
      # shapes: v0.0.0-<ts>-<rev> and vX.Y.Z-0.<ts>-<rev> (base-tag infix).
      reqcommit=""
      from_tag=0
      if [[ "$ver" =~ (0\.|-)[0-9]{14}-([0-9a-f]{12})$ ]]; then
        reqcommit="${BASH_REMATCH[2]}"
      else
        tag="$ver"
        [ -n "$tagprefix" ] && tag="$tagprefix/$ver"
        reqcommit=$(resolve_tag "$repo" "$tag")
        from_tag=1
        if [ -z "$reqcommit" ]; then
          say "ERROR-MISSING $context — tag $tag not found in $repo"
          ERR=$((ERR + 1))
          continue
        fi
        # This ecosystem cuts release commits ("strip replace directives") on a
        # detached/tag-only commit that is NEVER on master, so the tag commit
        # itself is never an ancestor of a master pin — its PARENT (the real
        # code commit) is the right comparison point. Pseudo-version commits
        # live on master directly and must NOT be parented.
        clone=$(local_clone "$repo") || clone=""
        if [ "$from_tag" = "1" ] && [ -n "$clone" ] && git -C "$clone" cat-file -e "$reqcommit^{commit}" 2>/dev/null; then
          reqcommit=$(git -C "$clone" rev-parse "$reqcommit^" 2>/dev/null || echo "$reqcommit")
        fi
      fi

      # Compare against the pinned rev
      if [[ "$pinned" == "$reqcommit"* ]]; then
        say "OK-EXACT     $context → $repo@${pinned:0:12}"
        OK=$((OK + 1))
        continue
      fi

      is_ancestor "$repo" "$reqcommit" "$pinned"
      case $? in
      0)
        say "OK-AHEAD     $context → $repo pin ${pinned:0:12} contains required code (${reqcommit:0:12})"
        OK=$((OK + 1))
        ;;
      1)
        # History diverged (rebased master) or pin is genuinely older. Compare
        # the module's code tree (excluding go.mod/go.sum — release commits
        # legitimately rewrite those) before calling it drift.
        trees_identical=2
        if clone=$(local_clone "$repo"); then
          treepath="$(sed -E 's|/v[0-9]+$||' <<<"$subpath")"
          [ -z "$treepath" ] && treepath="."
          if git -C "$clone" diff --quiet "$reqcommit" "$pinned" -- "$treepath" ':(exclude)*go.mod' ':(exclude)*go.sum' 2>/dev/null; then
            trees_identical=0
          else
            trees_identical=1
          fi
        fi
        case $trees_identical in
        0)
          say "OK-TREE      $context → history diverged but $repo tree identical (rebased release commit)"
          OK=$((OK + 1))
          ;;
        1)
          say "WARN-DIVERGED $context → $repo pin ${pinned:0:12} lacks required ${reqcommit:0:12} and tree differs (direction unprovable under rebase)"
          WARN=$((WARN + 1))
          ;;
        2)
          say "WARN-UNKNOWN $context → relation of $repo pin ${pinned:0:12} vs required ${reqcommit:0:12} undecidable (no local clone at $PROJECTS_DIR/$repo or missing objects)"
          WARN=$((WARN + 1))
          ;;
        esac
        ;;
      2)
        say "WARN-UNKNOWN $context → relation of $repo pin ${pinned:0:12} vs required ${reqcommit:0:12} undecidable (no local clone at $PROJECTS_DIR/$repo or missing objects)"
        WARN=$((WARN + 1))
        ;;
      esac
    done < <(parse_gomod "$gomod")
  done < <(find "$src" -name go.mod -not -path '*/.*' 2>/dev/null)
done

say ""
say "=== dep-audit summary: $OK ok, $INFO unpinned(proxy), $WARN warnings, $ERR errors ==="
[ "$ERR" -eq 0 ]
