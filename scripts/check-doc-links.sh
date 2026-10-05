#!/usr/bin/env bash
# Relative-link + heading-anchor checker for living docs (F54 rewrite of the
# 2026-08-31 audit session's buggy ad-hoc checker, which false-BROKEN'd every
# relative link via a wrong sed; 2026-10-01 T2: anchor validation added).
#
# Checks markdown links [text](target) in the LIVING docs only (frozen
# snapshots under docs/status/ and docs/planning/ keep their historical
# paths by repo policy). Relative targets are resolved against the
# linking file's directory; http(s)://, mailto:, and <>-style autolinks
# are ignored.
#
# Anchor validation (GitHub semantics): `file.md#anchor` and same-file
# `#anchor` links must resolve to a heading slug in the target .md file.
# Slugs: lowercase, punctuation dropped (alnum/_/- kept), each whitespace
# char -> '-', duplicate headings get -1, -2 suffixes. Links and headings
# inside ``` fences are ignored (quoted markdown is not real structure).
# 2026-10-06: single-backtick inline-code spans are stripped before link
# matching for the same reason — a bracketed-generic invocation written in
# backticks (chromedp Evaluate shape) parsed as a fake link with a
# non-path target and red-locked every markdown-staging commit.
#
# --selftest runs fixture cases (good/bad anchor, dot punctuation, dedup,
# fence immunity, inline-code immunity) and exits 0 only if all
# expectations hold.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

