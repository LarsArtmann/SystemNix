# CV Deploy — variant-patch hybrid-sync fix (2026-09-19)

> **[docs-health 2026-09-21] RESOLVED + ARCHIVED** — one-shot deploy runbook, executed: the variant-patch hybrid-sync fix shipped and the cv lock has since advanced past the staged rev (`a514dff68` → `f137db7730`); the deploy-gate flag raised here (hot-user-caches units missing from deploy.sh) was resolved in the 2026-09-20 six-unit batch.

~~**Purpose:** ship the 2026-09-18 hybrid content-sync fix so restarts stop~~ done — shipped; superseded by later cv lock bumps.
destroying runtime-written auto-apply variant patches in `data/cv` (the
app-1449 burn: 15 approvals pointed at dead "View tailored CV" links).

## What ships

- **Fix commit:** CV `ea80ee230` (2026-09-18 18:48) — `nix/nixos-module.nix`
  contentSync: shipped files overwritten IN PLACE, runtime files preserved,
  `chmod -R u+w` after copy; `nix/nixos-tests.nix` restart-survival pin.
- **Pinned rev:** `a514dff68` (CV master HEAD at staging time; fix + 185
  follow-up commits incl. typed route registry 133, honest-dry-run,
  T05 library-shadow dual-run).
- **Staged by:** machine session 2026-09-19 (`nix flake lock --update-input cv`;
  sub-inputs copied verbatim from CV's own committed flake.lock — no drift).
- **Pre-deploy gates verified at `a514dff68`:** `nix build .#cv` green;
  vendorHash no-op (refresh-vendor-hash reports pin correct); VM test
  `.#nixosTests.cv-server` green (incl. restart-survival assertions);
  variant base-fallback unit tests green.

## Deploy blocker (NOT cv-related, must land first)

`nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`
currently FAILS the `deploy-restart-audit` assertion:
`hot-user-caches-go-build-bootstrap`, `hot-user-caches-nix-bootstrap` are
converger oneshots missing from `scripts/deploy.sh`'s restart loop. This is
the in-flight `hot-user-caches.nix` work (uncommitted 2026-09-19) — land it
(add the units to `scripts/deploy.sh` or allowUnits with justification)
before running the deploy, or the switch dies at eval.

## Deploy window (owner)

```bash
cd ~/projects/SystemNix && nix run .#deploy   # nh-based, post-deploy checks run automatically
```

## Post-deploy verification (machine-runbook, ~10 min)

1. Generation + rev: `nixos-version --configuration-revision` on evo-x2 shows
   the new generation; `jq -r '.nodes.cv.locked.rev' ~/projects/SystemNix/flake.lock`
   still `a514dff68…`.
2. `/health/ready` returns 200 (critical funnel store check green).
3. Render smoke: `bun scripts/render-smoke.ts` against `http://cv.home.lan`
   (loads /cv + /admin in real chromium, asserts rendered DOM, saves
   screenshots under `~/.local/share/cv-verify/`).
4. Variant-patch survival (the actual fix): note an existing
   `/var/lib/cv/data/cv/*.patch.json` mtime, `systemctl restart cv-server`,
   confirm the file still exists with identical content; approvals panel
   "View tailored CV" links answer 200 (previously JSON 500).
5. First content-sync tick: `journalctl -u cv-server | grep cv-server-content-sync`
   shows the ExecStartPre ran clean.
