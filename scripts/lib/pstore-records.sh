#!/usr/bin/env bash
# pstore-records.sh: shared EFI-pstore record decoding for the boot autopsy
# scripts (the "pstore (EFI) crash dump" section of boot-evidence-pull.sh and
# the `kdump=` verdict line of crash-triage.sh).  Sourced, never executed.
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
# sandbox with bash + coreutils + grep only: no jq, no python, no awk).
#
# Testable seams (live default in parentheses):
#   PSTORE_JOURNALCTL      journalctl command ("journalctl", or the value of
#                          crash-triage.sh's JOURNALCTL when that is set)
#   PSTORE_ARCHIVE_ROOT    prefix of /var/lib/systemd/pstore; the archive
#                          files are read directly when readable, which in
#                          practice means a root run (/var/lib/systemd/pstore;
#                          an EMPTY value disables the direct read)
#
# verdict tokens (shared vocabulary, keep both scripts in step):
#   capture-kernel-OOM           the log is the capture kernel's and it died
#                                of the inherited watermark: the MAIN kernel's
#                                panic text is NOT in pstore
#   capture-kernel-panicked      the log is the capture kernel's, no OOM marker
#   main-kernel-panic-captured   the log is the main kernel's (a Panic# or
#                                Oops# record with long uptime stamps)
#   none                         the next boot archived no pstore dump

PSTORE_CAPTURE_PAGES_MAX=2000000
PSTORE_MAIN_UPTIME_MIN=600
# A part number above this bound is treated as a malformed header, so the
# descending scan below can never loop on a garbage number.
PSTORE_MAX_PART=100000

# ── JSON (journalctl -o json writes one object per line; values are strings
# or numbers) ─────────────────────────────────────────────────────────────

pstore_json_unescape() { # <escaped string body> -> decoded text (adds no newline)
  local s="$1" out='' pre esc hex cp lo ch
  while :; do
    pre=${s%%\\*}
    out+=$pre
    s=${s#"$pre"}
    case "$s" in
    '') break ;;
    '\')
      # a lone trailing backslash is not a valid escape: keep it literally
      out+='\'
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
        out+='\u' # not an escape this decoder knows: keep it literally
        continue
      fi
      s=${s:4}
      printf -v cp '%d' "0x$hex"
      # UTF-16 surrogate pair: combine the high and the low half
      if [ "$cp" -ge 55296 ] && [ "$cp" -le 56319 ] && [ "${s:0:2}" = '\u' ] &&
        [[ ${s:2:4} =~ ^[dcDC][0-9a-fA-F]{3}$ ]]; then
        printf -v lo '%d' "0x${s:2:4}"
        if [ "$lo" -ge 56320 ] && [ "$lo" -le 57343 ]; then
          s=${s:6}
          cp=$((65536 + (cp - 55296) * 1024 + (lo - 56320)))
        fi
      fi
      printf -v ch '%b' "\\U$(printf '%08x' "$cp")"
      out+=$ch
      ;;
    *) out+='\'$esc ;;
    esac
  done
  printf '%s' "$out"
}

