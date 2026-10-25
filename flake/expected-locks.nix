# Expected lock revs — the reviewed registry behind the lock-float eval gate
# (lib/lock-float-audit.nix, forced via allEvalGuards in flake.nix).
#
# Every root input that locks a rev MUST have an entry here, and the entry
# MUST equal flake.lock's locked rev. A blanket `nix flake update` therefore
# fails eval until the floated revs are re-registered — making each float a
# conscious, reviewed act instead of a silent eval-break that surfaces as a
# DOA deploy (the 2026-10-23 wave: hermes-python IFD + crowdsec module
# conflicts rode one blanket update).
#
# Deliberate float procedure (the ONLY way past the gate):
#   1. nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel \
#        --keep-going --no-link      # prove the new revs still evaluate
#   2. regenerate this file:
#      { jq -r '.nodes.root.inputs|to_entries[]|select(.value|type=="string")|"\(.key)\t\(.value)"' < flake.lock; } \
#        | while IFS=$'\t' read -r name nk; do \
#            rev=$(jq -r --arg nk "$nk" '.nodes[$nk].locked.rev? // empty' < flake.lock); \
#            [ -n "$rev" ] && printf '  %s = "%s";\n' "$name" "$rev"; done
#   3. commit lock + registry TOGETHER — the registry's git history is the
#      float audit log.
#
# Seeded 2026-10-25 from the live flake.lock (93 rev-carrying root inputs).
{
  art-dupl = "1b165cdb90fbdc554335576dd2caafb501f9d063";
  art-dupl-src = "1b165cdb90fbdc554335576dd2caafb501f9d063";
  bank-sync = "f2fe2393d45a821d9ce470f81eec6a8dda25280e";
  branching-flow = "becd8a1aec1a86eec34d760a38ccbacbc9cbab88";
  brandid-lint = "dd29f9b328a3ebd4346f310fd1be6e5d42be7a71";
  browser-history = "ca260f36c599a042115dd70efd25ac3006ab960b";
  buildflow = "08e9cae2132b48d48819d4106f4b0493f76d01cb";
  cmdguard = "5be908f329cfa37ccdb38af103c7899627e57232";
  crm = "38ff2c464eafefc149281d249d56d264bb795890";
  crush-config = "7639e20d1e16ff713bfaf4490b350b0b78dff378";
  crush-daily = "abe5489ef0a21ce3e704a1fc579b8830934925e3";
  cv = "88e0d1232cb0bc095e9f19ecf76f11565dc669fc";
  dankMaterialShell = "20bcf8559b10f30f3ad9c169cfecbe86a22f1b63";
  discordsync = "0b08c42f8e894f0551a113a6adbe7b283e9b9481";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "c0670d95d6942936f13f93479b86f67bcbde185e";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "9b5f5cd6cfe73792715f97a26f869b29a9b72d02";
  erraudit = "119791be49105174c44e13b39ea4a0d3066d5271";
  file-and-image-renamer = "a795ed9c6a396eab85cd824cc30a20df6d806157";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "024633cd702b10285db5cb19b40ad48d2399ba60";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "1ba1dbfe28738c9a71c266be6efa5b89e75491a9";
  go-auto-upgrade = "125d7aedabd135982e812c17062e2a1071f1ccd9";
  go-branded-id = "dd29f9b328a3ebd4346f310fd1be6e5d42be7a71";
  go-commit = "8cb641c51840be1ae7730bbf73553b1da0e7ad76";
  go-cqrs-lite = "0ed4ec9095ec3ba9bc85f2a8f6b83b64bb484201";
  go-error-family = "a23dc0e08234909e63ee3dc7a7833319bc195c54";
  go-filewatcher = "112a72f92b34082b899d69d821c56fb46e425123";
  go-finding = "8578f743638a6330373af34dd7b4a3fb4731632e";
  go-health-dashboard = "3bf1ca035defd81d0b5536b254b0b85eeb5c6c04";
  go-humanize-linter = "be8793eb18aef0517669dc1ba309899c91c12fae";
  go-nix-helpers = "07aefa24b85ba40758da508b909cf573fd5acbd8";
  go-output = "06357826d1a9886e5b10a9aa65c8d27ce6b25e3c";
  go-structure-linter = "15794344c26e909978dd00f9a49923f583c3b97f";
  go-taskqueue = "4e26f5bcc761cdab89525f7fa73d21c6fa672ccf";
  gogenfilter = "e8a33dd56d9a848efcedc493931af811dc6ed49e";
  golangci-lint-auto-configure = "f511153d0019bdd0ca328d406ba385a4e71c2451";
  helium = "ebac6e7f4af50aa48200ae77ea6606061e2d3e84";
  herdr = "5608de0608918aba2f9d501e7793b984a0ca9cfa";
  hermes-agent = "4ea8d23cc9f527332ccb1d55359b27741b6ea51b";
  home-manager = "c216bf5a1f173b0481bd5c8c489ebe5595ecc68c";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "b28dbc4693b0a109b14fc4cc6fbec9621a29500d";
  inboxclean = "f79e928a524d013f8aaf5487af480ff8711d0818";
  index = "f583b68abd981df5663c235d3618a189bba51fe7";
  journal = "69d9b10d9e38308faf33e90f04283a58fa360aa4";
  library-policy = "a9fd5e3b821ac3b39d676f15df464a0e0655d4cf";
  md-go-validator = "3f466de78df43628ca4c59803151f4345f67607a";
  monitor365 = "77b4a3aec788956760d28faf97b79ad7f9c55ebe";
  mr-sync = "a16a9f6ed44596e7da663b2c884d7441ebea4593";
  niri = "9ee3e13b60643448228353097880521658b2fe0e";
  niri-session-manager = "fbc96f843edc2022e3f8fde9bec33d770e96b75a";
  nix-amd-npu = "8848c6f3382852290ac25fbe7634058c4e9c037e";
  nix-darwin = "bb0b90dbd54e207100de72b5dcbe3188c98a4b69";
  nix-email = "c779a324698a5f2f4ab3d33a28abe15f7cc13319";
  nix-homebrew = "c11cccfdd36dd69b5323d70d354b2853379c2426";
  nix-ssh-config = "8c083ed1e823de2f00447468d077ca411b7673ee";
  nixos-hardware = "1b418b8f203e49a92f250f8babdd19af1b6f7a7f";
  nixpkgs = "fe13242281a67641c0102cdb1087f0ebe586c7df";
  nixpkgs-llama-rag = "0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
  nsfw-classifier = "61a5257c128c922439524d917f00db276412f8ab";
  nur = "e85f30ae202013cd99fc2f2dccc518a6fe63ac6a";
  offline-banner = "dc8a239ded65cd06e617594f1918e85ef8b60fd7";
  otel-tui = "5e7cf2f4dfc6f06a8c71f49f4d2b66672a7b50f6";
  overview = "e7b2cbb87eb3d61a962ecbf0a13bfadad7a29381";
  papdashboard = "b370f98dd1a10da252a3a7e5d0c0f9fcee93d25f";
  paperless-gpt-src = "0a59ea4b2c0b70afbf01bafcd0a0858372368009";
  project-dependency-graph = "40bba335378867a5fa3159c2003a31bdeee35edc";
  project-discovery-daemon = "d4443ffa73175098ad71ab0f30cd7b081310269f";
  project-meta = "4f1a0c6b85be266759ba2e168a3abba8bf4d8cd6";
  projects-management-automation = "bdd12a353ecb21fd16b7883d862106a4b4bd2fa5";
  pyproject-build-systems = "a17819c85163988e063806ffc4f6d2716bc8ead8";
  pyproject-nix = "ddc400a6883b042646d0940e65971bb7f7e96107";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  rust-overlay = "5b9f1198b59bcb31c5c3250b332e7d77590e6306";
  samber-linter = "03ea73775e778dfd13ddcec955f30423b7c9bdeb";
  signoz-collector-src = "b8fed011eafe8f2acaf204d4a7c8abedc1654cc8";
  signoz-src = "375b3f8305720b236a83b50955269c60d96e1f9e";
  silent-sddm = "d477613b07ca13729af20cb4699b308ac7348d2f";
  sops-nix = "442449fa7b1fe6c692d0103ac9fc8f9e82931cf3";
  storage-collector = "0569c46c3ca4c2959e711a5cf8f0d3545f912436";
  superfile = "97af177d4790cec601dc3a45a1e7c2983bb0dfc5";
  systems = "d36eeed142f88b5a636f2e3856a53c61654cf29b";
  templ = "ea160d4b448143e10ad25651d1150898fb4dd7d2";
  todo-list-ai = "903e88a93b8fa8fcb04d8f160557a9c9953527ed";
  treefmt-full-flake = "d4817f5494feca3c5e927b58032ddcd718dbfdff";
  treefmt-nix = "0d6d739a833ba9a9c93034862e4a7b061a062a1c";
  uv2nix = "0fdaa03ea3c3c16dbb1fe4d69108f07227a4b42d";
  vision-review-agent = "8cbb0ec900a84426a6e82ce1f9e5e2ff245c9f45";
  wallpapers-src = "1a67f4c8a3e4bab30ab7d4a0156439dfb5c6638b";
}
