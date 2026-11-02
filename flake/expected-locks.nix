# Expected lock revs — the reviewed registry behind the lock-float eval gate
# (lib/lock-float-audit.nix, lazily forced on HOST-CONFIG eval via
# lockFloatGated in flake.nix — never on app evals, so `nix run .#deploy`
# and `nix run .#float-register` stay reachable while drifted and absorb
# the drift mechanically; 2026-10-25 17:2x the old outputs-eval placement
# dead-ended the owner's `nix flake update && nix run .#deploy` at the gate
# before the automation could run).
#
# Every root input that locks a rev MUST have an entry here, and the entry
# MUST equal flake.lock's locked rev. A blanket `nix flake update` therefore
# fails any HOST-CONFIG build/eval until the floated revs are re-registered
# — making each float a conscious, reviewed act instead of a silent
# eval-break that surfaces as a DOA deploy (the 2026-10-23 wave:
# hermes-python IFD + crowdsec module conflicts rode one blanket update).
#
# Deliberate float procedure (the ONLY way past the gate — automated by
# scripts/float-register.sh, wired into scripts/deploy.sh):
#   1. regenerate this file (mechanical, derived from flake.lock — never
#      hand-edited):
#      # 2026-10-29 regen (documented jq procedure): adopt the float wave that moved 17 inputs
# since 2026-10-25 (buildflow, journal, crush-config, nix-email, offline-banner, crm,
# dnsblockd, cv, uv2nix, go-taskqueue, helium, homebrew-cask, nur, dankMaterialShell,
# pyproject-nix, rust-overlay, nixos-hardware) + add the new media-atlas input
# (435a0ba, forgejo-primary hub, v0.1 deploy PR). Proof: toplevel toplevel-proof log.
{
  art-dupl = "308d8d7510c0743980575d1e7ffa6fb903b96d59";
  art-dupl-src = "308d8d7510c0743980575d1e7ffa6fb903b96d59";
  bank-sync = "8786a2d2b2f03d080ed6d37969eb4b53de9e115c";
  branching-flow = "a4b5e9dd19918c064b1e560f146965c09e4a03b8";
  brandid-lint = "4db3cc969e320051c820f3801c158dc7c9f5f23a";
  browser-history = "f9c8916bc5b9ddf0ff2e55ad960be9b72ec09482";
  buildflow = "4ffcdee897196c42e284303db5fc35ed7365531e";
  cmdguard = "272e83e99e11f6f7fc7a87fdab4dce0d791a4aea";
  crm = "900bf55f18d0da734b4a431ffd531269371c3eb0";
  crush-config = "66bff2d6e99b5664d477e31457c0206ff38f4d33";
  crush-daily = "85b1d7a11985955da5724472a0c009bbfd78b409";
  cv = "aa878d2f0231cb6495f79124da70527b32d85ad1";
  cvagent = "eee6d5750256de688d149f1623d355955994d537";
  dankMaterialShell = "fca8c72763f27b81353855c0c57cf44de20003d3";
  discordsync = "ca6bcf97b951410031879c6a7de334b2de233e06";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "03f8421eec82cf3eb7fa01f688665b5b7f46fd9a";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "612e42fa7f198d4433f098d1a7d457441fb6b208";
  erraudit = "b3ba79700c0c6fd8a07e7e6275a593780d74ad3e";
  file-and-image-renamer = "43ca9929f994cb748373c476cd6164a858941fcd";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "ea2630b7470978622c7689a1ff75d2b389175399";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "1ba1dbfe28738c9a71c266be6efa5b89e75491a9";
  go-auto-upgrade = "d49dbdb295d48ed36962e78354e4317a7afb338d";
  go-branded-id = "4db3cc969e320051c820f3801c158dc7c9f5f23a";
  go-commit = "c5368d8d0a5604a50bf6ed36eb41baa7ab1f7b20";
  go-cqrs-lite = "516b58c5a827212fa8427199540114291934fe17";
  go-error-family = "31561e48eb940b9afbe78545df0dd90aec696d0f";
  go-filewatcher = "bb20199bd0ef116410a3504439dc2f7fb3e40614";
  go-finding = "f9794018ca5c105c912a68cbfd67485f62f10575";
  go-health-dashboard = "ee143ac0bb7a318c965d10fc1e810bd750248874";
  go-humanize-linter = "8ac99125c10beb0444f7e621545104e6b58be1b8";
  go-nix-helpers = "2c5d1d75aeacaaf6ddf558fd7d7bd5a4f4f7687a";
  go-output = "06357826d1a9886e5b10a9aa65c8d27ce6b25e3c";
  go-paperless = "bd1b68842c92e47dc4e61f99e9092c8da908d770";
  go-structure-linter = "f16200ebed2c59ac74e848d63fde4fdbdf9323a9";
  go-taskqueue = "0e1679ddb37319bbf36aff5c4f24117ecd4d59a9";
  gogenfilter = "eded9738cdec86854660079b9fd7dab5c82d7fb3";
  golangci-lint-auto-configure = "f4df57a684ab2820f349239c6b7f248bde9fc1a8";
  helium = "7945a36a1ef9a47cc3c3c094a16692b4beb8d59a";
  herdr = "ee5bfb5041bb3e4a49d591c72308aae3c81ecdde";
  hermes-agent = "0329638c2bf0438552145589787e355bf23343fe";
  home-manager = "095fef2f265c3c0da4fe315efba8f8a04495ab34";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "da17f8d99211dffe3a057ae75d4e6ec01a6a6297";
  inboxclean = "5c52f31506d114f508d3cf5832c552da3b5f2228";
  index = "f583b68abd981df5663c235d3618a189bba51fe7";
  journal = "3542a9587a12ce64dcf34f9d6443227a63f64bf5";
  library-policy = "f36510924184c78b638ae602e848935a627571c5";
  md-go-validator = "3f466de78df43628ca4c59803151f4345f67607a";
  media-atlas = "e2c4867d4157d59d1df5a571aae61581ccf40fee";
  monitor365 = "10d252918bfcea33f341385a50182f26aaa75182";
  mr-sync = "0064e140df16127c2419c1df955450ce0e72d222";
  niri = "9ee3e13b60643448228353097880521658b2fe0e";
  niri-session-manager = "fbc96f843edc2022e3f8fde9bec33d770e96b75a";
  nix-amd-npu = "8848c6f3382852290ac25fbe7634058c4e9c037e";
  nix-darwin = "ff0e21a414d4547183396da1b44a66f2577b65e9";
  nix-email = "3e8faf2265e75e8593162022258052a4bfb552cc";
  nix-homebrew = "52bc87da3f30c2261a6d1cfef3c892097b53daeb";
  nix-ssh-config = "8c083ed1e823de2f00447468d077ca411b7673ee";
  nixos-hardware = "04c6b94fa104bc23650983a4513aea196794d321";
  nixpkgs = "fe13242281a67641c0102cdb1087f0ebe586c7df";
  nixpkgs-llama-rag = "0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
  nixpkgs-unstable = "1c89083e451e891152365b799595cf7790a43325";
  nsfw-classifier = "58d398dc68b94f16df2adefdeb8f2864d950080f";
  nur = "ee8e726ca470e32fce85388d867be93fcd03d2c5";
  offline-banner = "2ccdf6ec04f32b94aa2b8ddd7d35a38b5daf2903";
  otel-tui = "5e7cf2f4dfc6f06a8c71f49f4d2b66672a7b50f6";
  overview = "ef9012966cf9d21106423c0042711ef434866c3b";
  papdashboard = "b370f98dd1a10da252a3a7e5d0c0f9fcee93d25f";
  paperless-gpt-src = "0a59ea4b2c0b70afbf01bafcd0a0858372368009";
  project-dependency-graph = "493013848b7a396cb9603b795cbf79d1ddaaa51d";
  project-discovery-daemon = "145cd73db456320adcde0d71b77a535e03bbd7f4";
  project-meta = "17dbf3d0d357e98c072f1da636f12c0b43433d63";
  projects-management-automation = "fde1c413fa3094d3122fdfaf51616b9358fe2aa4";
  pyproject-build-systems = "461a6a8540307fb9c05b8f6ad29e9720d2a621db";
  pyproject-nix = "bf7d4b1d6de61db02fd4e748395634f03006e5de";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  rust-overlay = "c85ccd343087c57da6021cafa1647142ad03e32e";
  samber-linter = "329c33c6eae0c8842ad9f8161d13773945e51747";
  signoz-collector-src = "637d961cf2c0e6c049a85434bb3a7c4ed26ce768";
  signoz-src = "375b3f8305720b236a83b50955269c60d96e1f9e";
  silent-sddm = "d477613b07ca13729af20cb4699b308ac7348d2f";
  sops-nix = "60182817ee048ac94b4c68ea76d5ef2e8aac730d";
  storage-collector = "0569c46c3ca4c2959e711a5cf8f0d3545f912436";
  superfile = "e5f3327caf9decf79b7d19a75a77a6eceff5b396";
  systems = "d36eeed142f88b5a636f2e3856a53c61654cf29b";
  templ = "dd6c9861fa78fb6d602da9b1ed1dc54ae7752ffe";
  todo-list-ai = "2365fa243a89862bd834ab7cb29cabc0e8087ed4";
  treefmt-full-flake = "d4817f5494feca3c5e927b58032ddcd718dbfdff";
  treefmt-nix = "0d6d739a833ba9a9c93034862e4a7b061a062a1c";
  uv2nix = "c361746c7d630d98b972378290547c8d35542a7a";
  vision-review-agent = "8cbb0ec900a84426a6e82ce1f9e5e2ff245c9f45";
  wallpapers-src = "a6c8891c5612688a770c41a6d5fcc531155b8519";
}
