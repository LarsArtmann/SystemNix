#!/usr/bin/env bash
# shellcheck shell=bash
# pstore-records.sh: shared EFI-pstore record decoding for the boot autopsy
# scripts (the "pstore (EFI) crash dump" section of boot-evidence-pull.sh and
# the `kdump=` verdict line of crash-triage.sh).  Sourced by those scripts;
# executed directly it runs nothing but its fixture selftest
# (`pstore-records.sh [selftest]`, flake check
# checks.x86_64-linux.pstore-records-selftest).
#
# Why (2026-11-25, two kernel panics at 08:57:47 and 11:05:51): with a crash
# image loaded, vpanic() jumps into the capture kernel BEFORE the main kernel
# writes its own panic text to pstore (no crash_kexec_post_notifiers).  The
# capture kernel then booted the normal systemd userspace, inherited the main
# system's vm.min_free_kbytes = 2097152 (a 2 GiB zone watermark inside a
# 512 MiB kernel), OOM-killed its own boot and panicked "System is deadlocked
# on memory" at uptime 11-13 s.  The only pstore dump that survives such a
# panic is therefore the CAPTURE kernel's log and /var/crash stays empty.  An
# autopsy that reads "a pstore dump exists" as "the main kernel's panic was
# captured" attributes the wrong log; this library decodes WHOSE log it is.
#
# Source of the records (unprivileged, verified live on systemd 262): the EFI
# pstore dump is archived at the START of the boot AFTER the crash by
# systemd-pstore.service, into /var/lib/systemd/pstore/<epoch>/<NNN>/.  The
# archived files are mode 0600 root, but the archiving process logs one
# journal entry per record whose FILE field carries the record text (first
# line "Panic#<count> Part<N>", or "Oops#<count> Part<N>" for an Oops).  Those
# entries carry NO _SYSTEMD_UNIT / _COMM field (the short-lived process is
# gone before journald attaches them), so `_SYSTEMD_UNIT=systemd-pstore.service`
# matches NOTHING on this system; the validated selector is
# SYSLOG_IDENTIFIER=systemd-pstore (22 records for boot 0 on 2026-11-25).  An
# older systemd puts the record text in MESSAGE instead, which is accepted as
# a fallback.  Parts are stored NEWEST-first: Part1 holds the newest lines, so
# chronological order is DESCENDING part number.
#
# Decoding (verified against the four dumps still in the journal):
#   record id (dmesg-efi_pstore-<id>) = <epoch><part:02d><count:03d>
#   "N pages RAM" with N < 2000000  -> the 512 MiB capture kernel
#   "[  UPTIME]" stamps >= 600 s    -> the main kernel
#   "min:<N>kB" on a "Node 0 <zone> free:" line -> the inherited watermark
#   "System is deadlocked on memory" -> the capture kernel OOM-panicked
# An empty read is never evidence: zero records means "no pstore data", never
# "no crash".
#
# Sourcing contract: defines functions and PSTORE_* seams only.  Nothing here
# calls journalctl or touches the filesystem at source time, so the fixture
# selftests of both scripts run without journalctl (and inside the nix
# sandbox with bash + coreutils only: no jq, no python, no awk).
#
# Testable seams (live default in parentheses):
#   PSTORE_JOURNALCTL      journalctl command ("journalctl", or the value of
#                          crash-triage.sh's JOURNALCTL when that is set);
#                          pstore_journalctl_cmd resolves it, so a sourcing
#                          script's own journal read goes through the SAME
#                          seam and one stub covers both
#   PSTORE_ARCHIVE_ROOT    prefix of /var/lib/systemd/pstore; the archive
#                          files are read directly when readable, which in
#                          practice means a root run (/var/lib/systemd/pstore;
#                          an EMPTY value disables the direct read)
#
# Verdict tokens (shared vocabulary, keep both scripts in step):
#   capture-kernel-OOM           the log is the capture kernel's and it died
#                                of the inherited watermark: the MAIN kernel's
#                                panic text is NOT in pstore
#   capture-kernel-panicked      the log is the capture kernel's, no OOM marker
#   main-kernel-panic-captured   the log is the main kernel's (a Panic# or
#                                Oops# record with long uptime stamps)
#   none                         the next boot archived no pstore dump

PSTORE_CAPTURE_PAGES_MAX=2000000
PSTORE_MAIN_UPTIME_MIN=600
PSTORE_ARCHIVE_ROOT="${PSTORE_ARCHIVE_ROOT-/var/lib/systemd/pstore}"
# A part number above this bound is treated as a malformed header, so the
# descending scan below can never loop on a garbage number.
PSTORE_MAX_PART=100000

