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
# 2026-11-03 regen (round-9 float: crush-daily + browser-history; diagnostic rebuild, proof pending)
{
  art-dupl = "5412d55d439e8d3b50ddf04d3a2f874db9a574fc";
  art-dupl-src = "5412d55d439e8d3b50ddf04d3a2f874db9a574fc";
  bank-sync = "4b0be19c81086b68492e61d2b7607448b3513f30";
  branching-flow = "440ab6a99930f557771ef240ff16bdd3a32d7e0b";
  brandid-lint = "cf71d5d24ed89e6a97289726d388159992e3c2b0";
  browser-history = "27134e8d5a01f5b3b34642c4bea561205e4aa21b";
  buildflow = "858e1c96ba1a418e58663836663619e680314376";
  cmdguard = "0ef84ddd682a3b4c504052aa88e3abce2e7efca3";
  crm = "f32f4c0beab95011e5f3b71f1e07826cb336da99";
  crush-config = "2f25a6f5c332899b5b4e3f5096b22f20af8dbf1d";
  crush-daily = "e8db4d3154d9469df76cb1974ee735a6df76a928";
  cv = "bce44b6bdf7226a41d5967a812eed745d9540e6d";
  cvagent = "e6a9ff36793a4ac3a2ba7e0c59cefa38fbf9c9c8";
  dankMaterialShell = "e46ccbc1d58930d6a189cd1c90b276db2d64bf42";
  discordsync = "ea6c444c06284584d34fbbeb1ffa7d12f80a897f";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "696c73e80f381740165c5155966f2cdcf8763fb8";
  docs-gates = "2278406afdfd1b8df7674e2e594b6ea880694c90";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "4bd8bf66136f9dcc90c8e27b7bd12c8490d60031";
  erraudit = "5c841cf21140bbba3bff6613126720dad8298cbd";
  file-and-image-renamer = "973dd383ba98ae8b6e3b4b3a95f690c627bb49ab";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "ea2630b7470978622c7689a1ff75d2b389175399";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "204b6977e00caac19e2313015a598543ca7be150";
  go-auto-upgrade = "6afba68c6d647dbd27c678909e8fedf43e9b17d2";
  go-branded-id = "cf71d5d24ed89e6a97289726d388159992e3c2b0";
  go-commit = "775150207aac111370c343cdc13b91e724c2273d";
  go-cqrs-lite = "7f88d061874c3ff729745db67d32a8a542c2c166";
  go-error-family = "bf4d5ba74ae21815a211a150b426cc4e50f5ab76";
  go-filewatcher = "9f44deee398bb9815b56948dcedd286a130e9832";
  go-finding = "5319d0af7ca5b8681396fb3dcfe9ce723e9f1e59";
  go-health-dashboard = "4519ee029761a048e95bea24aa459a82ac864a97";
  go-humanize-linter = "6f7946372c441f5266df160369d885e9ef31f512";
  go-nix-helpers = "2c5d1d75aeacaaf6ddf558fd7d7bd5a4f4f7687a";
  go-output = "ba5033465f9b8e39b876397f01e696fed1a81cd7";
  go-paperless = "c0fa9e47b746ca782e7af26fbdbb021603d361db";
  go-structure-linter = "784064d065ecc48681234c9bb7150ce7b010dfd7";
  go-taskqueue = "f19a4f0a36c6845be8e0e2362a9f4b5277613065";
  gogenfilter = "c088b323e8bdb082caf9f313431eca67b1aa476b";
  golangci-lint-auto-configure = "28340f6352b629bdf2225c88f1c7f64308279f67";
  helium = "ef91010a4fcc551b5cb24f52608dc8d45c527d9d";
  herdr = "ee5bfb5041bb3e4a49d591c72308aae3c81ecdde";
  hermes-agent = "b27d1995492be96651c3ae5b644959ab7130b513";
  home-manager = "82ce401aa350502897c3f2e85f384d61cd3b0b6d";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "88b5485cb721837a6a3e615c9932f98ad6e3c832";
  inboxclean = "5021c9270bf1739c10bf631a5c0ffa1e0cfee9cb";
  index = "61471a87f57d1ebf0ccbcbb3c28f183f0b313a5f";
  invoices = "f72f78e0332b655ded4c37c87f274d9f50513c85";
  journal = "4a63e7fd3ddd3aefcc92bfbcc959ce5918a63303";
  library-policy = "7fc09832355ee5f43dc7784b4a5510d57ccb0abd";
  md-go-validator = "c7fc05afe1cf6d67cf7b4ab6cb49f4720b3e0a1e";
  media-atlas = "3b8c7f9eb7693e597319213781b93bdd9321984f";
  monitor365 = "164e159a4b6c02a933ca911094e6c5e58dfdd86a";
  mr-sync = "5abebe93e6ca5abb0d878e3d5f2357f2f60e6fde";
  niri = "9ee3e13b60643448228353097880521658b2fe0e";
  niri-session-manager = "c79732161f23268aa1077b4d8ebf5f3fc7f3867d";
  nix-amd-npu = "8848c6f3382852290ac25fbe7634058c4e9c037e";
  nix-darwin = "ff0e21a414d4547183396da1b44a66f2577b65e9";
  nix-email = "d642b97e5cd1e7f11e188e77d2aa26f911f41d15";
  nix-homebrew = "52bc87da3f30c2261a6d1cfef3c892097b53daeb";
  nix-ssh-config = "8c083ed1e823de2f00447468d077ca411b7673ee";
  nixos-hardware = "919c16cf46a7acf9b44b2c2444bc39aa094eaa85";
  nixpkgs = "f9a75f41be3a74eab55d3a7679d34ad6cc0da977";
  nixpkgs-llama-rag = "0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
  nsfw-classifier = "695da95de2aafda3d99c445bbfec1979a221f79b";
  nur = "98e12bbd3c8892731f5844a225e89320801dbea1";
  offline-banner = "d2599e8459ee265ea30442b21ce494f9ffba913f";
  otel-tui = "d43d3f9edbe2c4c61380a10030df4ad02ffc3206";
  overview = "67b2fac96799f269348f51eca78903df6c14dcc8";
  papdashboard = "287f6951cf7c3995ca9cf92b12d4919fe095fbbb";
  paperless-gpt-src = "49c425596b846ae98d630f4087e8223c188032db";
  pim-sync = "6dd733a27a35d9e61b63e5c290a964a0e6af9a17";
  project-dependency-graph = "8335670e8e46e103cefce3e94f57fcc878720a3f";
  project-discovery-daemon = "ffbbc79f558f1f52a46b51aa1a8008601245ddf6";
  project-meta = "50770ad5a1f407fa11e61e6a3d7ee38ac0b64ea9";
  projects-management-automation = "da285ff97297f73862d486f2846cc2e5c9149838";
  pyproject-build-systems = "bdbc5f8dd2ad6136bb2ccecb14f6ec343965b194";
  pyproject-nix = "d43f0e74444c1f266c640fc49ce6ce6fb69d33c3";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  quotaboard = "23c6dddc577dfa1534897a0e1d9f3d7830936537";
  rust-overlay = "89750a2ef1c6a44db9f4251b16c23deffdcfddff";
  samber-linter = "4ce1f2e06d6bb77e9fedd07a652f753e2c169523";
  signoz-collector-src = "58895368666ac7c719d103680c8b4992428b5402";
  signoz-src = "f02b5521c6fd73a393d180a0ae4d8cf4d2740b7d";
  silent-sddm = "d179078e88cde18195b82841d3e879949b06faa8";
  sops-nix = "fe7b4228405aeac2ce7192c2049a6e2bc8637082";
  storage-collector = "6a6705677b35dd87db84502ef61e024beeed0844";
  superfile = "2328e2ecb643ac11198e7a39555484388dfa4785";
  systems = "d36eeed142f88b5a636f2e3856a53c61654cf29b";
  templ = "dd6c9861fa78fb6d602da9b1ed1dc54ae7752ffe";
  timesheets = "0a5524f3f7349bd2e7f8eee9c8c0cefb4f545fe0";
  todo-list-ai = "a4ae4cff8e5fea44b76b5c5d50f4f4da607ee7da";
  treefmt-full-flake = "d4817f5494feca3c5e927b58032ddcd718dbfdff";
  treefmt-nix = "0d6d739a833ba9a9c93034862e4a7b061a062a1c";
  uv2nix = "c361746c7d630d98b972378290547c8d35542a7a";
  vision-review-agent = "22c7e5ee2134f38aa1373f65e5c601038045f6d5";
  wallpapers-src = "a6c8891c5612688a770c41a6d5fcc531155b8519";
}
