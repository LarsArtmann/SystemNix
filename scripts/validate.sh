#!/usr/bin/env bash
set -euo pipefail
nix --extra-experimental-features "nix-command flakes" flake check --no-build