# --- JSON (journalctl -o json writes one object per line; values are strings
# or numbers) ---------------------------------------------------------------

# bs is a backslash and dq a double quote; routing both through variables
# keeps the case patterns below free of quote-escape acrobatics.

pstore_unescape_set() { # <variable name> <escaped string body>: decodes INTO that variable (fork-free)
  # The target name must not be one of this function's own locals.
  local __pv="$1" s="$2" out='' pre esc hex cp lo ch bs=$'\\'
  while :; do
    pre=${s%%"$bs"*}
    out+=$pre
    s=${s#"$pre"}
    case "$s" in
    '') break ;;
    "$bs")
      # a lone trailing backslash is not a valid escape: keep it literally
      out+=$bs
      break
      ;;
    esac
    esc=${s:1:1}
    s=${s:2}
    case "$esc" in
    n) out+=$'\n' ;;
    t) out+=$'\t' ;;
    r) out+=$'\r' ;;
    b) out+=$'\b' ;;
    f) out+=$'\f' ;;
    '"' | / | \\) out+=$esc ;;
    u)
      hex=${s:0:4}
      if [[ ! $hex =~ ^[0-9a-fA-F]{4}$ ]]; then
        out+=$bs'u' # not an escape this decoder knows: keep it literally
        continue
      fi
      s=${s:4}
      printf -v cp '%d' "0x$hex"
      # UTF-16 surrogate pair: combine the high and the low half
      if [ "$cp" -ge 55296 ] && [ "$cp" -le 56319 ] && [ "${s:0:2}" = "${bs}u" ] &&
        [[ ${s:2:4} =~ ^[dcDC][0-9a-fA-F]{3}$ ]]; then
        printf -v lo '%d' "0x${s:2:4}"
        if [ "$lo" -ge 56320 ] && [ "$lo" -le 57343 ]; then
          s=${s:6}
          cp=$((65536 + (cp - 55296) * 1024 + (lo - 56320)))
        fi
      fi
      printf -v ch '%b' "${bs}U$(printf '%08x' "$cp")"
      out+=$ch
      ;;
    *) out+=$bs$esc ;;
    esac
  done
  printf -v "$__pv" '%s' "$out"
  return 0
}

pstore_json_unescape() { # <escaped string body> -> decoded text (adds no newline)
  pstore_unescape_set PSTORE_VAL "$1"
  printf '%s' "$PSTORE_VAL"
}

pstore_json_getv() { # <json object> <key>: decoded value INTO the global PSTORE_VAL; rc 1 when absent (fork-free)
  # Minimal object walker (keys are plain identifiers, values are strings or
  # numbers): it never mistakes a `"key":"` sequence INSIDE a string value for
  # the real key, which a plain substring search would.
  local s="$1" want="$2" dq='"' bs=$'\\' v chunk tb hit
  s=${s#"${s%%[![:space:]]*}"}
  case "$s" in '{'*) ;; *) return 1 ;; esac
  s=${s:1}
  while :; do
    s=${s#"${s%%[![:space:]]*}"}
    case "$s" in
    '' | '}') return 1 ;;
    esac
    hit=0
    case "$s" in
    "${dq}${want}${dq}"*) hit=1 ;;
    "${dq}"*) ;;
    *) return 1 ;;
    esac
    s=${s:1}
    s=${s#*"${dq}"} # the key is a plain identifier: skip to its closing quote
    s=${s#"${s%%[![:space:]]*}"}
    case "$s" in ':'*) ;; *) return 1 ;; esac
    s=${s:1}
    s=${s#"${s%%[![:space:]]*}"}
    case "$s" in
    "${dq}"*)
      s=${s:1} # drop the opening quote
      v=''
      while :; do
        chunk=${s%%"${dq}"*}
        if [ "$chunk" = "$s" ]; then return 1; fi # no closing quote
        v+=$chunk
        tb=0
        while [[ $chunk == *"$bs" ]]; do # count the trailing backslashes
          tb=$((tb + 1))
          chunk=${chunk%?}
        done
        s=${s#*"${dq}"}
        if [ $((tb % 2)) -eq 1 ]; then
          v+="${dq}" # the quote was escaped: the string continues
          continue
        fi
        break
      done
      if [ "$hit" = 1 ]; then
        pstore_unescape_set PSTORE_VAL "$v"
        return 0
      fi
      ;;
    *) # number or literal
      v=${s%%[,\}]*}
      s=${s#"$v"}
      if [ "$hit" = 1 ]; then
        PSTORE_VAL=$v
        return 0
      fi
      ;;
    esac
    s=${s#"${s%%[![:space:]]*}"}
    case "$s" in
    ','*) s=${s:1} ;;
    *) return 1 ;;
    esac
  done
}

