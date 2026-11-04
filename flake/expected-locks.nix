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
  art-dupl = "308d8d7510c0743980575d1e7ffa6fb903b96d59";
  art-dupl-src = "308d8d7510c0743980575d1e7ffa6fb903b96d59";
  bank-sync = "cb7495a8637e9d260a3bbbef93e7893d1df93935";
  branching-flow = "d17cb1aec720939b75dfb132a7c135cffe5b2717";
  brandid-lint = "8a4230f6c633231fc1afa4d37b2b14966a0f08c1";
  browser-history = "98cfec09be088e4aca262cfe6715abde3a1aed96";
  buildflow = "317b0e768c81de03d7de38a41be5eb03db28e699";
  cmdguard = "4ecff5c3b61257712574e03c49d8a83d0024f1e8";
  crm = "900bf55f18d0da734b4a431ffd531269371c3eb0";
  crush-config = "8604de36911ef98e1372f7c88b02b3b6751b2c88";
  crush-daily = "87d01bdc40822f379039e5baa2a73a16da761c49";
  cv = "16a656f4924069efcee122c3f7f8ccf27d592a21";
  cvagent = "4f2c4dffb767df027ead65c8c5aebbed66a01ff6";
  dankMaterialShell = "d95a41da4b52dbe5cccba046b3c648a6ea151ed4";
  discordsync = "c624aca2dcef347d58d28d71bf4832f3beb46e0c";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "b75d15f1bf621895d03b217a5ef9df020a7afd2e";
  docs-gates = "acbc98ab68298e13d294f04435601286f416569a";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "cc5f133d892eaf102809d9997eaab2e14d38b376";
  erraudit = "fa5575f931b607c056dc1a36719f63073e560358";
  file-and-image-renamer = "973dd383ba98ae8b6e3b4b3a95f690c627bb49ab";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "ea2630b7470978622c7689a1ff75d2b389175399";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "204b6977e00caac19e2313015a598543ca7be150";
  go-auto-upgrade = "97cac4a948933bcc2ae4464646b0cb3f27e4c7cf";
  go-branded-id = "8a4230f6c633231fc1afa4d37b2b14966a0f08c1";
  go-commit = "39f7ddac0ef5090bcc844a0ad661de217f2078e1";
  go-cqrs-lite = "f30247c2b00ce04f8b95f4c87090335d7ff47065";
  go-error-family = "d8c8391cfdcefe35cf53fc6a02295f2192bbbeb2";
  go-filewatcher = "a965e6b8be500594e117eb52e4269fefa90cfcfb";
  go-finding = "49669e3675e2818919d32ae18075185f8ed4d012";
  go-health-dashboard = "d4a65347ae999d578fc515aa7d7e6c64753dd7bc";
  go-humanize-linter = "f48b5441ba0ed9c24368180e5cdd5e50f7c478f8";
  go-nix-helpers = "2c5d1d75aeacaaf6ddf558fd7d7bd5a4f4f7687a";
  go-output = "ba5033465f9b8e39b876397f01e696fed1a81cd7";
  go-paperless = "241f8efe3bfc03c13b9f6091f6eb5c35c14b1025";
  go-structure-linter = "e5b069bfa307f88c89297a25bb1b447cfccd642e";
  go-taskqueue = "bfbfde6a1eded1aee7a8b7433a17ac3f0e05b7c1";
  gogenfilter = "ebdac855fea9ed24ed20e4e0590ab80fd24d826d";
  golangci-lint-auto-configure = "072921f17af7c57955ff3bf7ac3596b378ad7807";
  helium = "7945a36a1ef9a47cc3c3c094a16692b4beb8d59a";
  herdr = "ee5bfb5041bb3e4a49d591c72308aae3c81ecdde";
  hermes-agent = "0329638c2bf0438552145589787e355bf23343fe";
  home-manager = "b787c48e2ec57a9d098f5c2721882a3bc1e16f97";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "55e9a0a23de055acf61f83864fafca4f6924271e";
  inboxclean = "e2f68d05b859c0d6be0e0f4b7a9ef0a1c006393f";
  index = "d624a2faa7f086d945da75475a7b3dbde2cae97b";
  journal = "653acc12fe92cff29fbb59336885f7b4a0c6d6a9";
  library-policy = "c1dc17ae97bc732dd21bd929bbc8a9acb148621e";
  md-go-validator = "c976f3263745f46192cd145ac8351a54aa833937";
  media-atlas = "3cbd374f3a5ff14c6fea0ad39b971aa14dc65f68";
  monitor365 = "f7806d9af28888561c6b765ba0fe863120b6c17d";
  mr-sync = "3ce3d7296803698c9166598f5f3c5fc5a2118553";
  niri = "9ee3e13b60643448228353097880521658b2fe0e";
  niri-session-manager = "fbc96f843edc2022e3f8fde9bec33d770e96b75a";
  nix-amd-npu = "8848c6f3382852290ac25fbe7634058c4e9c037e";
  nix-darwin = "ff0e21a414d4547183396da1b44a66f2577b65e9";
  nix-email = "add3db94ca1ace449812d94c9d59e4dd0e647645";
  nix-homebrew = "52bc87da3f30c2261a6d1cfef3c892097b53daeb";
  nix-ssh-config = "8c083ed1e823de2f00447468d077ca411b7673ee";
  nixos-hardware = "04c6b94fa104bc23650983a4513aea196794d321";
  nixpkgs = "fe13242281a67641c0102cdb1087f0ebe586c7df";
  nixpkgs-llama-rag = "0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
  nixpkgs-unstable = "1d060086d60cb76a40cf37109f979d88a5bd6396";
  nsfw-classifier = "f8f83822af56905803772a4c488c24471f95bdc6";
  nur = "4a3e5f3e14c14af4bbce83fd49df45f1e9db45a2";
  offline-banner = "2ccdf6ec04f32b94aa2b8ddd7d35a38b5daf2903";
  otel-tui = "5e7cf2f4dfc6f06a8c71f49f4d2b66672a7b50f6";
  overview = "b4b36c73f15f069f4334012fddc5943155206b0c";
  papdashboard = "c0b29a360818997041a9844f7d47c30ce20caa21";
  paperless-gpt-src = "0a59ea4b2c0b70afbf01bafcd0a0858372368009";
  project-dependency-graph = "aaac17c167b903ea59c861a9dc04b466466b9893";
  project-discovery-daemon = "a6dd6a302e386c5025c2fe81f0c888f2a87fd331";
  project-meta = "3ab5e690849d1b20781793e499d54710517d94ee";
  projects-management-automation = "4053b2ed9a06a740a8045de5cbdea08c5b9ffdbf";
  pyproject-build-systems = "461a6a8540307fb9c05b8f6ad29e9720d2a621db";
  pyproject-nix = "bf7d4b1d6de61db02fd4e748395634f03006e5de";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  quotaboard = "47b9dd14a6a1c85e3dd2feacc862847d730e67ed";
  rust-overlay = "7fcafdf6f0761462d68012aba6a627be3f008d68";
  samber-linter = "329c33c6eae0c8842ad9f8161d13773945e51747";
  signoz-collector-src = "6355ea5bea0759f73cc027e03a8362aee2341a20";
  signoz-src = "375b3f8305720b236a83b50955269c60d96e1f9e";
  silent-sddm = "d477613b07ca13729af20cb4699b308ac7348d2f";
  sops-nix = "b18e01ce148eb3efff5de2f2d3181ca53b2b2a54";
  storage-collector = "0569c46c3ca4c2959e711a5cf8f0d3545f912436";
  superfile = "e5f3327caf9decf79b7d19a75a77a6eceff5b396";
  systems = "d36eeed142f88b5a636f2e3856a53c61654cf29b";
  templ = "dd6c9861fa78fb6d602da9b1ed1dc54ae7752ffe";
  todo-list-ai = "2365fa243a89862bd834ab7cb29cabc0e8087ed4";
  treefmt-full-flake = "d4817f5494feca3c5e927b58032ddcd718dbfdff";
  treefmt-nix = "0d6d739a833ba9a9c93034862e4a7b061a062a1c";
  uv2nix = "c361746c7d630d98b972378290547c8d35542a7a";
  vision-review-agent = "59cc2721467905c205100fde344f517c57b615fa";
  wallpapers-src = "a6c8891c5612688a770c41a6d5fcc531155b8519";
}
