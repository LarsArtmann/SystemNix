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
  art-dupl = "0cfc9966b768aeb3894c0ba1af1019c5a19c81a5";
  art-dupl-src = "0cfc9966b768aeb3894c0ba1af1019c5a19c81a5";
  bank-sync = "fab930686bd945301b2e0fccd2aaeeadf5d7300c";
  branching-flow = "d529225745111c9158cb27b48ad0d02e6edbbc66";
  brandid-lint = "8a4230f6c633231fc1afa4d37b2b14966a0f08c1";
  browser-history = "7110bcb36eb16037f5b20fb9142cd4e32dfbc49c";
  buildflow = "2d6bbee1775e55826b63d1139bdf427f5f2ddf09";
  cmdguard = "4ecff5c3b61257712574e03c49d8a83d0024f1e8";
  crm = "2e083afbc74c6f8df50f552c3986a233f80517c0";
  crush-config = "459d24517ea91db03d9c3b86460ec8834a99a87b";
  crush-daily = "e8db4d3154d9469df76cb1974ee735a6df76a928";
  cv = "16a656f4924069efcee122c3f7f8ccf27d592a21";
  cvagent = "b9f0acf192650bba8d653db1f9968a273c0813c2";
  dankMaterialShell = "1dab9c5420095cbbe05c5bcc87cec211bb28c3a7";
  discordsync = "ea6c444c06284584d34fbbeb1ffa7d12f80a897f";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "cb116e57d2f9c5c6ffd18386900e36b4a0023b83";
  docs-gates = "500506ed394bf53a62d472fc5b795188cbd1ae31";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "ac1acac2d937c3ca83c06d73751d3990b06ee555";
  erraudit = "3d1f7ed37a1c52a7cc8b9c3e1749a2c8a423256f";
  file-and-image-renamer = "973dd383ba98ae8b6e3b4b3a95f690c627bb49ab";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "ea2630b7470978622c7689a1ff75d2b389175399";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "204b6977e00caac19e2313015a598543ca7be150";
  go-auto-upgrade = "cf18ace902124435b9306fdcaad254d901885709";
  go-branded-id = "8a4230f6c633231fc1afa4d37b2b14966a0f08c1";
  go-commit = "39f7ddac0ef5090bcc844a0ad661de217f2078e1";
  go-cqrs-lite = "0b7aee41623fe2682104d9aa7969a41416697897";
  go-error-family = "d8c8391cfdcefe35cf53fc6a02295f2192bbbeb2";
  go-filewatcher = "a965e6b8be500594e117eb52e4269fefa90cfcfb";
  go-finding = "49669e3675e2818919d32ae18075185f8ed4d012";
  go-health-dashboard = "d7059a94ce5e54fea7a60b0ad70ebe976563102b";
  go-humanize-linter = "f48b5441ba0ed9c24368180e5cdd5e50f7c478f8";
  go-nix-helpers = "2c5d1d75aeacaaf6ddf558fd7d7bd5a4f4f7687a";
  go-output = "ba5033465f9b8e39b876397f01e696fed1a81cd7";
  go-paperless = "241f8efe3bfc03c13b9f6091f6eb5c35c14b1025";
  go-structure-linter = "96c225032ae991ffc455bd569a8b489d783145b1";
  go-taskqueue = "bfbfde6a1eded1aee7a8b7433a17ac3f0e05b7c1";
  gogenfilter = "ebdac855fea9ed24ed20e4e0590ab80fd24d826d";
  golangci-lint-auto-configure = "28340f6352b629bdf2225c88f1c7f64308279f67";
  helium = "ef91010a4fcc551b5cb24f52608dc8d45c527d9d";
  herdr = "ee5bfb5041bb3e4a49d591c72308aae3c81ecdde";
  hermes-agent = "0329638c2bf0438552145589787e355bf23343fe";
  home-manager = "b787c48e2ec57a9d098f5c2721882a3bc1e16f97";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "ac4d78aec142280106fb32cd4639c579e651fcf9";
  inboxclean = "d1b06e682d744ea1d77dfe19abc4bae8d5dd009d";
  index = "adeeb3031f0801a462d7507c1d2728010a78b7a1";
  journal = "4a63e7fd3ddd3aefcc92bfbcc959ce5918a63303";
  library-policy = "72ed2d4fffef152da28c3f4549e21c995fd4ea39";
  md-go-validator = "13a0e7898d982a5f27a77ea4712ec8c2339e1c96";
  media-atlas = "5c6b3d4627154f399626fc17efc4d390529e6b9f";
  monitor365 = "164e159a4b6c02a933ca911094e6c5e58dfdd86a";
  mr-sync = "079624b34b96f4ce8827d0555f3ceeca08a32db2";
  niri = "9ee3e13b60643448228353097880521658b2fe0e";
  niri-session-manager = "fbc96f843edc2022e3f8fde9bec33d770e96b75a";
  nix-amd-npu = "8848c6f3382852290ac25fbe7634058c4e9c037e";
  nix-darwin = "ff0e21a414d4547183396da1b44a66f2577b65e9";
  nix-email = "759ebd91cd400805908c7e4597a94d2fa3990976";
  nix-homebrew = "52bc87da3f30c2261a6d1cfef3c892097b53daeb";
  nix-ssh-config = "8c083ed1e823de2f00447468d077ca411b7673ee";
  nixos-hardware = "d645c71a58dbae3eb17ff551a07aea13a541cb1a";
  nixpkgs = "fe13242281a67641c0102cdb1087f0ebe586c7df";
  nixpkgs-llama-rag = "0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
  nixpkgs-unstable = "1d060086d60cb76a40cf37109f979d88a5bd6396";
  nsfw-classifier = "a8ba14601a9d6397b16e78210ad7a388bcc7d0fa";
  nur = "f6e986cc66c1ab410d81648e6c614fa5ad0bc858";
  offline-banner = "97b8056d55991e012249445fc1afc608e409bd7b";
  otel-tui = "d43d3f9edbe2c4c61380a10030df4ad02ffc3206";
  overview = "67b2fac96799f269348f51eca78903df6c14dcc8";
  papdashboard = "610b04ebe6a60fec48f078dbc370d9f58bed7ab4";
  paperless-gpt-src = "0a59ea4b2c0b70afbf01bafcd0a0858372368009";
  pim-sync = "de22ba839560698da727403b29fd4e431c498296";
  project-dependency-graph = "8335670e8e46e103cefce3e94f57fcc878720a3f";
  project-discovery-daemon = "cfaaecd05e6f0567f5ba2fa1009928b4477bc721";
  project-meta = "332065f18ae14bcd630b7a2cf6ad4d06eebcc49b";
  projects-management-automation = "f598fc9f0503301078bdf0d052a43012d9be70f1";
  pyproject-build-systems = "947b2b0c973de462b19577715f04ba8d6f48ed7e";
  pyproject-nix = "d43f0e74444c1f266c640fc49ce6ce6fb69d33c3";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  quotaboard = "12b38ee5e7d667edc9e4e10e48dccbb8af6a1730";
  rust-overlay = "19e0e6c951a7a8a7d3232c64e58d26b89df44c60";
  samber-linter = "5795e9246ca8aaca20c7bbbb2e947816f7e2dcef";
  signoz-collector-src = "6355ea5bea0759f73cc027e03a8362aee2341a20";
  signoz-src = "375b3f8305720b236a83b50955269c60d96e1f9e";
  silent-sddm = "d179078e88cde18195b82841d3e879949b06faa8";
  sops-nix = "b18e01ce148eb3efff5de2f2d3181ca53b2b2a54";
  storage-collector = "0569c46c3ca4c2959e711a5cf8f0d3545f912436";
  superfile = "1957ac07db4c60ef8266fdfd191e350d629cb25a";
  systems = "d36eeed142f88b5a636f2e3856a53c61654cf29b";
  templ = "dd6c9861fa78fb6d602da9b1ed1dc54ae7752ffe";
  todo-list-ai = "2365fa243a89862bd834ab7cb29cabc0e8087ed4";
  treefmt-full-flake = "d4817f5494feca3c5e927b58032ddcd718dbfdff";
  treefmt-nix = "0d6d739a833ba9a9c93034862e4a7b061a062a1c";
  uv2nix = "c361746c7d630d98b972378290547c8d35542a7a";
  vision-review-agent = "4520467de182ec7ad53e23a880664354e2ff52a4";
  wallpapers-src = "a6c8891c5612688a770c41a6d5fcc531155b8519";
}