pstore_json_get() { # <json object> <key> -> decoded string value on stdout; rc 1 when absent
  pstore_json_getv "$1" "$2" || return 1
  printf '%s' "$PSTORE_VAL"
}

# --- records: parse, assemble, classify -------------------------------------
# pstore_jsonl_parse fills these globals in the CALLER shell, so call it with
# a redirect (`pstore_jsonl_parse < file` or `<<< "$jsonl"`), never as a
# pipeline segment.  Index of PSTORE_BODY = count * 1000000 + part, so a dump
# set that holds several panic counts cannot collide.

PSTORE_N=0           # records kept
PSTORE_PARSE_LINES=0 # JSON lines seen (record entries and other messages)
PSTORE_BODY=()       # record body (header line removed), keyed count*1000000+part
PSTORE_MAXCOUNT=0
PSTORE_MAXPART=0
PSTORE_MINPART=0
PSTORE_EPOCHS=''     # distinct dump ids (epoch of the record id), first-seen order
PSTORE_KINDS=''      # distinct header kinds, e.g. "Panic#1"
PSTORE_BYTES=0       # bytes of the assembled dump text
PSTORE_ARCH_HITS=0   # records whose body came from the archive (root run)
PSTORE_HDR_OF=()     # record header line ("Panic#1 Part2"), keyed like PSTORE_BODY
PSTORE_ARCHIVE_OF=() # archive path under /var/lib/systemd/pstore ('' when the
# message does not name one), keyed like PSTORE_BODY
PSTORE_EPOCH='' # scratch of pstore_epoch_of
PSTORE_VAL=''   # scratch of pstore_json_getv

pstore_epoch_of() { # <MESSAGE text> -> sets PSTORE_EPOCH ('' and rc 1 when undecodable); fork-free
  local m="$1" id
  if [[ $m =~ pstore/([0-9]+)/ ]]; then
    PSTORE_EPOCH=${BASH_REMATCH[1]}
    return 0
  fi
  if [[ $m =~ efi_pstore-([0-9]+) ]]; then
    id=${BASH_REMATCH[1]}
    # <epoch><part:02d><count:03d>: drop the last five digits
    PSTORE_EPOCH=${id%?????}
    return 0
  fi
  PSTORE_EPOCH=''
  return 1
}

