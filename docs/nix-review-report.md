# Nix Review Report: Fighting Nix's Native Capabilities

## Executive Summary

- **80+ .nix files reviewed** across `flake.nix`, `lib/`, `overlays/`, `modules/nixos/services/`, `modules/nixos/desktop/`, `platforms/`, `pkgs/`, and `tests/`
- **7 major anti-pattern categories** identified, spanning ~30 files
- The codebase is **functional and well-documented** — many "fights with Nix" have good reasons documented in AGENTS.md (e.g. the `import ../../../lib/default.nix lib` pattern is deliberate for `nix flake check` standalone evaluation). This report focuses on patterns where Nix-native alternatives exist but aren't used.

---

## Category 1: Manual Config String Building Instead of Nix Generators (HIGH)

The single biggest "fighting Nix" pattern. Multiple files hand-write YAML/JSON/key-value configs as interpolated Nix multiline strings, when `lib.generators.*` or `pkgs.formats.*` exist specifically for this.

### 1a. Hand-rolled YAML emitter — `homepage.nix:110-358`

```nix
mkGroup = name: services: "- ${name}:\n" + lib.concatStringsSep "" services;
mkService = name: props:
  "    - ${name}:\n"
  + lib.concatStringsSep "" (lib.mapAttrsToList (k: v: "        ${k}: ${v}\n") props);
...
pkgs.writeText "homepage-services.yaml" (lib.concatStringsSep "\n" groups);
```

**Problem:** A custom YAML emitter built from string concatenation. No quoting, no type handling, indentation-sensitive. Any value containing a `:` or newline breaks silently.

**Fix:** Use `(pkgs.formats.yaml {}).generate` over a structured attrset:

```nix
(pkgs.formats.yaml {}).generate "homepage-services.yaml" {
  services = [
    { "Pocket ID" = { href = ...; description = ...; icon = ...; }; };
    ...
  ];
}
```

### 1b. YAML compose files via `writeText` + manual interpolation — 4 files

| File                     | Lines    | YAML Content                                                     |
| ------------------------ | -------- | ---------------------------------------------------------------- |
| `twenty.nix:29-106`      | 77 lines | docker-compose.yml with `${...}` Nix + `''${...}` shell escaping |
| `manifest.nix:19-106`    | 87 lines | docker-compose.yml with JS healthcheck embedded                  |
| `voice-agents.nix:21-40` | 19 lines | docker-compose.whisper-asr.yml                                   |
| `openseo.nix:15-51`      | 36 lines | docker-compose.yml                                               |

**Problem:** Manual YAML string assembly with indentation, escaping `''${` for env-var passthrough, and no structural validation.

**Fix:** Build a Nix attrset and serialize with `builtins.toJSON` (docker-compose accepts JSON) or `lib.generators.toYAML {}`:

```nix
composeFile = pkgs.writeText "twenty-docker-compose.yml" (
  builtins.toJSON {
    name = "twenty";
    services.server = {
      image = images.twenty.ref;
      ports = [ "127.0.0.1:${toString serverPort}:3000" ];
      environment.PG_DATABASE_URL = "postgres://${pgUser}:\${PG_DATABASE_PASSWORD}@db:5432/${pgDb}";
      ...
    };
  }
);
```

### 1c. Minecraft `options.txt` via `writeText` — `minecraft.nix:68-256` (188 lines!)

```nix
clientOptionsFile = pkgs.writeText "options.txt" ''
  version:4790
  ao:true
  ...
  fov:${toString (fovToNormalized ccfg.fov)}
  ...
'';
```

**Fix:** Use `lib.generators.toKeyValue { mkKeyValue = k: v: "${k}:${toString v}"; }` over a structured attrset.

### 1d. ClickHouse XML via string interpolation — `signoz.nix:257-279`

```nix
services.clickhouse.extraServerConfig = ''
  <clickhouse>
    <keeper_server>
      <tcp_port>${toString ports.signoz-clickhouse-keeper}</tcp_port>
      ...
    </keeper_server>
  </clickhouse>
'';
```

**Fix:** Build a structured attrset and use `lib.generators.toXML {}`.

### 1e. Hand-written `.env` templates — `sops.nix:215-325` (~10 templates)

```nix
templates."forgejo-sync.env".content = ''
  FORGEJO_TOKEN=${config.sops.placeholder.forgejo_token}
  GITHUB_TOKEN=${config.sops.placeholder.github_token}
  GITHUB_USER=${config.sops.placeholder.github_user}
'';
```

**Fix:** Use `lib.generators.toKeyValue {}`:

