# print-safe: print PDF/PNG on the Canon MG2500 without the Gutenprint
# gray-ink flood. Nixified 2026-09-16 from the working ~/.local/bin script
# (byte-identical body; verified by post-build diff). See the script header
# for the full driver-bug rationale (Gutenprint 5.3.5 turns any gray pixel
# into massive dot-noise; this renders pure black/white and bypasses the
# broken filter chain via lp -o raw).
{
  writeShellApplication,
  poppler-utils,
  python3,
  coreutils,
  gawk,
  gnugrep,
  cups,
  bash,
}:
writeShellApplication {
  name = "print-safe";

  runtimeInputs = [
    poppler-utils
    python3
    coreutils
    gawk
    gnugrep
    cups
    bash
  ];

  # NOTE: cups filters (imagetoraster, rastertogutenprint) and the PPD are
  # consumed from the HOST CUPS install (/var/lib/cups/path, /etc/cups/ppd)
  # by absolute path -- this tool is host-coupled by design.
  text = ''
    # print-safe — print PDF/PNG on the Canon MG2500 without the Gutenprint gray-ink flood.
    #
    # The Gutenprint 5.3.5 "bjc-MG2500-series" driver turns any gray pixel into
    # massive dot-noise (a light-gray A4 page = 19 MB of ink commands = solid
    # black page). This script renders input as PURE BLACK/WHITE only:
    #   PDF -> pdftoppm (antialiasing OFF) -> threshold at 156 -> imagetoraster
    #      -> rastertogutenprint -> lp -o raw (bypasses the broken filter chain)
    # A size guard aborts before printing if the stream looks pathological.
    #
    # Usage: print-safe file.pdf [copies]     (copies default: 1)

    set -euo pipefail

    PRINTER="Canon_MG2500_series"
    COPIES="''${2:-1}"
    # Overridable for fault-injection tests (stub filter dir); production
    # keeps the host CUPS filter path.
    FILTER_DIR="''${PRINT_SAFE_FILTER_DIR:-/var/lib/cups/path/lib/cups/filter}"
    export PPD="/etc/cups/ppd/''${PRINTER}.ppd"

    [ -f "$1" ] || { echo "print-safe: file not found: $1" >&2; exit 1; }
    [ -x "$FILTER_DIR/imagetoraster" ] || { echo "print-safe: imagetoraster missing" >&2; exit 1; }
    [ -x "$FILTER_DIR/rastertogutenprint.5.3" ] || { echo "print-safe: rastertogutenprint missing" >&2; exit 1; }

    WORK="$(mktemp -d /tmp/print-safe.XXXXXX)"
    trap 'rm -rf "$WORK"' EXIT
    SRC="$WORK/page"

    case "$1" in
      *.pdf) pdftoppm -gray -r 600 -aa no -aaVector no -singlefile "$1" "$SRC" ;;
      *.png|*.pgm) cp "$1" "$SRC.pgm" 2>/dev/null || cp "$1" "$SRC.img" ;;
      *) echo "print-safe: unsupported type (need .pdf or .png/.pgm): $1" >&2; exit 1 ;;
    esac
    [ -f "$SRC.pgm" ] || { echo "print-safe: rendering produced no PGM" >&2; exit 1; }

    python3 - "$SRC.pgm" "$WORK/bw.png" <<'EOF'
    import sys, zlib, struct
    src, dst = sys.argv[1], sys.argv[2]
    data = open(src, 'rb').read()
    idx, tokens = 0, []
    while len(tokens) < 4:
        while data[idx:idx+1].isspace(): idx += 1
        if data[idx:idx+1] == b'#':
            while data[idx:idx+1] != b'\n': idx += 1
            continue
        s = idx
        while not data[idx:idx+1].isspace(): idx += 1
        tokens.append(data[s:idx])
    idx += 1
    w, h = int(tokens[1]), int(tokens[2])
    px = bytearray(data[idx:idx+w*h])
    dark = sum(1 for v in px if v < 156)
    for i, v in enumerate(px): px[i] = 0 if v < 156 else 255
    print(f"print-safe: {dark*100.0/len(px):.1f}% ink coverage")
    raw = b'''.join(b'\x00' + bytes(px[r*w:(r+1)*w]) for r in range(h))
    def chunk(t, d):
        c = t + d
        return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c))
    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(bytes(raw), 6))
           + chunk(b'IEND', b'''))
    open(dst, 'wb').write(png)
    EOF

    # imagetoraster exits 1 from a known free() crash, and since the
    # 2026-11-10 incident it sometimes crashes BEFORE or MID-WRITE (0-byte
    # and truncated outputs observed) with its stderr swallowed above -- so
    # the exit code is ignored and the output is validated, with retries.
    ATTEMPTS=0
    while :; do
      ATTEMPTS=$((ATTEMPTS + 1))
      rm -f "$WORK/page.raster"
      { bash -c "'$FILTER_DIR/imagetoraster' 1 lars print-safe 1 'media=A4 ColorModel=RGB' \
        '$WORK/bw.png' > '$WORK/page.raster'" 2>/dev/null; } 2>/dev/null || true
      if python3 - "$WORK/page.raster" <<'PYEOF' 2>/dev/null
    import struct, sys
    d = open(sys.argv[1], 'rb').read()
    if d[:3] != b'3Sa':
        sys.exit(1)
    height = struct.unpack('<I', d[380:384])[0]
    bytes_per_line = struct.unpack('<I', d[396:400])[0]
    expected = 1800 + height * bytes_per_line
    print(f"print-safe: raster {len(d)} bytes (expected {expected}, page {height} x {bytes_per_line})")
    sys.exit(0 if len(d) == expected else 1)
    PYEOF
      then
        break
      fi
      if [ "$ATTEMPTS" -ge 5 ]; then
        echo "print-safe: imagetoraster produced an invalid/incomplete raster after $ATTEMPTS attempts" >&2
        exit 1
      fi
      echo "print-safe: imagetoraster attempt $ATTEMPTS failed validation, retrying..." >&2
      sleep 1
    done

    "$FILTER_DIR/rastertogutenprint.5.3" 1 lars print-safe 1 \
      'media=A4 ColorModel=RGB' "$WORK/page.raster" > "$WORK/printer.bin" 2>/dev/null

    STREAM_SIZE="$(stat -c%s "$WORK/printer.bin")"
    echo "print-safe: printer stream ''${STREAM_SIZE} bytes (white=45k, black=127k, gray-flood=4M+)"
    if [ "$STREAM_SIZE" -gt 1500000 ]; then
      echo "print-safe: ABORTED — stream exceeds safety ceiling (gray flood regression?)" >&2
      exit 1
    fi
    [ "$STREAM_SIZE" -gt 10000 ] || { echo "print-safe: ABORTED — stream nearly empty" >&2; exit 1; }

    if [ "''${PRINT_SAFE_DRY_RUN:-0}" = "1" ]; then
      echo "print-safe: dry run — stream verified at $WORK/printer.bin, nothing sent."
      trap - EXIT
      exit 0
    fi

    cupsenable "$PRINTER" 2>/dev/null || true
    JOB="$(lp -d "$PRINTER" -o raw -n "$COPIES" "$WORK/printer.bin" | awk '{print $4}' | tr -d '.')"
    echo "print-safe: job $JOB sent ($COPIES copies), waiting for printer..."
    WAITED=0
    while [ "$WAITED" -lt 600 ]; do
      sleep 5; WAITED=$((WAITED + 5))
      lpstat -W not-completed 2>/dev/null | grep -q "$JOB" || break
    done
    cupsdisable "$PRINTER" 2>/dev/null || true
    echo "print-safe: done — queue re-disabled (fail-safe). Re-enable with: cupsenable $PRINTER"
  '';
}