pstore_jsonl_parse() { # stdin: `journalctl -o json` lines -> PSTORE_* globals
  local line f m hdr body kind count part idx rel b2
  local nl=$'\n' e
  local LC_ALL=C # byte counts (${#body}) stay byte counts under a UTF-8 locale
  PSTORE_N=0
  PSTORE_PARSE_LINES=0
  PSTORE_BODY=()
  PSTORE_MAXCOUNT=0
  PSTORE_MAXPART=0
  PSTORE_MINPART=0
  PSTORE_EPOCHS=''
  PSTORE_KINDS=''
  PSTORE_BYTES=0
  PSTORE_ARCH_HITS=0
  PSTORE_HDR_OF=()
  PSTORE_ARCHIVE_OF=()
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    PSTORE_PARSE_LINES=$((PSTORE_PARSE_LINES + 1))
    f=''
    f=''
    case "$line" in
    *'"FILE":'*)
      if pstore_json_getv "$line" FILE; then f=$PSTORE_VAL; fi
      ;;
    esac
    case "$f" in
    Panic#* | Oops#*) ;;
    # older systemd: no FILE field, the record text sits in MESSAGE.  The
    # walk is gated on a cheap substring test: a full walk of every journal
    # line costs seconds on a big boot.
    *)
      case "$line" in
      *'Panic#'* | *'Oops#'*)
        if pstore_json_getv "$line" MESSAGE; then f=$PSTORE_VAL; fi
        ;;
      *) f='' ;;
      esac
      ;;
    esac
    hdr=${f%%"$nl"*}
    case "$hdr" in
    'Panic#'*\ Part* | 'Oops#'*\ Part*) ;;
    *) continue ;;
    esac
    body=${f#"$hdr"}
    body=${body#"$nl"}
    m=''
    if pstore_json_getv "$line" MESSAGE; then m=$PSTORE_VAL; fi
    rel=''
    case "$m" in
    *' moved to /var/lib/systemd/pstore/'*) rel=${m#* moved to /var/lib/systemd/pstore/} ;;
    esac
    # Root run: the archived file wins when it is readable (the journal copy
    # stays the unprivileged path).  The file may repeat the header line.
    if [ -n "$PSTORE_ARCHIVE_ROOT" ] && [ -n "$rel" ]; then
      if [ -r "$PSTORE_ARCHIVE_ROOT/$rel" ]; then
        b2=$(cat "$PSTORE_ARCHIVE_ROOT/$rel" 2>/dev/null) || b2=''
        if [ -n "$b2" ]; then
          case "$b2" in
          "$hdr"$nl*) b2=${b2#"$hdr$nl"} ;;
          esac
          body=$b2
          PSTORE_ARCH_HITS=$((PSTORE_ARCH_HITS + 1))
        fi
      fi
    fi
    kind=${hdr%% *}
    count=0
    part=0
    if [[ $hdr =~ ^(Panic|Oops)#([0-9]+)[[:space:]]+Part([0-9]+)$ ]]; then
      count=${BASH_REMATCH[2]}
      part=${BASH_REMATCH[3]}
    fi
    [ "$part" -le "$PSTORE_MAX_PART" ] || continue # malformed part number
    idx=$((count * 1000000 + part))
    case " ${PSTORE_BODY[idx]+x}" in
    ' x') continue ;; # duplicate (count, part): the first occurrence wins
    esac
    PSTORE_BODY[idx]=$body
    PSTORE_HDR_OF[idx]=$hdr
    PSTORE_ARCHIVE_OF[idx]=$rel
    PSTORE_N=$((PSTORE_N + 1))
    PSTORE_BYTES=$((PSTORE_BYTES + ${#body}))
    [ "$count" -le "$PSTORE_MAXCOUNT" ] || PSTORE_MAXCOUNT=$count
    if [ "$PSTORE_N" -eq 1 ]; then
      PSTORE_MINPART=$part
      PSTORE_MAXPART=$part
    else
      [ "$part" -le "$PSTORE_MAXPART" ] || PSTORE_MAXPART=$part
      [ "$part" -ge "$PSTORE_MINPART" ] || PSTORE_MINPART=$part
    fi
    case " $PSTORE_KINDS " in
    *" $kind "*) ;;
    *) PSTORE_KINDS="${PSTORE_KINDS:+$PSTORE_KINDS }$kind" ;;
    esac
    if pstore_epoch_of "$m"; then e=$PSTORE_EPOCH; else e=unknown; fi
    case " $PSTORE_EPOCHS " in
    *" $e "*) ;;
    *) PSTORE_EPOCHS="${PSTORE_EPOCHS:+$PSTORE_EPOCHS }$e" ;;
    esac
  done
  return 0
}

pstore_dump_text() { # assembled dump on stdout, oldest line first (descending part number)
  local c p i
  for ((c = PSTORE_MAXCOUNT; c >= 0; c--)); do
    for ((p = PSTORE_MAXPART; p >= 0; p--)); do
      i=$((c * 1000000 + p))
      case " ${PSTORE_BODY[i]+x}" in
      ' x') ;;
      *) continue ;;
      esac
      [ -n "${PSTORE_BODY[i]}" ] || continue
      printf '%s\n' "${PSTORE_BODY[i]%$'\n'}"
    done
  done
  return 0
}

pstore_records_list() { # one line per record on stdout, dump order (same walk as pstore_dump_text): header, archive path, size, first line
  local c p i first
  local LC_ALL=C # the cut below is a byte cut: it must never split a multi-byte character
  for ((c = PSTORE_MAXCOUNT; c >= 0; c--)); do
    for ((p = PSTORE_MAXPART; p >= 0; p--)); do
      i=$((c * 1000000 + p))
      case " ${PSTORE_BODY[i]+x}" in
      ' x') ;;
      *) continue ;;
      esac
      # The header IS the record's identity (the archive file is named after
      # it); the first body line carries the uptime stamp the part starts at.
      first=${PSTORE_BODY[i]%%$'\n'*}
      [ "${#first}" -le 200 ] || first="${first:0:200}..."
      printf -- '- record=%s archive=%s bytes=%s first-line: %s\n' \
        "${PSTORE_HDR_OF[i]}" "${PSTORE_ARCHIVE_OF[i]:-none}" "${#PSTORE_BODY[i]}" "${first:-(empty)}"
    done
  done
  return 0
}