LIVING_DOCS=(
  README.md
  TODO_LIST.md
  FEATURES.md
  ROADMAP.md
  CHANGELOG.md
  AGENTS.md
  docs/README.md
  docs/CONTRIBUTING.md
  docs/gotchas-archive.md
  docs/agents/*.md
  docs/services/*.md
  docs/todo/*.md
)

BROKEN_COUNT=0

# GitHub-style heading slug: lowercase, drop punctuation (keep alnum/_/-,
# unicode letters under a UTF-8 locale), each whitespace char -> '-'.
slug_github() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^[:alnum:]_ -]//g; s/[[:space:]]/-/g'
}

# anchor_slugs <file> -> newline-joined heading slugs (dedup -1, -2, ...)
anchor_slugs() {
  local f="$1" in_fence=0 line text slug
  local -A seen=()
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
    '```'*)
      in_fence=$(((in_fence + 1) % 2))
      continue
      ;;
    esac
    [ "$in_fence" -eq 0 ] || continue
    # ATX heading: up to 3 leading spaces, 1-6 '#', space (or EOL) after.
    [[ $line =~ ^[[:space:]]{0,3}#{1,6}([[:space:]].*)?$ ]] || continue
    text="${line#"${line%%[![:space:]]*}"}"
    while [[ $text == \#* ]]; do text="${text#\#}"; done
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    [ -n "$text" ] || continue
    slug=$(slug_github "$text")
    [ -n "$slug" ] || continue
    if [[ -n ${seen[$slug]:-} ]]; then
      seen[$slug]=$((${seen[$slug]} + 1))
      slug="$slug-${seen[$slug]}"
    else
      seen[$slug]=0
    fi
    printf '%s\n' "$slug"
  done <"$f"
}

# anchor cache: file -> newline-joined slugs (lazily built)
declare -A _ANCHOR_CACHE=()

anchors_of() {
  local f="$1"
  if [[ -z ${_ANCHOR_CACHE[$f]:-} ]]; then
    _ANCHOR_CACHE[$f]=$(anchor_slugs "$f")
  fi
  printf '%s' "${_ANCHOR_CACHE[$f]}"
}

anchor_exists() {
  local f="$1" want="$2" slugs
  # herestring, never a pipe: a -q early-close would SIGPIPE the producer
  # under pipefail (the documented house false-FAIL class).
  slugs="$(anchors_of "$f")"
  grep -Fxq -- "$want" <<<"$slugs"
}

# check_file <file>: walk non-fenced lines, validate every [text](target).
check_file() {
  local f="$1" dir in_fence=0 line rest match target path anchor afile
  local link_re='\[[^]]*\]\([^)]+\)'
  dir=$(dirname "$f")
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
    '```'*)
      in_fence=$(((in_fence + 1) % 2))
      continue
      ;;
    esac
    [ "$in_fence" -eq 0 ] || continue
    # strip inline-code spans (`...`): their content is literal text, never
    # link structure — fence immunity at span size. One span per pass, not a
    # greedy glob, so real links BETWEEN two spans survive.
    rest="$line"
    local code_re='`[^`]+`'
    while [[ $rest =~ $code_re ]]; do
      rest="${rest/"${BASH_REMATCH[0]}"/}"
    done
    while [[ $rest =~ $link_re ]]; do
      match="${BASH_REMATCH[0]}"
      # advance past this match (first occurrence of the exact string)
      rest="${rest#*"$match"}"
      target="${match%")"}"
      target="${target##*(}"
      case "$target" in
      http://* | https://* | mailto:*) continue ;;
      esac
      # angle-bracket form: [text](<path>) — strip the brackets
      target="${target#"<"}"
      target="${target%">"}"
      anchor=""
      path="$target"
      if [[ $target == *"#"* ]]; then
        anchor="${target#*#}"
        path="${target%%#*}"
      fi
      path="${path//%20/ }"
      if [ -n "$path" ] && [ ! -e "$dir/$path" ]; then
        echo "BROKEN: $f -> $target"
        BROKEN_COUNT=$((BROKEN_COUNT + 1))
        continue
      fi
      if [ -n "$anchor" ]; then
        afile="$f"
        [ -n "$path" ] && afile="$dir/$path"
        case "$afile" in
        *.md) ;;
        *) continue ;; # non-markdown target: no headings to validate
        esac
        if [ ! -f "$afile" ]; then
          continue # directory or missing (already reported above)
        fi
        if ! anchor_exists "$afile" "$anchor"; then
          echo "BROKEN-ANCHOR: $f -> $target (no heading \"$anchor\" in $afile)"
          BROKEN_COUNT=$((BROKEN_COUNT + 1))
        fi
      fi
    done
  done <"$f"
}

run_selftest() {
  local tmp out fail=0 e
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN

  cat >"$tmp/target.md" <<'EOF'
# Title

## Section One
text

## Dotted. Heading (v2)!
more

## Dup

## Dup

```
## Fenced Heading
[fake](broken-in-fence.md)
```
EOF

  cat >"$tmp/in.md" <<'EOF'
# In Doc

[good-file](target.md)
[good-anchor](target.md#section-one)
[good-dot](target.md#dotted-heading-v2)
[good-same-file](#in-doc)
[good-dup-1](target.md#dup-1)
[bad-file](nope.md)
[bad-anchor](target.md#missing-heading)
[bad-same-file](#nope)
[bad-dup-2](target.md#dup-2)
[fence-heading-ref](target.md#fenced-heading)
`Evaluate[T](expr, opts...) Action[T]` must never parse as a link
`span one` then [real-between-spans](target.md#missing-code-span) then `span two`
[`ticked text`](target.md#section-one)
EOF

  local expect_broken=(
    "in.md -> nope.md"
    "in.md -> target.md#missing-heading"
    "in.md -> #nope"
    "in.md -> target.md#dup-2"
    "in.md -> target.md#fenced-heading"
    "in.md -> target.md#missing-code-span"
  )
  local expect_ok=(
    "target.md#section-one"
    "target.md#dotted-heading-v2"
    "#in-doc"
    "target.md#dup-1"
    "broken-in-fence"
    "expr, opts..."
    "in.md -> target.md#section-one"
  )

  out=$(check_file "$tmp/in.md") || true
  for e in "${expect_broken[@]}"; do
    if ! grep -qF -- "$e" <<<"$out"; then
      echo "SELFTEST FAIL: expected detection of: $e"
      fail=1
    fi
  done
  for e in "${expect_ok[@]}"; do
    if grep -qF -- "$e" <<<"$out"; then
      echo "SELFTEST FAIL: false positive on: $e"
      fail=1
    fi
  done

  # positive control: an all-good file reports nothing
  cat >"$tmp/clean.md" <<'EOF'
[fine](target.md#section-one)
EOF
  if
    out=$(check_file "$tmp/clean.md") || true
    [ -n "$out" ]
  then
    echo "SELFTEST FAIL: clean file flagged: $out"
    fail=1
  fi

  if [ "$fail" -ne 0 ]; then
    echo "SELFTEST: FAIL"
    return 1
  fi
  echo "SELFTEST: OK (anchors, dots, dedup, fences, inline code)"
}

if [ "${1:-}" = "--selftest" ]; then
  run_selftest
  exit 0
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  echo "usage: scripts/check-doc-links.sh [--selftest]"
  exit 0
fi

while IFS= read -r f; do
  [ -f "$f" ] || continue
  check_file "$f"
done < <(ls "${LIVING_DOCS[@]}" 2>/dev/null || true)

if [ "$BROKEN_COUNT" -ne 0 ]; then
  echo "FAIL: $BROKEN_COUNT broken link(s)/anchor(s) above."
  exit 1
fi
echo "OK: no broken relative links or anchors in living docs."
