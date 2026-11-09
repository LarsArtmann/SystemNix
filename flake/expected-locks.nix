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
  bank-sync = "40c1feb641aaaac633f48b2bcbe361b6b5f83ebb";
  branching-flow = "bbdb8b1d5bdb90d0f7686ba55cf8d60af9ea89f5";
  brandid-lint = "cf71d5d24ed89e6a97289726d388159992e3c2b0";
  browser-history = "27134e8d5a01f5b3b34642c4bea561205e4aa21b";
  buildflow = "026d209fb28ce066b59d8c253233d4b41cba61ed";
  cmdguard = "0ef84ddd682a3b4c504052aa88e3abce2e7efca3";
  crm = "f32f4c0beab95011e5f3b71f1e07826cb336da99";
  crush-config = "b387487bc94057860d5f3153a143828d71847044";
  crush-daily = "e8db4d3154d9469df76cb1974ee735a6df76a928";
  cv = "ff70e6a3ecfac8ee4674bef40c5a9c3e7a26094d";
  cvagent = "6ff68d32fd73b54512d4d55567d6b426c7be6f55";
  dankMaterialShell = "32d6c430f89f58122c8f4a6de5b38aaf5316b1d3";
  discordsync = "ea6c444c06284584d34fbbeb1ffa7d12f80a897f";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "af8abffde7b3d827bdb719e6c4fed664882e914f";
  docs-gates = "2278406afdfd1b8df7674e2e594b6ea880694c90";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "4bd8bf66136f9dcc90c8e27b7bd12c8490d60031";
  erraudit = "5c841cf21140bbba3bff6613126720dad8298cbd";
  file-and-image-renamer = "973dd383ba98ae8b6e3b4b3a95f690c627bb49ab";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "ea2630b7470978622c7689a1ff75d2b389175399";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "204b6977e00caac19e2313015a598543ca7be150";
  go-auto-upgrade = "ff72ebf0d6f101a12641a32507074c0395f659b3";
  go-branded-id = "cf71d5d24ed89e6a97289726d388159992e3c2b0";
  go-commit = "2da8caecb82c927e6ca7ca04a682e1f73dd145fa";
  go-cqrs-lite = "6927dbb827f538979481fa1570187c677ed66cb0";
  go-error-family = "7ccca5c62037bab213d548f21a8be333781c0e9c";
  go-filewatcher = "9f44deee398bb9815b56948dcedd286a130e9832";
  go-finding = "bedec26890c79cc9612100ee8744475082744315";
  go-health-dashboard = "d15fcb62b57fff15a75a997ea382be5a937eebfb";
  go-humanize-linter = "9c91385bdabc94d30b0fe974f6f4ebd371c77dcb";
  go-nix-helpers = "2c5d1d75aeacaaf6ddf558fd7d7bd5a4f4f7687a";
  go-output = "ba5033465f9b8e39b876397f01e696fed1a81cd7";
  go-paperless = "b015a5d4267e9e7e33534e7ddce11a5854898969";
  go-structure-linter = "0f92c65eba5f8b59dc2a27fd1d9fbc7f1567683c";
  go-taskqueue = "c84d2b5a5bdfb1367b97b1e7b0c54a7e07e60620";
  gogenfilter = "c088b323e8bdb082caf9f313431eca67b1aa476b";
  golangci-lint-auto-configure = "28340f6352b629bdf2225c88f1c7f64308279f67";
  helium = "ef91010a4fcc551b5cb24f52608dc8d45c527d9d";
  herdr = "ee5bfb5041bb3e4a49d591c72308aae3c81ecdde";
  hermes-agent = "466591fe65d0257c96083df16fcd39636032304c";
  home-manager = "2c0c1f01521469cf0271180c453c79782d53c2f6";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "f55bf89d3531acc9f8b384ed83687f9d608c54b0";
  inboxclean = "e553c510cafe335f659030331d8b4d120d6c1826";
  index = "f7e28a0e716dfbb29bcffcc6c67e889d651ec172";
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
  nix-email = "10309cb74f1d5a3b55c9ed5176a4693885ced020";
  nix-homebrew = "52bc87da3f30c2261a6d1cfef3c892097b53daeb";
  nix-ssh-config = "8c083ed1e823de2f00447468d077ca411b7673ee";
  nixos-hardware = "1a8ff4f57ffe1f732beaa1db842247a381ea471d";
  nixpkgs = "f4a03c008967841f2a0b3cb7c436fc6fc31671f6";
  nixpkgs-llama-rag = "0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
  nsfw-classifier = "695da95de2aafda3d99c445bbfec1979a221f79b";
  nur = "235c242d78c5a3e4a537d310296a2a45aef94a98";
  offline-banner = "d9f6d6f239b60907561088cf71e92570c447d962";
  otel-tui = "d43d3f9edbe2c4c61380a10030df4ad02ffc3206";
  overview = "67b2fac96799f269348f51eca78903df6c14dcc8";
  papdashboard = "287f6951cf7c3995ca9cf92b12d4919fe095fbbb";
  paperless-gpt-src = "49c425596b846ae98d630f4087e8223c188032db";
  pim-sync = "1b70ed4bc523d60fc7e72f6284311e42b3c950c1";
  project-dependency-graph = "8335670e8e46e103cefce3e94f57fcc878720a3f";
  project-discovery-daemon = "adb9821783092cd8c037421f26aa48c7409a9d47";
  project-meta = "8b40bd7d250253cddb1d1cf694377dd6ee47f4a2";
  projects-management-automation = "5f9f4661baa5e0368cc748bf432c3059686a7278";
  pyproject-build-systems = "bdbc5f8dd2ad6136bb2ccecb14f6ec343965b194";
  pyproject-nix = "d43f0e74444c1f266c640fc49ce6ce6fb69d33c3";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  quotaboard = "13fa2925c18d5064ac92328ca12a8fe3cfb9e341";
  rust-overlay = "51c6dc40d18552701f7c5c62e3f7a5fc899f7132";
  samber-linter = "6978204b1a910896054c824e5886178d427def8d";
  signoz-collector-src = "6355ea5bea0759f73cc027e03a8362aee2341a20";
  signoz-src = "87bcd1b70275f985531aab749dda5566a3bf8c46";
  silent-sddm = "d179078e88cde18195b82841d3e879949b06faa8";
  sops-nix = "89a234ce2daf6e568a7d4b4fe250afdd23d84e20";
  storage-collector = "6a6705677b35dd87db84502ef61e024beeed0844";
  superfile = "2328e2ecb643ac11198e7a39555484388dfa4785";
  systems = "d36eeed142f88b5a636f2e3856a53c61654cf29b";
  templ = "dd6c9861fa78fb6d602da9b1ed1dc54ae7752ffe";
  todo-list-ai = "2365fa243a89862bd834ab7cb29cabc0e8087ed4";
  treefmt-full-flake = "d4817f5494feca3c5e927b58032ddcd718dbfdff";
  treefmt-nix = "0d6d739a833ba9a9c93034862e4a7b061a062a1c";
  uv2nix = "c361746c7d630d98b972378290547c8d35542a7a";
  vision-review-agent = "22c7e5ee2134f38aa1373f65e5c601038045f6d5";
  wallpapers-src = "a6c8891c5612688a770c41a6d5fcc531155b8519";
}