pstore_part_gaps() { # part numbers missing between the lowest and the highest part ('' when none)
  local p c found gaps=''
  # No records means there is no part range at all.  The walk below would
  # otherwise test part 0, find nothing, and the facts block would print
  # `gaps=0`: a "missing part 0" in a dump that does not exist (2026-11-26).
  [ "$PSTORE_N" -gt 0 ] || return 0
  for ((p = PSTORE_MINPART; p <= PSTORE_MAXPART; p++)); do
    found=0
    for ((c = 0; c <= PSTORE_MAXCOUNT; c++)); do
      case " ${PSTORE_BODY[$((c * 1000000 + p))]+x}" in
      ' x')
        found=1
        break
        ;;
      esac
    done
    [ "$found" = 1 ] || gaps="${gaps:+$gaps,}$p"
  done
  printf '%s' "$gaps"
}

pstore_facts() { # PSTORE_* records -> key=value lines (token= first): whose log, and how it died
  local re_stamp='^[^[]*\[[[:space:]]*([0-9]+)\.([0-9]+)\]'
  local re_ram='^[^[]*\[[[:space:]]*[0-9]+\.[0-9]+\][[:space:]]*([0-9]+) pages RAM$'
  local re_zone='^[^[]*\[[[:space:]]*[0-9]+\.[0-9]+\][[:space:]]*Node [0-9]+ [A-Za-z0-9_]+ free:'
  local re_min=' min:([0-9]+)kB low:([0-9]+)kB high:([0-9]+)kB'
  local c p i line pages_ram='' min_kb='' up_key='' max_up=0 frac6 deadlocked=0 panic_lines=0
  local kernel='' basis='' token='' lines=0
  for ((c = PSTORE_MAXCOUNT; c >= 0; c--)); do
    for ((p = PSTORE_MAXPART; p >= 0; p--)); do
      i=$((c * 1000000 + p))
      case " ${PSTORE_BODY[i]+x}" in
      ' x') ;;
      *) continue ;;
      esac
      while IFS= read -r line; do
        lines=$((lines + 1))
        if [[ $line =~ $re_stamp ]]; then
          frac6=${BASH_REMATCH[2]}000000
          up_key=$((BASH_REMATCH[1] * 1000000 + 10#${frac6:0:6}))
          [ "$up_key" -le "$max_up" ] || max_up=$up_key
        fi
        if [ -z "$pages_ram" ] && [[ $line =~ $re_ram ]]; then
          pages_ram=${BASH_REMATCH[1]}
        fi
        if [[ $line =~ $re_zone ]] && [[ $line =~ $re_min ]]; then
          if [ -z "$min_kb" ] || [ "${BASH_REMATCH[1]}" -gt "$min_kb" ]; then
            min_kb=${BASH_REMATCH[1]}
          fi
        fi
        case "$line" in
        *'System is deadlocked on memory'*) deadlocked=$((deadlocked + 1)) ;;
        esac
        case "$line" in
        *'Kernel panic - not syncing'*) panic_lines=$((panic_lines + 1)) ;;
        esac
      done <<<"${PSTORE_BODY[i]%$'\n'}"
    done
  done
  if [ "$PSTORE_N" -eq 0 ]; then
    kernel=none
    basis=none
  elif [ -n "$pages_ram" ]; then
    if [ "$pages_ram" -lt "$PSTORE_CAPTURE_PAGES_MAX" ]; then kernel=capture; else kernel=main; fi
    basis=pages_ram
  elif [ "$max_up" -ge $((PSTORE_MAIN_UPTIME_MIN * 1000000)) ]; then
    kernel=main
    basis=uptime
  else
    # No memory report in the dump and no long stamp: on a kdump box that is
    # the capture kernel's shape (it panics seconds into its boot).  The
    # basis is reported so a reader can see the verdict was NOT page-proven.
    kernel=capture
    basis=uptime-short
  fi
  case "$kernel" in
  none) token=none ;;
  capture)
    if [ "$deadlocked" -gt 0 ]; then token=capture-kernel-OOM; else token=capture-kernel-panicked; fi
    ;;
  main) token=main-kernel-panic-captured ;;
  esac
  printf 'token=%s\n' "$token"
  printf 'kernel=%s\n' "$kernel"
  printf 'basis=%s\n' "$basis"
  printf 'records=%s\n' "$PSTORE_N"
  printf 'lines=%s\n' "$lines"
  printf 'pages_ram=%s\n' "$pages_ram"
  printf 'max_uptime_s=%s\n' "$((max_up / 1000000))"
  printf 'min_kb=%s\n' "$min_kb"
  printf 'deadlocked=%s\n' "$deadlocked"
  printf 'panic_lines=%s\n' "$panic_lines"
  printf 'kinds=%s\n' "${PSTORE_KINDS:-none}"
  printf 'epochs=%s\n' "${PSTORE_EPOCHS:-unknown}"
  printf 'bytes=%s\n' "$PSTORE_BYTES"
  printf 'part_range=%s..%s\n' "$PSTORE_MAXPART" "$PSTORE_MINPART"
  printf 'gaps=%s\n' "$(pstore_part_gaps)"
  printf 'journal_entries=%s\n' "$PSTORE_PARSE_LINES"
  printf 'archive_hits=%s\n' "$PSTORE_ARCH_HITS"
  return 0
}

