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
  branching-flow = "8fd75a742970ad258a288abf24a6c349c820d202";
  brandid-lint = "8a4230f6c633231fc1afa4d37b2b14966a0f08c1";
  browser-history = "c4859aec4e87470f0d9c8e59db2416c1e8d95502";
  buildflow = "a1d0c149276576094610a581e62833327a9cb2c8";
  cmdguard = "f2240dd724a1ae9281b69e31bc0ac4f3a34e126b";
  crm = "63a396097495e6ad813056d76ba669d2ba163a01";
  crush-config = "cc5394b51b6368691f8eed885e1aac9c6f7b13c6";
  crush-daily = "e8db4d3154d9469df76cb1974ee735a6df76a928";
  cv = "16a656f4924069efcee122c3f7f8ccf27d592a21";
  cvagent = "30b379b3e03eaa574e30c65e029463c7a100c70d";
  dankMaterialShell = "c1c789a1584fb09446293c923b434dcb6325b354";
  discordsync = "ea6c444c06284584d34fbbeb1ffa7d12f80a897f";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "728b333937df2213940f650d4458cea7a9911750";
  docs-gates = "1715886439923c7dd834a2a7d8bfe45eb1efb98e";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "ac1acac2d937c3ca83c06d73751d3990b06ee555";
  erraudit = "c1902feae1284abc160b166501368e8d31ef3971";
  file-and-image-renamer = "973dd383ba98ae8b6e3b4b3a95f690c627bb49ab";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "ea2630b7470978622c7689a1ff75d2b389175399";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "204b6977e00caac19e2313015a598543ca7be150";
  go-auto-upgrade = "babe9c554338f7d89fbbaefca867fd278cb9972a";
  go-branded-id = "8a4230f6c633231fc1afa4d37b2b14966a0f08c1";
  go-commit = "2da8caecb82c927e6ca7ca04a682e1f73dd145fa";
  go-cqrs-lite = "254e4839c1517c181797e0a0e6aa17744de99cf7";
  go-error-family = "7ccca5c62037bab213d548f21a8be333781c0e9c";
  go-filewatcher = "9b8e5fb1a02db8ed014ce6d60a4b015c63497fce";
  go-finding = "49669e3675e2818919d32ae18075185f8ed4d012";
  go-health-dashboard = "7ba23849fc9f35588ca8d96ec7652cda36003024";
  go-humanize-linter = "f48b5441ba0ed9c24368180e5cdd5e50f7c478f8";
  go-nix-helpers = "2c5d1d75aeacaaf6ddf558fd7d7bd5a4f4f7687a";
  go-output = "ba5033465f9b8e39b876397f01e696fed1a81cd7";
  go-paperless = "241f8efe3bfc03c13b9f6091f6eb5c35c14b1025";
  go-structure-linter = "0f92c65eba5f8b59dc2a27fd1d9fbc7f1567683c";
  go-taskqueue = "fcedea0cd471efa34eeded4d7a91ebdb89e91b87";
  gogenfilter = "ebdac855fea9ed24ed20e4e0590ab80fd24d826d";
  golangci-lint-auto-configure = "28340f6352b629bdf2225c88f1c7f64308279f67";
  helium = "ef91010a4fcc551b5cb24f52608dc8d45c527d9d";
  herdr = "ee5bfb5041bb3e4a49d591c72308aae3c81ecdde";
  hermes-agent = "0329638c2bf0438552145589787e355bf23343fe";
  home-manager = "b787c48e2ec57a9d098f5c2721882a3bc1e16f97";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "64f8b45863ed50607836c1baa64aac5ae38700f4";
  inboxclean = "7965e6944968dbfcc2a2feb1ac703bf213d2aa7e";
  index = "73e0d5f27c3dbee6edb712ce4bafc8c06a194f2e";
  journal = "4a63e7fd3ddd3aefcc92bfbcc959ce5918a63303";
  library-policy = "7fc09832355ee5f43dc7784b4a5510d57ccb0abd";
  md-go-validator = "13a0e7898d982a5f27a77ea4712ec8c2339e1c96";
  media-atlas = "f7f4a8a1f366ac8d21c83f4745a378dbc00f9da0";
  monitor365 = "164e159a4b6c02a933ca911094e6c5e58dfdd86a";
  mr-sync = "cb369dc3bd05e01390b939709c6f1813d6b8bddf";
  niri = "9ee3e13b60643448228353097880521658b2fe0e";
  niri-session-manager = "c79732161f23268aa1077b4d8ebf5f3fc7f3867d";
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
  nur = "3a14a647426e4fdc02bd607ba8a7708c09d2467f";
  offline-banner = "97b8056d55991e012249445fc1afc608e409bd7b";
  otel-tui = "d43d3f9edbe2c4c61380a10030df4ad02ffc3206";
  overview = "67b2fac96799f269348f51eca78903df6c14dcc8";
  papdashboard = "81668050515e2e7bbea2beab1cdf29a56eaff993";
  paperless-gpt-src = "0a59ea4b2c0b70afbf01bafcd0a0858372368009";
  pim-sync = "1b70ed4bc523d60fc7e72f6284311e42b3c950c1";
  project-dependency-graph = "8335670e8e46e103cefce3e94f57fcc878720a3f";
  project-discovery-daemon = "ab80974e1e8d722e8516e1ab1c6f5c8d01d0ce5d";
  project-meta = "1c666a4c86af0406d4ba564bd1f322fef1a8552b";
  projects-management-automation = "f598fc9f0503301078bdf0d052a43012d9be70f1";
  pyproject-build-systems = "947b2b0c973de462b19577715f04ba8d6f48ed7e";
  pyproject-nix = "d43f0e74444c1f266c640fc49ce6ce6fb69d33c3";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  quotaboard = "012db1dbaabc233c4e4e0170127ca16685a1452f";
  rust-overlay = "19e0e6c951a7a8a7d3232c64e58d26b89df44c60";
  samber-linter = "6978204b1a910896054c824e5886178d427def8d";
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
