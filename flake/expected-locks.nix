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
  brandid-lint = "77198852914db0d3d0db7d8b770e4c3f35c3dc41";
  browser-history = "9daaa804d86a00b1546d72bbd531e5ecae4e27ba";
  buildflow = "2d6bbee1775e55826b63d1139bdf427f5f2ddf09";
  cmdguard = "7ab3f21740684fbc53ac07e5d7f3231e67993e42";
  crm = "900bf55f18d0da734b4a431ffd531269371c3eb0";
  crush-config = "227a1307f79a3abd7c746f98e985d84660720744";
  crush-daily = "07cf5ca43bed84dcab77878be14855e9495e15a4";
  cv = "16a656f4924069efcee122c3f7f8ccf27d592a21";
  cvagent = "4f2c4dffb767df027ead65c8c5aebbed66a01ff6";
  dankMaterialShell = "15073346175f34f49a6e80aa17104c2827eb0e05";
  discordsync = "c624aca2dcef347d58d28d71bf4832f3beb46e0c";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "8b5352f3270bacf9777f8427c642a8d05ae5bb7c";
  docs-gates = "6ed909f3309102120e9fefee7b67a9ad9317e3e7";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "cc5f133d892eaf102809d9997eaab2e14d38b376";
  erraudit = "fa5575f931b607c056dc1a36719f63073e560358";
  file-and-image-renamer = "857e2f175fbcf5b18f300c3bf4a86aae2a237739";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "ea2630b7470978622c7689a1ff75d2b389175399";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "1ba1dbfe28738c9a71c266be6efa5b89e75491a9";
  go-auto-upgrade = "97cac4a948933bcc2ae4464646b0cb3f27e4c7cf";
  go-branded-id = "77198852914db0d3d0db7d8b770e4c3f35c3dc41";
  go-commit = "963d20c11d0a9df12c5257e749a3c3f5d51b1262";
  go-cqrs-lite = "f30247c2b00ce04f8b95f4c87090335d7ff47065";
  go-error-family = "d8c8391cfdcefe35cf53fc6a02295f2192bbbeb2";
  go-filewatcher = "a965e6b8be500594e117eb52e4269fefa90cfcfb";
  go-finding = "26863a3b7c9b943526b2885d6acae87d24e0ae6f";
  go-health-dashboard = "d4a65347ae999d578fc515aa7d7e6c64753dd7bc";
  go-humanize-linter = "8ac99125c10beb0444f7e621545104e6b58be1b8";
  go-nix-helpers = "2c5d1d75aeacaaf6ddf558fd7d7bd5a4f4f7687a";
  go-output = "ba5033465f9b8e39b876397f01e696fed1a81cd7";
  go-paperless = "bd1b68842c92e47dc4e61f99e9092c8da908d770";
  go-structure-linter = "e5b069bfa307f88c89297a25bb1b447cfccd642e";
  go-taskqueue = "bfbfde6a1eded1aee7a8b7433a17ac3f0e05b7c1";
  gogenfilter = "eded9738cdec86854660079b9fd7dab5c82d7fb3";
  golangci-lint-auto-configure = "072921f17af7c57955ff3bf7ac3596b378ad7807";
  helium = "7945a36a1ef9a47cc3c3c094a16692b4beb8d59a";
  herdr = "ee5bfb5041bb3e4a49d591c72308aae3c81ecdde";
  hermes-agent = "0329638c2bf0438552145589787e355bf23343fe";
  home-manager = "095fef2f265c3c0da4fe315efba8f8a04495ab34";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "eac29400b54292c776a2e2e8abd165cee96ed058";
  inboxclean = "e2f68d05b859c0d6be0e0f4b7a9ef0a1c006393f";
  index = "d624a2faa7f086d945da75475a7b3dbde2cae97b";
  journal = "653acc12fe92cff29fbb59336885f7b4a0c6d6a9";
  library-policy = "c1dc17ae97bc732dd21bd929bbc8a9acb148621e";
  md-go-validator = "c976f3263745f46192cd145ac8351a54aa833937";
  media-atlas = "18f3cae05049430ef86702a2559d5e339a1c5b2d";
  monitor365 = "ebfa4056f7687f972ff7fd6767a376d755971bd3";
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
  nixpkgs-unstable = "0bb2eedc20e4739f29e8045034f2828ad7054f8f";
  nsfw-classifier = "b43a6da7234c32a7def7eab7063fb2e0d553a26d";
  nur = "351d481889ec339ff0858584eb606503cb1ac49f";
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
  quotaboard = "c98d13ad4b4bdb84b02074c6db29a06fc156b282";
  rust-overlay = "6b29b8e8d3cc8ebda9342fbbcc7ac06eff58e2fb";
  samber-linter = "329c33c6eae0c8842ad9f8161d13773945e51747";
  signoz-collector-src = "bd2b18fed2538300fa724953d653c9bb69ddc12c";
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
  vision-review-agent = "59cc2721467905c205100fde344f517c57b615fa";
  wallpapers-src = "a6c8891c5612688a770c41a6d5fcc531155b8519";
}