```nix
content = lib.generators.toKeyValue {} {
  FORGEJO_TOKEN = config.sops.placeholder.forgejo_token;
  GITHUB_TOKEN = config.sops.placeholder.github_token;
  GITHUB_USER = config.sops.placeholder.github_user;
};
```

### 1f. YAML output post-processed with raw string concat — `dns-blocker.nix:346-362`

```nix
dnsblockdConfigFile = pkgs.writeText "dnsblockd-config.yaml" (
  lib.generators.toYAML {} { listen_addr = cfg.blockIP; ... }
  + lib.optionalString (cfg.categories != {}) "\ncategories_file: ${categoriesJSON}"
);
```

**Fix:** Put `categories_file` _inside_ the generator attrset conditionally:

```nix
lib.generators.toYAML {} ({
  listen_addr = cfg.blockIP;
  ...
} // lib.optionalAttrs (cfg.categories != {}) { categories_file = "${categoriesJSON}"; })
```

### 1g. `builtins.toJSON` interpolated into shell single-quotes — `pocket-id.nix:217,228`

```nix
UPDATE_RESPONSE=$(api_put "/api/oidc/clients/$EXISTING_CLIENT" '${builtins.toJSON clientAttrs}')
```

**Problem:** Any client name containing a single quote breaks the script (injection hazard).

**Fix:** Pre-generate JSON at build time with `(pkgs.formats.json {}).generate` and pass `--data @"${jsonFile}"` to curl.

---

## Category 2: `//` on `serviceConfig` Instead of `mkMerge` (HIGH)

The `harden` and `serviceDefaults` helpers emit `mkDefault`-tagged values. The `//` operator is a **shallow merge** that **discards module-system priority annotations**. If `harden` sets `MemoryMax = lib.mkDefault "512M"` and another module later overrides it, `//` silently clobbers the priority. `mkMerge` preserves it.

### Affected files:

| File               | Line(s) | Pattern                                            |
| ------------------ | ------- | -------------------------------------------------- |
| `gatus-config.nix` | 539-559 | `harden {...} // serviceDefaults {...} // {...}`   |
| `hermes.nix`       | 229-263 | `{...} // serviceDefaults {...} // harden {...}`   |
| `twenty.nix`       | 179-185 | `harden {...} // { Type = "oneshot"; ... }`        |
| `immich.nix`       | 76-92   | `harden {...} // serviceDefaults {}` (3 instances) |

**Fix:**

```nix
# BEFORE (broken priority)
serviceConfig = harden { MemoryMax = "512M"; } // serviceDefaults {} // { ... };

# AFTER (correct priority resolution)
serviceConfig = lib.mkMerge [
  (harden { MemoryMax = "512M"; })
  (serviceDefaults {})
  { ... }
];
```

> **Note:** AGENTS.md documents that `lib.mkMerge` + flake-parts "does not work — use inline config or imports." This refers to top-level `config = lib.mkMerge [...]` in a flake-parts module, NOT to `serviceConfig` inside a `systemd.services.<name>` definition. Using `mkMerge` on `serviceConfig` is safe and correct — it's a local attrset value, not a flake-parts config merge.

---

## Category 3: Shell Scripts Embedded in Nix Strings Instead of `writeShellApplication` (HIGH)

### 3a. 123-line embedded shell script — `nvme-health-monitor.nix:14-137`

```nix
checkScript = ''
  STATE_DIR="$HOME/.local/state/nvme-health-monitor"
  mkdir -p "$STATE_DIR"
  DEVICE="${cfg.device}"
  ...
  SMART=$(nvme smart-log -o json "$DEVICE" 2>/dev/null) || exit 0
  extract() {
    local key="$1"
    echo "$SMART" | grep -oP "\"''${key}\"\s*:\s*\K[0-9]+"   # ← JSON parsed with grep!
  }
  ...
'';
```

**Problems:**

1. 123 lines of shell as an interpolated Nix string — untestable, unlintable
2. JSON output requested (`-o json`) then parsed with `grep -oP` regex — fragile, breaks on nested keys
3. Runtime deps (`nvme`, `jq`) not declared via `runtimeInputs`

**Fix:** Move to `scripts/nvme-health-check.sh`, load via `builtins.readFile`, pass config via environment variables. Add `jq` to runtime deps and parse properly:

```bash
CRITICAL_WARNING=$(echo "$SMART" | jq -r '.critical_warning')
```

### 3b. 70-line embedded shell script — `disk-monitor.nix:14-85`

Same pattern. Also uses `lib.concatStringsSep " "` for unsafe shell array generation:

