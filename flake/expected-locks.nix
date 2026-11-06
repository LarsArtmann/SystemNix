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
  bank-sync = "fab930686bd945301b2e0fccd2aaeeadf5d7300c";
  branching-flow = "8fd75a742970ad258a288abf24a6c349c820d202";
  brandid-lint = "cf71d5d24ed89e6a97289726d388159992e3c2b0";
  browser-history = "6ebaf8afe410a815fb3d38565453d839ea868cb7";
  buildflow = "8dd59d211eda9c82b2282d67b5073abaa3ed9adf";
  cmdguard = "f2240dd724a1ae9281b69e31bc0ac4f3a34e126b";
  crm = "166451e57841b04db8282d1045d495cb4c4e6c4c";
  crush-config = "20587f0e66aacbe4d6a701036e442f19bf657a16";
  crush-daily = "e8db4d3154d9469df76cb1974ee735a6df76a928";
  cv = "700b521fa405060bac51b2cbec5ca5d087d34037";
  cvagent = "30b379b3e03eaa574e30c65e029463c7a100c70d";
  dankMaterialShell = "fe133e076b3352f10423fc608cc0c362e60751af";
  discordsync = "ea6c444c06284584d34fbbeb1ffa7d12f80a897f";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "847d81e36ab084a677a60047c401525710b1c991";
  docs-gates = "2278406afdfd1b8df7674e2e594b6ea880694c90";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "ac1acac2d937c3ca83c06d73751d3990b06ee555";
  erraudit = "5c841cf21140bbba3bff6613126720dad8298cbd";
  file-and-image-renamer = "973dd383ba98ae8b6e3b4b3a95f690c627bb49ab";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "ea2630b7470978622c7689a1ff75d2b389175399";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "204b6977e00caac19e2313015a598543ca7be150";
  go-auto-upgrade = "ff72ebf0d6f101a12641a32507074c0395f659b3";
  go-branded-id = "cf71d5d24ed89e6a97289726d388159992e3c2b0";
  go-commit = "2da8caecb82c927e6ca7ca04a682e1f73dd145fa";
  go-cqrs-lite = "8500f811822017603dfa141c9b68556160957677";
  go-error-family = "7ccca5c62037bab213d548f21a8be333781c0e9c";
  go-filewatcher = "9f44deee398bb9815b56948dcedd286a130e9832";
  go-finding = "57b8e19d5430d1bff65e5caf53fb3bfda9b246ad";
  go-health-dashboard = "83be4b1b46f209a8e313a47e3a0c0e44b3a26eb2";
  go-humanize-linter = "9c91385bdabc94d30b0fe974f6f4ebd371c77dcb";
  go-nix-helpers = "2c5d1d75aeacaaf6ddf558fd7d7bd5a4f4f7687a";
  go-output = "ba5033465f9b8e39b876397f01e696fed1a81cd7";
  go-paperless = "97340ef09e90ac6abdbe3c81f99a3cfc6788bbb8";
  go-structure-linter = "0f92c65eba5f8b59dc2a27fd1d9fbc7f1567683c";
  go-taskqueue = "93e0ec7a13cb63eeb0e2d6f551d4ce2e96a951ee";
  gogenfilter = "ebdac855fea9ed24ed20e4e0590ab80fd24d826d";
  golangci-lint-auto-configure = "28340f6352b629bdf2225c88f1c7f64308279f67";
  helium = "ef91010a4fcc551b5cb24f52608dc8d45c527d9d";
  herdr = "ee5bfb5041bb3e4a49d591c72308aae3c81ecdde";
  hermes-agent = "6b21d0564de0492e2ebd0d8f63fca86c03b5c892";
  home-manager = "2c0c1f01521469cf0271180c453c79782d53c2f6";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "b82223d85a750a5cd19f2ae8f7496a8f36a70581";
  inboxclean = "e553c510cafe335f659030331d8b4d120d6c1826";
  index = "bb3c31ecb6e339652165706ef68ba082ab7858fa";
  journal = "4a63e7fd3ddd3aefcc92bfbcc959ce5918a63303";
  library-policy = "7fc09832355ee5f43dc7784b4a5510d57ccb0abd";
  md-go-validator = "13a0e7898d982a5f27a77ea4712ec8c2339e1c96";
  media-atlas = "5c6b3d4627154f399626fc17efc4d390529e6b9f";
  monitor365 = "164e159a4b6c02a933ca911094e6c5e58dfdd86a";
  mr-sync = "5abebe93e6ca5abb0d878e3d5f2357f2f60e6fde";
  niri = "9ee3e13b60643448228353097880521658b2fe0e";
  niri-session-manager = "c79732161f23268aa1077b4d8ebf5f3fc7f3867d";
  nix-amd-npu = "8848c6f3382852290ac25fbe7634058c4e9c037e";
  nix-darwin = "ff0e21a414d4547183396da1b44a66f2577b65e9";
  nix-email = "10309cb74f1d5a3b55c9ed5176a4693885ced020";
  nix-homebrew = "52bc87da3f30c2261a6d1cfef3c892097b53daeb";
  nix-ssh-config = "8c083ed1e823de2f00447468d077ca411b7673ee";
  nixos-hardware = "d645c71a58dbae3eb17ff551a07aea13a541cb1a";
  nixpkgs = "1d060086d60cb76a40cf37109f979d88a5bd6396";
  nixpkgs-llama-rag = "0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
  nsfw-classifier = "a8ba14601a9d6397b16e78210ad7a388bcc7d0fa";
  nur = "1f07fb5c85e4ea2343f857c3a9566bd5ed9a05ec";
  offline-banner = "d9f6d6f239b60907561088cf71e92570c447d962";
  otel-tui = "d43d3f9edbe2c4c61380a10030df4ad02ffc3206";
  overview = "67b2fac96799f269348f51eca78903df6c14dcc8";
  papdashboard = "ea0f5c4d8348a56c9103d1bb8171b7c640abc880";
  paperless-gpt-src = "49c425596b846ae98d630f4087e8223c188032db";
  pim-sync = "1b70ed4bc523d60fc7e72f6284311e42b3c950c1";
  project-dependency-graph = "8335670e8e46e103cefce3e94f57fcc878720a3f";
  project-discovery-daemon = "ab80974e1e8d722e8516e1ab1c6f5c8d01d0ce5d";
  project-meta = "8b40bd7d250253cddb1d1cf694377dd6ee47f4a2";
  projects-management-automation = "5f9f4661baa5e0368cc748bf432c3059686a7278";
  pyproject-build-systems = "947b2b0c973de462b19577715f04ba8d6f48ed7e";
  pyproject-nix = "d43f0e74444c1f266c640fc49ce6ce6fb69d33c3";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  quotaboard = "61801b113d657a375c74c2a298c14c815c91f1ef";
  rust-overlay = "74cebce67ef6671ea48fda353a5be2d229bd2920";
  samber-linter = "6978204b1a910896054c824e5886178d427def8d";
  signoz-collector-src = "6355ea5bea0759f73cc027e03a8362aee2341a20";
  signoz-src = "d1f4503b40a4656eb1d9d96f94011d5fddc3d51d";
  silent-sddm = "d179078e88cde18195b82841d3e879949b06faa8";
  sops-nix = "89a234ce2daf6e568a7d4b4fe250afdd23d84e20";
  storage-collector = "0569c46c3ca4c2959e711a5cf8f0d3545f912436";
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
