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
  art-dupl = "1b165cdb90fbdc554335576dd2caafb501f9d063";
  art-dupl-src = "1b165cdb90fbdc554335576dd2caafb501f9d063";
  bank-sync = "122508d924843a37848de94c64545f883e241f8d";
  branching-flow = "f28419ee2c5b7cf6ad46233bf6cf2d9f2b257546";
  brandid-lint = "dd29f9b328a3ebd4346f310fd1be6e5d42be7a71";
  browser-history = "f9c8916bc5b9ddf0ff2e55ad960be9b72ec09482";
  buildflow = "4acfb12b5797fe4e558e9e1034ae6af3376433b4";
  cmdguard = "8185582ff2becf5acf0089b716a35698802fe4d9";
  crm = "ef98a573726d3a012e17df1f190c09ea6e004ff3";
  crush-config = "d79602d02729797ca0e28e0d6d42f2d800893d08";
  crush-daily = "83c4d8a3de5035eb00122d3f85307d0636f91224";
  cv = "e168e6d39913680adbb2611a7e1ed5aaf68d4bf9";
  dankMaterialShell = "8ce37501bd9c4dcbac04d1deb4e57d50f3e2c94f";
  discordsync = "79952c46f0bfcc94763e40570741a1c97785d2d2";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "31ee4453ebdbaacfa22f00562dfbf4737dd56990";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "9b5f5cd6cfe73792715f97a26f869b29a9b72d02";
  erraudit = "256200c1d59572ad4db6afdb0c37eae28e6c89d1";
  file-and-image-renamer = "6ce5c2a7220695e3e188d2ec47a53947e31611c3";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "024633cd702b10285db5cb19b40ad48d2399ba60";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "1ba1dbfe28738c9a71c266be6efa5b89e75491a9";
  go-auto-upgrade = "3d6eded262c2d5416ac75ad6b36f1451a846d118";
  go-branded-id = "dd29f9b328a3ebd4346f310fd1be6e5d42be7a71";
  go-commit = "953c7484c35517de5717a044ec5c3a80abd83406";
  go-cqrs-lite = "5e603d5e868c7a8960b984169dc2a222b72449b0";
  go-error-family = "a23dc0e08234909e63ee3dc7a7833319bc195c54";
  go-filewatcher = "16ea6599150a70a55acd043d4236be71b439ed60";
  go-finding = "8578f743638a6330373af34dd7b4a3fb4731632e";
  go-health-dashboard = "75d6874eed176cc1d5ace1b5bdda963b06a7fb6d";
  go-humanize-linter = "ec19200cb3f547e5856622a5c57eafeb81131050";
  go-nix-helpers = "07aefa24b85ba40758da508b909cf573fd5acbd8";
  go-output = "06357826d1a9886e5b10a9aa65c8d27ce6b25e3c";
  go-paperless = "ba4ea1fecce5f7aab778904f218020b0d16ee418";
  go-structure-linter = "0ebb272dc4316e07f045d2b1d704744104c93d4b";
  go-taskqueue = "07a396cadd5085c0aa38a8907db758cefa375840";
  gogenfilter = "ad71a7f11c3a36e5c72c382a3d59a8c118889efe";
  golangci-lint-auto-configure = "9ca0054b23e7e9fe4d6220f0cac8feb4bd09491f";
  helium = "86742b6e69c1f5647843653dab56100941cb1b9d";
  herdr = "ee5bfb5041bb3e4a49d591c72308aae3c81ecdde";
  hermes-agent = "0329638c2bf0438552145589787e355bf23343fe";
  home-manager = "095fef2f265c3c0da4fe315efba8f8a04495ab34";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "eea6c48738eaba41db013a9b83fd77c6bc75e9d0";
  inboxclean = "5c52f31506d114f508d3cf5832c552da3b5f2228";
  index = "f583b68abd981df5663c235d3618a189bba51fe7";
  journal = "1230bf2301ed5f7136b0499e90ea55afaaa9c6fc";
  library-policy = "f36510924184c78b638ae602e848935a627571c5";
  md-go-validator = "3f466de78df43628ca4c59803151f4345f67607a";
  media-atlas = "382d21cb1dfa652b8d7b37e5df1ef28f71b7761d";
  monitor365 = "10d252918bfcea33f341385a50182f26aaa75182";
  mr-sync = "84b33709e649f73109c9f9a162b84a6d3976a18f";
  niri = "9ee3e13b60643448228353097880521658b2fe0e";
  niri-session-manager = "fbc96f843edc2022e3f8fde9bec33d770e96b75a";
  nix-amd-npu = "8848c6f3382852290ac25fbe7634058c4e9c037e";
  nix-darwin = "bb0b90dbd54e207100de72b5dcbe3188c98a4b69";
  nix-email = "9d7b808602668c7d831077a333fa97ce51746c46";
  nix-homebrew = "c11cccfdd36dd69b5323d70d354b2853379c2426";
  nix-ssh-config = "8c083ed1e823de2f00447468d077ca411b7673ee";
  nixos-hardware = "b6754c901c21478fd8450d62101e712b2a4f0d75";
  nixpkgs = "fe13242281a67641c0102cdb1087f0ebe586c7df";
  nixpkgs-llama-rag = "0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
  nixpkgs-unstable = "31ecbaca1bdefa45dffc409f0250bd8039ea0010";
  nsfw-classifier = "58d398dc68b94f16df2adefdeb8f2864d950080f";
  nur = "8cc81fb4a1f27c69833147a761c182926f89aecb";
  offline-banner = "2ccdf6ec04f32b94aa2b8ddd7d35a38b5daf2903";
  otel-tui = "5e7cf2f4dfc6f06a8c71f49f4d2b66672a7b50f6";
  overview = "1c467991e698e59a68301ebc38c2be72abc83dcf";
  papdashboard = "b370f98dd1a10da252a3a7e5d0c0f9fcee93d25f";
  paperless-gpt-src = "0a59ea4b2c0b70afbf01bafcd0a0858372368009";
  project-dependency-graph = "9836197c61ec18537f1bd59ef0ecfad04915f98a";
  project-discovery-daemon = "145cd73db456320adcde0d71b77a535e03bbd7f4";
  project-meta = "9ba321b2a73b937c1b15294b36777b2d47eac84f";
  projects-management-automation = "7dc552fe07e0f4b58b6e9355800ad91f2e29f1d0";
  pyproject-build-systems = "6171a3484937e14cdf2316ed9a60f1c27b6cb71e";
  pyproject-nix = "bf7d4b1d6de61db02fd4e748395634f03006e5de";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  rust-overlay = "afcefd09c71e63663a46e4ce5e09968584f2c709";
  samber-linter = "2728734d1b499b004c5e9e59ad1a8822d23a98db";
  signoz-collector-src = "b8fed011eafe8f2acaf204d4a7c8abedc1654cc8";
  signoz-src = "375b3f8305720b236a83b50955269c60d96e1f9e";
  silent-sddm = "d477613b07ca13729af20cb4699b308ac7348d2f";
  sops-nix = "60182817ee048ac94b4c68ea76d5ef2e8aac730d";
  storage-collector = "0569c46c3ca4c2959e711a5cf8f0d3545f912436";
  superfile = "97af177d4790cec601dc3a45a1e7c2983bb0dfc5";
  systems = "d36eeed142f88b5a636f2e3856a53c61654cf29b";
  templ = "3e969eda7228806e4917c3e1985a4b9058161aca";
  todo-list-ai = "903e88a93b8fa8fcb04d8f160557a9c9953527ed";
  treefmt-full-flake = "d4817f5494feca3c5e927b58032ddcd718dbfdff";
  treefmt-nix = "0d6d739a833ba9a9c93034862e4a7b061a062a1c";
  uv2nix = "c361746c7d630d98b972378290547c8d35542a7a";
  vision-review-agent = "8cbb0ec900a84426a6e82ce1f9e5e2ff245c9f45";
  wallpapers-src = "1a67f4c8a3e4bab30ab7d4a0156439dfb5c6638b";
}