```nix
THRESHOLDS=(${lib.concatStringsSep " " (map toString cfg.thresholds)})
MOUNT_POINTS=(${lib.concatStringsSep " " cfg.fileSystems})
```

**Fix:** Extract to script file. Use `lib.escapeShellArgs` for array safety.

### 3c. 70-line inline `script` with full package paths — `signoz.nix:366-434`

```nix
script = ''
  SIGNOZ_URL="http://..."
  WEBHOOK_FILE="${config.sops.secrets.discord_alert_webhook_url.path}"
  ...
  ${pkgs.coreutils}/bin/echo "Deploying notification channels..."
  WEBHOOK_URL=$(${pkgs.coreutils}/bin/cat "$WEBHOOK_FILE")
  EXISTING_CHANNELS=$(${pkgs.curl}/bin/curl -sf ...)
  EXISTING_CHANNEL_ID=$(echo "$EXISTING_CHANNELS" | ${pkgs.jq}/bin/jq -r ...)
'';
```

Every command is spelled as `${pkgs.x}/bin/...` even though the service declares `path = [pkgs.curl pkgs.jq pkgs.coreutils]`.

**Fix:** `pkgs.writeShellApplication { runtimeInputs = [pkgs.curl pkgs.jq]; text = ''...''; }` — bare commands, auto PATH.

### 3d. `writeShellScriptBin` wrapper with hardcoded paths — `signoz.nix:316-323`

```nix
wrapper = pkgs.writeShellScriptBin "signoz-wrapper" ''
  if [ ! -f '${jwtFile}' ]; then
    ${pkgs.openssl}/bin/openssl rand -base64 48 > '${jwtFile}'   # ← hardcoded path
    chmod 400 '${jwtFile}'
  fi
  export SIGNOZ_TOKENIZER_JWT_SECRET="$(cat '${jwtFile}')"
  exec ${lib.getExe packages.signoz} server --config /etc/signoz/signoz.yaml
'';
```

**Fix:** `writeShellApplication { runtimeInputs = [pkgs.openssl]; ... }` — use bare `openssl`.

### 3e. Inline `preStart` with full paths — `pocket-id.nix:521-523`

```nix
preStart = ''
  ${pkgs.coreutils}/bin/timeout 120 ${pkgs.bash}/bin/bash -c 'until ${pkgs.curl}/bin/curl -sf ...'
'';
```

**Fix:** `writeShellApplication` with `runtimeInputs = [pkgs.coreutils pkgs.curl]`.

### 3f. Inline `bash -c` with double-escaping — `manifest.nix:116`, `twenty.nix:137`

```nix
execStart = "${pkgs.bash}/bin/bash -c '... $(date +%%Y%%m%%d_%%H%%M%%S).sql ... find ... -mtime +30 -delete'";
```

**Fix:** `writeShellApplication` with `runtimeInputs = [pkgs.docker-compose pkgs.findutils pkgs.coreutils]`.

### 3g. Inline backup `script` without declared deps — `immich.nix:119-128`

```nix
script = ''
  set -euo pipefail
  backupDir="${config.services.immich.mediaLocation}/database-backup"
  pg_dump --host=/run/postgresql --clean --if-exists --dbname=${...} \
    > "$backupDir/immich-$stamp.sql"
  find "$backupDir" -name "immich-*.sql" -mtime +7 -delete
'';
```

`pg_dump`, `find`, `date` are undeclared runtime deps.

**Fix:** `writeShellApplication` with `runtimeInputs = [config.services.postgresql.package pkgs.findutils]`.

---

## Category 4: Deep Relative Imports `import ../../../lib/default.nix lib` (MEDIUM)

**Present in ~20+ module files.** Every service module begins with:

```nix
inherit (import ../../../lib/default.nix lib) harden serviceDefaults ports ...;
```

**Note:** AGENTS.md explicitly documents this as **deliberate**: `nix flake check` evaluates each `nixosModule` standalone (no injected args), so helpers must be self-imported. Injecting via `_module.args` would either break the standalone check or keep the import as a default.

**However**, there are two improvements that reduce fragility without breaking the standalone check:

1. **Consolidate within each file** — some files import `lib/default.nix` **twice** in different `let` scopes (e.g., `signoz.nix:11` and `signoz.nix:111-118`). Import once at the top.
2. **Use `builtins.path` for stability** — `import (builtins.path { path = ../../../lib/default.nix; name = "systemnix-lib"; }) lib` gives a fixed store path name.

### Special case: `monitor365.nix:34` bypasses the port collision checker

```nix
ports = (import ../../../lib/ports.nix).ports;
```