# --- live read ---------------------------------------------------------------

pstore_journalctl_cmd() { # -> the journalctl command every read below execs (the one seam a selftest stubs)
  printf '%s\n' "${PSTORE_JOURNALCTL:-${JOURNALCTL:-journalctl}}"
}

pstore_journal_fetch() { # <boot id or index> -> JSON lines on stdout
  # rc 0 = the journal answered (zero lines is a valid answer: "no pstore
  # data"); rc 1 = journalctl is missing or could not read that boot, which is
  # NOT an answer and must never be read as "no dump".
  local jc
  jc=$(pstore_journalctl_cmd)
  command -v "$jc" >/dev/null 2>&1 || {
    echo "pstore-records: journalctl command not found: $jc" >&2
    return 1
  }
  "$jc" --quiet --no-pager -b "$1" -o json SYSLOG_IDENTIFIER=systemd-pstore
}

pstore_facts_for() { # <next-boot id or ''> -> pstore_facts block plus fetch=ok|error|nonext; never fails
  local jsonl
  if [ -z "$1" ]; then
    printf 'token=none\nfetch=nonext\n'
    return 0
  fi
  if ! jsonl=$(pstore_journal_fetch "$1" 2>/dev/null); then
    printf 'token=none\nfetch=error\n'
    return 0
  fi
  pstore_jsonl_parse <<<"$jsonl"
  pstore_facts
  printf 'fetch=ok\n'
  return 0
}

pstore_fact() { # <key=value block> <key> -> value on stdout ('' and rc 1 when absent)
  local l
  while IFS= read -r l; do
    case "$l" in
    "$2="*)
      printf '%s\n' "${l#*=}"
      return 0
      ;;
    esac
  done <<<"$1"
  return 1
}

# shellcheck disable=SC2034  # read by the sourcing scripts
PSTORE_RECORDS_LOADED=1

# --- fixture selftest (runs only when this file is EXECUTED) -----------------

