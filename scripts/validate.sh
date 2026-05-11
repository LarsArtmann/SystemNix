#!/usr/bin/env bash
set -euo pipefail
nix --extra-experimental-features "nix-command flakes pipe-operators" flake check --no-build