This imports the **raw** `ports.nix` directly, skipping the duplicate-port-detection wrapper in `lib/default.nix:127-137`. Every other module imports `lib/default.nix lib` and gets the checked `ports`.

**Fix:** `inherit (import ../../../lib/default.nix lib) ports;`

### Special case: `sops.nix:3` — most fragile path

```nix
secretsDir = ./../../../platforms/nixos/secrets;
```

Three `../` with a leading `./` — breaks silently on any move.

---

## Category 5: `system.activationScripts` for Directory Setup Instead of `systemd.tmpfiles.rules` (MEDIUM)

### 5a. `hermes.nix:176-202`

```nix
system.activationScripts."hermes-setup" = lib.stringAfter [...] ''
  mkdir -p ${cfg.stateDir}/{sessions,skills,memories,cron,cache,logs/curator,workspace}
  chown -R ${cfg.user}:${cfg.group} ${cfg.stateDir}
  chmod 2770 ${cfg.stateDir} ${cfg.stateDir}/{...}
  setfacl -m "g:${cfg.group}:r-x" "$primaryHome" ...
'';
```

**Fix:** Use `systemd.tmpfiles.rules` with the existing `mkStateDir` helper:

```nix
systemd.tmpfiles.rules = map (d: "d ${cfg.stateDir}/${d} 2770 ${cfg.user} ${cfg.group} -")
  ["sessions" "skills" "memories" "cron" "cache" "logs/curator" "workspace"];
```