pstore_json_get() { # <json object> <key> -> decoded string value; rc 1 when absent
  # Minimal object walker (keys are plain identifiers, values are strings or
  # numbers): it never mistakes a `"key":"` sequence INSIDE a string value for
  # the real key, which a plain substring search would.
  local s="$1" want="$2" k v chunk out tb hit
  s=${s#"${s%%[![:space:]]*}"}
  case "$s" in '{'*) ;; *) return 1 ;; esac
  s=${s:1}
  while :; do
    s=${s#"${s%%[![:space:]]*}"}
    case "$s" in
    '' | '}'*) return 1 ;;
    esac
    hit=0
    case "$s" in
    '"'"$want"'" | '"'"$want"'"[[:space:]]*) hit=1 ;;
    '"'"*) ;;
    *) return 1 ;;
    esac
    s=${s:1}
    k=${s%%'"'*}
    s=${s#*'"'}
    s=${s#"${s%%[![:space:]]*}"}
    case "$s" in ':'*) ;; *) return 1 ;; esac
    s=${s:1}
    s=${s#"${s%%[![:space:]]*}"}
    case "$s" in
    '"'*)
      s=${s:1}
      v=''
      while :; do
        case "$s" in
        '"'*) ;;
        *) return 1 ;; # unterminated string
        esac
        chunk=${s%%'"'*}
        v+=$chunk
        tb=0
        while [[ $chunk == *'\' ]]; do
          tb=$((tb + 1))
          chunk=${chunk%?}
        done
        s=${s#*'"'}
        if [ $((tb % 2)) -eq 1 ]; then
          v+='"' # the quote was escaped: the string continues
          continue
        fi
        break
      done
      if [ "$hit" = 1 ]; then
        pstore_json_unescape "$v"
        return 0
      fi
      ;;
    *) # number or literal
      v=${s%%[,\}]*}
      s=${s#"$v"}
      if [ "$hit" = 1 ]; then
        printf '%s' "$v"
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

# ── records: parse, assemble, classify ────────────────────────────────────
# pstore_jsonl_parse fills these globals in the CALLER shell, so call it
# with a redirect (`pstore_jsonl_parse < file` or `<<< "$jsonl"`), never as a
# pipeline segment.  Index of PSTORE_BODY = count * 1000000 + part, so a dump
# set that holds several panic counts cannot collide.

PSTORE_N=0          # records kept
PSTORE_PARSE_LINES=0 # JSON lines seen (record entries and other messages)
PSTORE_BODY=()      # record body (header line removed), keyed count*1000000+part
PSTORE_MAXCOUNT=0
PSTORE_MAXPART=0
PSTORE_MINPART=0
PSTORE_EPOCHS=''    # distinct dump ids (epoch of the record id), first-seen order
PSTORE_KINDS=''     # distinct header kinds, e.g. "Panic#1"
PSTORE_BYTES=0      # bytes of the assembled dump text
PSTORE_ARCH_HITS=0  # records whose body came from the archive (root run)

pstore_epoch_of() { # <MESSAGE text> -> epoch of the record id ('' when undecodable)
  local m="$1" id
  if [[ $m =~ pstore/([0-9]+)/ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ $m =~ efi_pstore-([0-9]+) ]]; then
    id=${BASH_REMATCH[1]}
    # <epoch><part:02d><count:03d>: drop the last five digits
    printf '%s\n' "${id%?????}"
    return 0
  fi
  return 1
}

pstore_jsonl_parse() { # stdin: `journalctl -o json` lines -> PSTORE_* globals
  local line f m hdr body kind count part epoch idx rel b2
  local nl=$'\n'
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
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    PSTORE_PARSE_LINES=$((PSTORE_PARSE_LINES + 1))
    case "$line" in
    *FILE* | *'Panic#'* | *'Oops#'*) ;;
    *) continue ;;
    esac
    f=$(pstore_json_get "$line" FILE) || f=''
    case "$f" in
    '') f=$(pstore_json_get "$line" MESSAGE) || f='' ;; # older systemd: no FILE field
    esac
    hdr=${f%%"$nl"*}
    case "$hdr" in
    'Panic#'*\ Part* | 'Oops#'*\ Part*) ;;
    *) continue ;;
    esac
    body=${f#"$hdr"}
    body=${body#"$nl"}
    m=$(pstore_json_get "$line" MESSAGE) || m=''
    # Root run: the archived file wins when it is readable (the journal copy
    # stays the unprivileged path).  The file may repeat the header line.
    if [ -n "$PSTORE_ARCHIVE_ROOT" ]; then
      case "$m" in
      *' moved to /var/lib/systemd/pstore/'*)
        rel=${m#* moved to /var/lib/systemd/pstore/}
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
        ;;
      esac
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
    PSTORE_N=$((PSTORE_N + 1))
    PSTORE_BYTES=$((PSTORE_BYTES + $(printf '%s' "$body" | wc -c)))
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
    epoch=$(pstore_epoch_of "$m") || epoch=''
    case " $PSTORE_EPOCHS " in
    *" ${epoch:-unknown} "*) ;;
    *) PSTORE_EPOCHS="${PSTORE_EPOCHS:+$PSTORE_EPOCHS }${epoch:-unknown}" ;;
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

pstore_part_gaps() { # part numbers missing between the lowest and the highest part ('' when none)
  local p c found gaps=''
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
  local re_ram='^[^]]*\[[0-9.]+\][[:space:]]*([0-9]+) pages RAM$'
  local re_zone='^[^]]*\[[0-9.]+\][[:space:]]*Node [0-9]+ [A-Za-z0-9_]+ free:'
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
      done <<< "${PSTORE_BODY[i]}"
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

# ── live read ─────────────────────────────────────────────────────────────

pstore_journal_fetch() { # <boot id or index> -> JSON lines on stdout
  # rc 0 = the journal answered (zero lines is a valid answer: "no pstore
  # data"); rc 1 = journalctl is missing or could not read that boot, which is
  # NOT an answer and must never be read as "no dump".
  local jc="${PSTORE_JOURNALCTL:-${JOURNALCTL:-journalctl}}"
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
  pstore_jsonl_parse <<< "$jsonl"
  pstore_facts
  printf 'fetch=ok\n'
  return 0
}

pstore_fact() { # <key=value block> <key> -> value ('' and rc 1 when absent)
  local l
  while IFS= read -r l; do
    case "$l" in
    "$2="*)
      printf '%s\n' "${l#*=}"
      return 0
      ;;
    esac
  done <<< "$1"
  return 1
}

# Marker for the sourcing scripts: the library is present and usable.
PSTORE_RECORDS_LOADED=1
