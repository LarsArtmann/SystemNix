# Crush Configuration (interactive AI sessions)

How the `crush` AI assistant is configured on evo-x2: providers, keys,
models, LSPs, and the verification workflow for changing any of it.

- **Config**: HM-managed `~/.config/crush/crushrc` (Bash, loaded at every
  crush start) — source: `platforms/nixos/users/home.nix`
- **Secrets**: sops `platforms/nixos/secrets/crush.yaml` → `/run/secrets/<name>`
  (lars:users 0400), injected at load via the `crush_key` helper
- **Auth store**: `~/.local/share/crush/crush.json` — machine-owned; ONLY
  hyper's OAuth state lives there (self-rotating, by design). Never manage or
  symlink this file; never put static keys back into it
- **Catalog**: `~/.local/share/crush/providers.json` — auto-updated by crush;
  provider definitions (base_url, model lists) merge with config ("yours win")
- **Deleted on purpose**: user-level `~/.config/crush/crush.json` (2026-08-31).
  Do NOT recreate it — config split-brain, and crush logs a merge warning when
  both exist

## Current Providers

| Provider     | Key source            | Notes                                                    |
| ------------ | --------------------- | -------------------------------------------------------- |
| `synthetic`  | sops `crush-daily.yaml` | injected since 2026-08-18                              |
| `zai`        | sops `crush.yaml`     | `glm-5.3-flash` declared via `model add` (not in catalog) |
| `gemini`     | sops `crush.yaml`     |                                                          |
| `minimax`    | sops `crush.yaml`     | **DISABLED** 2026-08-31: Token Plan exhausted (2056). `provider add minimax --disable true` in crushrc; key stays rendered. Re-enable = delete that line |
| `kimi-coding`| sops `crush.yaml`     |                                                          |
| `llamacpp`   | none (local)          | `:8899`, ad-hoc llama-server; models auto-discovered     |
| `hyper`      | auth store (OAuth)    | stays store-owned: tokens self-rotate hourly             |

## Adding a Provider Key

1. Encrypt it (public key only, NO sudo needed). Stage in RAM to avoid
   `.sops.yaml` path-rule mismatches:
   ```bash
   T=$(mktemp -p /dev/shm); cd /dev/shm
   echo 'newkey_api_key: "VALUE"' > "$T"; chmod 600 "$T"
   sops -e --age age133ckftlye8snhzga95fnl4np7npjry90qr3g84ya0kddctecx5hsx9uyh6 -i "$T"
   sops -d "$T" >> /dev/null  # (on a host with the private key) verify
   ```
   then merge the key into `platforms/nixos/secrets/crush.yaml` with
   `sops --set '["newkey_api_key"] "VALUE"' …` (needs the age PRIVATE key,
   i.e. a sudo session), or regenerate the file the public-key way.
2. Declare it in `modules/nixos/services/sops.nix` (the `crush.yaml`
   `mkSecrets` block): add `"newkey_api_key"` to the name list.
3. Inject it in the HM crushrc (`home.nix`): `crush_key newprovider newkey_api_key`.
4. Test WITHOUT a deploy: `bash scripts/crush-rc-test.sh` (loads the rc in an
   isolated `XDG_CONFIG_HOME`; `EXTRA='…'` appends a candidate line;
   `--probe` + `PROBE_MODEL=provider/model` fires one real completion).
5. Deploy (`nix run .#deploy`), then verify `crush models` lists the provider
   and restart crush sessions — config loads ONLY at session start.

## Rotating a Key

`sops --set '["zai_api_key"] "NEW"' platforms/nixos/secrets/crush.yaml`
(sudo/age private key), then redeploy. Rotation — not relocation — is what
makes old plaintext residue in session DBs inert.

## Verification Suite for ANY crushrc Change

1. `bash scripts/crush-rc-test.sh` — load-safety (a bad statement aborts the
   ENTIRE config load: all providers/LSPs/MCPs vanish)
2. `crush models | diff` before/after — WHICH entities exist; a deleted
   config source may own entities nothing else provides (the 2026-08-31
   glm-5.3-flash lesson)
3. `bash scripts/crush-rc-test.sh --probe` + `PROBE_MODEL=provider/model` —
   one real completion through the key (auth + model both proven)
4. `crush models` asserts model IDENTITY in any smoke run — never trust a
   reply without knowing which provider/model served it (silent fallback to a
   pricier default is a real, observed failure mode)

## Gotchas

- `model add` has NO `reasoning_levels` flag (source:
  `internal/shellconfig/model.go`) — tier lists come from the catalog or
  crush's default handling; `--reasoning-effort` is an unvalidated string
  (`xhigh` works, the usage text's `low|medium|high` is aspirational)
- `discover_models` defaults to TRUE — llama.cpp/ollama-class providers need
  no hand-maintained model lists
- Session DBs (`~/.{config,local/share}/crush/.crush/crush.db`) snapshot
  provider configs per session: store-era keys sit there until rotation;
  crushrc-injected keys are never snapshotted
- `crush_key` skips absent secrets AND `PLACEHOLDER*` values — a provider
  with a placeholder ships inert, not broken