(Isolate the `setfacl` grant into a small oneshot unit if it's genuinely needed.)

### 5b. `discordsync.nix:81-88`

```nix
system.activationScripts."discordsync-setup" = lib.stringAfter [...] ''
  mkdir -p ${cfg.stateDir}/attachments
  chown -R ${cfg.user}:${cfg.group} ${cfg.stateDir}
  chmod 2770 ${cfg.stateDir} ${cfg.stateDir}/attachments
'';
```

**Fix:** Same pattern — `systemd.tmpfiles.rules`.

### 5c. `configuration.nix:135-138`

```nix
system.activationScripts.home-manager-profile-dirs = ''
  mkdir -p /nix/var/nix/profiles/per-user/${config.users.primaryUser}
  chown ${config.users.primaryUser}:users /nix/var/nix/profiles/per-user/${config.users.primaryUser}
'';
```

**Fix:** `systemd.tmpfiles.rules`.

---

## Category 6: Hardcoded Paths Instead of Deriving From Config (MEDIUM)

### 6a. Hardcoded `/home/${cfg.user}/...` in option defaults — 4 files

| File                         | Line(s)    | Code                                                       |
| ---------------------------- | ---------- | ---------------------------------------------------------- |
| `file-and-image-renamer.nix` | 27, 40, 65 | `default = "/home/${cfg.user}/Desktop"`                    |
| `monitor365.nix`             | 72         | `default = "/home/${primaryUser}/.local/share/monitor365"` |
| `homepage.nix`               | 14         | `stateDir = "/var/lib/homepage-dashboard"`                 |
| `forgejo.nix`                | 505        | `stateDir = "/var/lib/forgejo"`                            |

**Fix:** Derive from the user record: `"${config.users.users.${cfg.user}.home}/Desktop"`

### 6b. `configuration.nix:276-280` — hardcoded `/home/` paths

```nix
watchPaths = [
  "/home/${config.users.primaryUser}/Downloads"
  "/home/${config.users.primaryUser}/Pictures"
];
syntheticApiKeyFile = "/home/${config.users.primaryUser}/.synthetic_api_key";
```

### 6c. `pocket-id.nix:298` — hardcoded email domain

```nix
default = "noreply@cloud.larsartmann.com";
```

**Fix:** `default = "noreply@${domain}";` (the module already has `domain` in scope).

---

## Category 7: `with pkgs;` in Package Lists (LOW)

| File                     | Line(s)  |
| ------------------------ | -------- |
| `configuration.nix`      | 124, 177 |
| `ai-stack.nix`           | 96       |
| `security-hardening.nix` | 64       |

**Problem:** `with pkgs;` makes variable sources unclear and silently shadows on name collision.

**Fix:** Explicit `pkgs.` prefixes or `builtins.attrValues { inherit (pkgs) firefox obs-studio; }`.

---

## Category 8: Miscellaneous Patterns (LOW-MEDIUM)

### 8a. JSON parsed with `grep -oP` instead of `jq` — `nvme-health-monitor.nix:47-60`

```bash
SMART=$(nvme smart-log -o json "$DEVICE" 2>/dev/null)
extract() { echo "$SMART" | grep -oP "\"''${key}\"\s*:\s*\K[0-9]+"; }
```

The script requests JSON then parses it with regex. **Fix:** Add `jq` to runtimeInputs.

### 8b. Raw `iptables` in `extraCommands` — `minecraft.nix:451-455`

```nix
networking.firewall.extraCommands = ''
  iptables -A nixos-fw -p tcp --dport ${toString cfg.port} -s ${...} -j nixos-fw-accept
'';
```

**Fix:** Use declarative `networking.firewall.allowedTCPPorts` or interface-scoped rules.

### 8c. Duplicated IP list — `security-hardening.nix:37,48`

```nix
DEFAULT.ignoreip = "127.0.0.1/8 ::1 ${config.networking.local.subnet} 10.0.0.0/8 172.16.0.0/12";
# ...same string again on line 48...
```

**Fix:** Extract to a `let` binding.

### 8d. `builtins.listToAttrs (map ...)` instead of `lib.genAttrs` — `manifest.nix:128-144`

```nix
secrets = builtins.listToAttrs (map (name: { inherit name; value = {...}; }) [...]);
```

**Fix:** `lib.genAttrs [...] (_: { ... })`.

### 8e. `secretsDir + "/${file}"` instead of `lib.path.append` — `sops.nix` (~10 occurrences)

**Fix:** `lib.path.append secretsDir file` keeps path type, catches typos at eval time.

### 8f. Manual bool→string — `discordsync.nix:120-124`

```nix
"BACKFILL_ON_STARTUP=${if cfg.backfillOnStartup then "true" else "false"}"
```

**Fix:** `lib.boolToString cfg.backfillOnStartup`.

### 8g. `concatStringsSep "\n"` instead of `concatLines` — `dns-blocker.nix:65-67`

**Fix:** `lib.concatLines cfg.whitelist`.

### 8h. Missing `harden`/`serviceOneshotDefaults` on oneshot services — `immich.nix:105-129`

The db-backup service runs completely unhardened — no `harden {}`, no `serviceOneshotDefaults {}`, unlike every other service in the codebase.

### 8i. Missing module `options` — `immich.nix` (entire file)

The module defines no options of its own — relies entirely on upstream `config.services.immich.enable` but adds backup timers, OAuth wiring, and acceleration config with no documented extension points.

---

## Summary by Impact

| Priority | Pattern                                              | Files                                                                                        | Effort                                |
| -------- | ---------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------- |
| **HIGH** | Manual YAML/JSON/XML via `writeText` + string interp | homepage, twenty, manifest, voice-agents, openseo, minecraft, signoz, dns-blocker, pocket-id | Medium — convert each to `generators` |
| **HIGH** | `//` on `serviceConfig` breaks `mkForce` priority    | gatus, hermes, twenty, immich                                                                | Low — wrap in `mkMerge [...]`         |
| **HIGH** | Shell scripts embedded in Nix strings                | nvme-health-monitor (123 lines), disk-monitor (70 lines), signoz (70 lines)                  | Medium — extract to script files      |
| **MED**  | `activationScripts` for mkdir/chown                  | hermes, discordsync, configuration                                                           | Low — convert to `tmpfiles.rules`     |
| **MED**  | Hardcoded `/home/` paths in defaults                 | file-and-image-renamer, monitor365, homepage, configuration, pocket-id                       | Low — derive from user record         |
| **MED**  | `with pkgs;` in lists                                | configuration, ai-stack, security-hardening                                                  | Low — add explicit prefixes           |
| **LOW**  | Deep relative imports (documented as deliberate)     | ~20+ files                                                                                   | High — requires flake.lib restructure |
| **LOW**  | Misc (grep JSON, raw iptables, duplicated strings)   | nvme, minecraft, security-hardening                                                          | Low                                   |

## What's Done Well

- **`harden` + `serviceDefaults` helpers** — excellent abstraction, used consistently across all services
- **`ports.nix` with collision detection** — the `builtins.throw` on duplicate ports is a great safety net
- **`mkFilesystem` validator** — validates mount options at eval time
- **`forgejo.nix`** — the cleanest service module; all complex logic is in `writeShellApplication` derivations
- **`_signoz-alerts.nix`** — correctly uses `builtins.toJSON` for structured rule generation
- **`flake.nix` auto-discovery** of NixOS modules from directory structure
- **`follows` chains** are thorough — nearly every input follows nixpkgs
- **`dns-failover.nix`** — clean module with typed options, descriptions, and assertions
- **Gatus health checks** are universal — every service is monitored