pstore_selftest() (
  # Subshell body: the scratch-dir EXIT trap and the exit statuses stay
  # scoped to the selftest.  Strict mode mirrors the sourcing scripts, so
  # the functions are exercised under the shell options they run with live.
  set -euo pipefail
  local failures=0 tmp block
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  check() { # <desc> <cmd...>
    local desc="$1"
    shift
    if "$@"; then
      :
    else
      echo "FAIL: $desc"
      failures=$((failures + 1))
    fi
  }

  PSTORE_ARCHIVE_ROOT='' # the direct archive read (root only) stays out of the legs
  PSTORE_STUB_DIR="$tmp"
  export PSTORE_STUB_DIR

  # Stub journalctl: the library's only external read goes through
  # PSTORE_JOURNALCTL, so the legs answer it from a fixture file, fail on
  # demand, and log every call to prove WHAT was asked.
  mkdir -p "$tmp/bin"
  {
    printf '#!%s\n' "$BASH"
    cat <<'STUB'
printf '%s\n' "$*" >>"$PSTORE_STUB_DIR/calls"
[ -z "${PSTORE_STUB_FAIL:-}" ] || { echo "stub journalctl: $PSTORE_STUB_FAIL" >&2; exit 1; }
cat "$PSTORE_STUB_DIR/${PSTORE_STUB_FILE:-records.jsonl}"
STUB
  } >"$tmp/bin/journalctl"
  chmod +x "$tmp/bin/journalctl"
  PSTORE_JOURNALCTL="$tmp/bin/journalctl"
  export PSTORE_JOURNALCTL

  # Capture-kernel dump of the 2026-11-25 cuts, shrunk to three parts: the
  # 512 MiB kernel speaks ("131118 pages RAM"), the inherited watermark
  # ("min:2097152kB") and its OOM panic sit on different parts, so the
  # decode has to assemble them.  Parts are stored NEWEST-first.
  cat >"$tmp/records.jsonl" <<'JSONL'
{"SYSLOG_IDENTIFIER":"systemd-pstore","_BOOT_ID":"0737ecd796a143208516dbcff4e46e07","FILE":"Panic#1 Part3\n<6>[    0.000000] Linux version 7.3.5 (stub)\n<4>[   13.062148] Node 0 DMA32 free:156464kB boost:0kB min:2097152kB low:2621440kB high:3145728kB\n<4>[   13.062170] 131118 pages RAM\n","MESSAGE":"PStore dmesg-efi_pstore-179560116503001 moved to /var/lib/systemd/pstore/1795601165/001/dmesg-efi_pstore-179560116503001","__REALTIME_TIMESTAMP":"1795601218315500"}
{"SYSLOG_IDENTIFIER":"systemd-pstore","_BOOT_ID":"0737ecd796a143208516dbcff4e46e07","FILE":"Panic#1 Part1\n<4>[   13.064394] Out of memory and no killable processes...\n<0>[   13.064395] Kernel panic - not syncing: System is deadlocked on memory\n","MESSAGE":"PStore dmesg-efi_pstore-179560116501001 moved to /var/lib/systemd/pstore/1795601165/001/dmesg-efi_pstore-179560116501001","__REALTIME_TIMESTAMP":"1795601218315583"}
{"SYSLOG_IDENTIFIER":"systemd-pstore","_BOOT_ID":"0737ecd796a143208516dbcff4e46e07","FILE":"Panic#1 Part2\n<4>[   13.064380] systemd invoked oom-killer: gfp_mask=0xcc0\n<4>[   13.064390] Out of memory: Killed process 1 (systemd) total-vm:42524kB\n","MESSAGE":"PStore dmesg-efi_pstore-179560116502001 moved to /var/lib/systemd/pstore/1795601165/001/dmesg-efi_pstore-179560116502001","__REALTIME_TIMESTAMP":"1795601218315540"}
JSONL
  : >"$tmp/calls"
  block=$(pstore_facts_for 0)
  check "records: fetch ok" grep -qx 'fetch=ok' <<<"$block"
  check "records: token capture-kernel-OOM" grep -qx 'token=capture-kernel-OOM' <<<"$block"
  check "records: basis pages_ram" grep -qx 'basis=pages_ram' <<<"$block"
  check "records: 3 records" grep -qx 'records=3' <<<"$block"
  check "records: pages_ram decoded" grep -qx 'pages_ram=131118' <<<"$block"
  check "records: min_kb decoded" grep -qx 'min_kb=2097152' <<<"$block"
  check "records: deadlocked counted" grep -qx 'deadlocked=1' <<<"$block"
  check "records: panic line counted" grep -qx 'panic_lines=1' <<<"$block"
  check "records: kinds" grep -qx 'kinds=Panic#1' <<<"$block"
  check "records: epochs" grep -qx 'epochs=1795601165' <<<"$block"
  check "records: part range" grep -qx 'part_range=3..1' <<<"$block"
  check "records: no missing part prints an EMPTY gaps" grep -qx 'gaps=' <<<"$block"
  check "query: next boot by id, validated selector" \
    grep -qxF -- '--quiet --no-pager -b 0 -o json SYSLOG_IDENTIFIER=systemd-pstore' "$tmp/calls"

  # Per-record listing and the assembled dump: dump order is highest part
  # first (Part1 holds the newest lines), so the assembled text ends with
  # the panic line.
  pstore_jsonl_parse <"$tmp/records.jsonl"
  pstore_records_list >"$tmp/list"
  check "list: one line per record" test "$(grep -c '^- record=' "$tmp/list")" = 3
  check "list: dump order, newest part last" \
    test "$(sed -n 's/^- record=Panic#1 Part\([0-9]*\) .*/\1/p' "$tmp/list")" = $'3\n2\n1'
  check "list: archive path from the message" \
    grep -qF -- '- record=Panic#1 Part1 archive=1795601165/001/dmesg-efi_pstore-179560116501001 ' "$tmp/list"
  check "list: first line of the part" \
    grep -qF 'first-line: <4>[   13.064394] Out of memory and no killable processes...' "$tmp/list"
  pstore_dump_text >"$tmp/dump"
  check "dump: oldest part first" test "$(head -n 1 "$tmp/dump")" = '<6>[    0.000000] Linux version 7.3.5 (stub)'
  check "dump: newest part last" \
    test "$(tail -n 1 "$tmp/dump")" = '<0>[   13.064395] Kernel panic - not syncing: System is deadlocked on memory'

  # Missing part: Part2 never made it out of the EFI ring.
  grep -v 'Part2' "$tmp/records.jsonl" >"$tmp/records.gap.jsonl"
  export PSTORE_STUB_FILE=records.gap.jsonl
  block=$(pstore_facts_for 0)
  check "gap: records=2" grep -qx 'records=2' <<<"$block"
  check "gap: the missing part is named" grep -qx 'gaps=2' <<<"$block"

  # No records: the journal ANSWERED with zero lines (a clean boot archived
  # nothing).  The block must say so and must not invent a part 0 gap.
  : >"$tmp/records.none.jsonl"
  export PSTORE_STUB_FILE=records.none.jsonl
  block=$(pstore_facts_for 0)
  check "none: token none" grep -qx 'token=none' <<<"$block"
  check "none: zero lines is a valid answer" grep -qx 'fetch=ok' <<<"$block"
  check "none: records=0" grep -qx 'records=0' <<<"$block"
  check "none: gaps stays EMPTY" grep -qx 'gaps=' <<<"$block"
  if grep -qx 'gaps=0' <<<"$block"; then
    echo "FAIL: none: gaps=0 reports a missing part 0 in a dump that does not exist (2026-11-26)"
    failures=$((failures + 1))
  fi

  # No next boot: the pulled boot is the newest one, so there is nothing to
  # ask the journal for.
  export PSTORE_STUB_FILE=records.jsonl
  : >"$tmp/calls"
  block=$(pstore_facts_for '')
  check "nonext: two-line block" test "$(printf '%s\n' "$block")" = $'token=none\nfetch=nonext'
  check "nonext: journal never asked" test ! -s "$tmp/calls"

  # Unreadable journal: NOT an answer.  It must surface as fetch=error and
  # never as the zero-record token alone.
  block=$(PSTORE_STUB_FAIL='boot -9 unreadable' pstore_facts_for 0)
  check "error: fetch=error" grep -qx 'fetch=error' <<<"$block"
  check "error: rc of the raw fetch" test "$(
    PSTORE_STUB_FAIL=x pstore_journal_fetch 0 >/dev/null 2>&1
    echo "$?"
  )" = 1

  # Main-kernel dump (the shape a working capture path leaves): long uptime
  # stamps, no memory report, an Oops kind.
  cat >"$tmp/records.main.jsonl" <<'JSONL'
{"SYSLOG_IDENTIFIER":"systemd-pstore","FILE":"Oops#2 Part1\n<4>[ 86412.345678] RIP: 0010:stub_init+0x1a/0x30\n<0>[ 86412.400000] Kernel panic - not syncing: Fatal exception\n","MESSAGE":"PStore dmesg-efi_pstore-179570000001002 moved to /var/lib/systemd/pstore/1795700000/001/dmesg-efi_pstore-179570000001002"}
JSONL
  export PSTORE_STUB_FILE=records.main.jsonl
  block=$(pstore_facts_for 0)
  check "main: token main-kernel-panic-captured" grep -qx 'token=main-kernel-panic-captured' <<<"$block"
  check "main: basis uptime" grep -qx 'basis=uptime' <<<"$block"
  check "main: oops kind" grep -qx 'kinds=Oops#2' <<<"$block"
  check "main: epoch from the record id" grep -qx 'epochs=1795700000' <<<"$block"

  # Older systemd: no FILE field, the record text sits in MESSAGE.
  cat >"$tmp/records.old.jsonl" <<'JSONL'
{"SYSLOG_IDENTIFIER":"systemd-pstore","MESSAGE":"Panic#1 Part1\n<0>[   13.064395] Kernel panic - not syncing: System is deadlocked on memory\n"}
JSONL
  export PSTORE_STUB_FILE=records.old.jsonl
  block=$(pstore_facts_for 0)
  check "old-systemd: record read from MESSAGE" grep -qx 'records=1' <<<"$block"
  check "old-systemd: capture kernel by uptime" grep -qx 'basis=uptime-short' <<<"$block"

  # JSON escapes: a quote, a tab and a newline inside one FILE value.  The
  # \uXXXX path goes through printf '%b' '\U...', which bash only turns
  # into UTF-8 under a UTF-8 locale (under LC_ALL=C it stays literal text,
  # found in the nix sandbox on 2026-11-26), so the leg names the locale
  # the records are read in.
  check "json: escapes decoded" test "$(LC_ALL=C.UTF-8 pstore_json_get '{"FILE":"a\"b\tc\n\u00e9"}' FILE)" = $'a"b\tc\né'

  if [ "$failures" -eq 0 ]; then
    echo "pstore-records selftest: all cases green"
    exit 0
  fi
  echo "pstore-records selftest: $failures FAILURE(S)"
  exit 1
)

# Sourcing runs nothing below this line: BASH_SOURCE is this file, $0 is
# the sourcing script.  Only a direct execution reaches the selftest.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-selftest}" in
  selftest)
    pstore_selftest
    ;;
  *)
    echo "usage: $0 [selftest] (this file is a library: the autopsy scripts source it)" >&2
    exit 2
    ;;
  esac
fi
