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
#      { jq -r '.nodes.root.inputs|to_entries[]|select(.value|type=="string")|"\(.key)\t\(.value)"' < flake.lock; } \
#        | while IFS=$'\t' read -r name nk; do \
#            rev=$(jq -r --arg nk "$nk" '.nodes[$nk].locked.rev? // empty' < flake.lock); \
#            [ -n "$rev" ] && printf '  %s = "%s";\n' "$name" "$rev"; done
#      Diff the regenerated body against the committed one: every changed line
#      must be a rev the float actually moved. A row you did not expect means the
#      lock moved again underneath you — re-derive, never hand-patch.
#   2. prove the new revs still evaluate:
#      nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel \
#        --keep-going --no-link > ~/.cache/lockfloat/float-proof.log 2>&1; echo rc=$?
#      ALWAYS capture to a file. `| tail` exits 0 and hides every root failure.
#   3. commit lock + registry TOGETHER — the registry's git history is the
#      float audit log. Proof RED? Fix upstream-first (or revert BOTH that
#      input's registry row and its lock rev); never commit an unproven float
#      and never delete rows to go green.
#
# Seeded 2026-10-25 from the live flake.lock (94 rev-carrying root inputs; 2026-10-25 regen: inboxclean pin lift + new nixpkgs-unstable input).
{
  art-dupl = "1b165cdb90fbdc554335576dd2caafb501f9d063";
  art-dupl-src = "1b165cdb90fbdc554335576dd2caafb501f9d063";
  bank-sync = "310d55faa56ec496cf4d39c4834ef040f4b210ff";
  branching-flow = "f28419ee2c5b7cf6ad46233bf6cf2d9f2b257546";
  brandid-lint = "dd29f9b328a3ebd4346f310fd1be6e5d42be7a71";
  browser-history = "22832ea18fe7991a76cc6a645815754bf4e7818a";
  buildflow = "b085569a1550c9f1590b23c75edbade07ba961fa";
  cmdguard = "8185582ff2becf5acf0089b716a35698802fe4d9";
  crm = "a8b85507183c69f740debc099799fe02e767ea8d";
  crush-config = "028d6402a6aa3257e323a4396880b293730a5e2d";
  crush-daily = "43da0172a78c637e158fd40db3f7c55f77f03aaa";
  cv = "8243b2d42f0cf7da9caa93ddc5d76946d9a2e46d";
  dankMaterialShell = "ee6e941459f0b38e1b075757370a6a6d4cc3daba";
  discordsync = "e219d156bd38f3d167c2516c7d675d82366165cf";
  disko = "cedd626e11b635470fa6f9fdb8ad79b0075dd7f9";
  dms-paste = "e8928d213c2dd1f992963fca3d49b69385511cb2";
  dnsblockd = "f9bb6477c5b29490eb7c785a6c6c7d83658e2632";
  domains = "aba7cb95b31399cdae936ad7a12f5fffff7dc312";
  emeet-pixyd = "9b5f5cd6cfe73792715f97a26f869b29a9b72d02";
  erraudit = "6fe130d39a8b5a6d633a3946cc6e3b922721efd6";
  file-and-image-renamer = "2bb1e5869346aead7320f70f9b32a4ac3344d726";
  flake-compat = "5edf11c44bc78a0d334f6334cdaf7d60d732daab";
  flake-parts = "024633cd702b10285db5cb19b40ad48d2399ba60";
  flake-utils = "b7a79d3fea1e214f6d668d521cecec0c01e26544";
  git-hooks = "1ba1dbfe28738c9a71c266be6efa5b89e75491a9";
  go-auto-upgrade = "3d6eded262c2d5416ac75ad6b36f1451a846d118";
  go-branded-id = "dd29f9b328a3ebd4346f310fd1be6e5d42be7a71";
  go-commit = "953c7484c35517de5717a044ec5c3a80abd83406";
  go-cqrs-lite = "654d2f530cbdfafbf7a422b6c087e380273acf2c";
  go-error-family = "a23dc0e08234909e63ee3dc7a7833319bc195c54";
  go-filewatcher = "16ea6599150a70a55acd043d4236be71b439ed60";
  go-finding = "8578f743638a6330373af34dd7b4a3fb4731632e";
  go-health-dashboard = "44d8a24e58cd99aca8528041854181a361c0ad48";
  go-humanize-linter = "ec19200cb3f547e5856622a5c57eafeb81131050";
  go-nix-helpers = "07aefa24b85ba40758da508b909cf573fd5acbd8";
  go-output = "06357826d1a9886e5b10a9aa65c8d27ce6b25e3c";
  go-structure-linter = "0ebb272dc4316e07f045d2b1d704744104c93d4b";
  go-taskqueue = "477c9af4ac9056e939af07112d4871b78bea073f";
  gogenfilter = "ad71a7f11c3a36e5c72c382a3d59a8c118889efe";
  golangci-lint-auto-configure = "9ca0054b23e7e9fe4d6220f0cac8feb4bd09491f";
  helium = "b8621d3ce7fb0468f0a47e74a02cb0cb1b7992fb";
  herdr = "2713feb56e9c9db33992db0a262c68f7426d46dd";
  hermes-agent = "0329638c2bf0438552145589787e355bf23343fe";
  home-manager = "1e3ebeb683d055d1675d3f64e6d2b186cb2ee504";
  homebrew-bundle = "a3265c84b232e13048ecbf6fc18a2eedfadbeb08";
  homebrew-cask = "b612f2bbeda1e4e9e0dc5cec3106942f9f40f068";
  inboxclean = "5c52f31506d114f508d3cf5832c552da3b5f2228";
  index = "f583b68abd981df5663c235d3618a189bba51fe7";
  journal = "b6efb5bbe3a388731e8ceff28ac330124d836c11";
  library-policy = "4020b31d31e8a8cabea7dafab102f49fd4764f44";
  md-go-validator = "3f466de78df43628ca4c59803151f4345f67607a";
  monitor365 = "10d252918bfcea33f341385a50182f26aaa75182";
  mr-sync = "84b33709e649f73109c9f9a162b84a6d3976a18f";
  niri = "9ee3e13b60643448228353097880521658b2fe0e";
  niri-session-manager = "fbc96f843edc2022e3f8fde9bec33d770e96b75a";
  nix-amd-npu = "8848c6f3382852290ac25fbe7634058c4e9c037e";
  nix-darwin = "bb0b90dbd54e207100de72b5dcbe3188c98a4b69";
  nix-email = "234c6eccf32221e731052d9a45376b54053d1c9f";
  nix-homebrew = "c11cccfdd36dd69b5323d70d354b2853379c2426";
  nix-ssh-config = "8c083ed1e823de2f00447468d077ca411b7673ee";
  nixos-hardware = "8ba09466dc929acf5c8bb3e0cc40f472a7df3630";
  nixpkgs = "fe13242281a67641c0102cdb1087f0ebe586c7df";
  nixpkgs-llama-rag = "0968519e14f7aa7d3e9b389682bd74d2b51c8ce8";
  nixpkgs-unstable = "3ec636362e1816bc2f0888fa0fa2c69f1bc9e504";
  nsfw-classifier = "58d398dc68b94f16df2adefdeb8f2864d950080f";
  nur = "751c7206db3b6c53e862839c601bfac332dace94";
  offline-banner = "dc8a239ded65cd06e617594f1918e85ef8b60fd7";
  otel-tui = "5e7cf2f4dfc6f06a8c71f49f4d2b66672a7b50f6";
  overview = "1c467991e698e59a68301ebc38c2be72abc83dcf";
  papdashboard = "b370f98dd1a10da252a3a7e5d0c0f9fcee93d25f";
  paperless-gpt-src = "0a59ea4b2c0b70afbf01bafcd0a0858372368009";
  project-dependency-graph = "9836197c61ec18537f1bd59ef0ecfad04915f98a";
  project-discovery-daemon = "145cd73db456320adcde0d71b77a535e03bbd7f4";
  project-meta = "9ba321b2a73b937c1b15294b36777b2d47eac84f";
  projects-management-automation = "b13d2e2116e3bc45ffae4cb0dbdb32edf2e6f42f";
  pyproject-build-systems = "a17819c85163988e063806ffc4f6d2716bc8ead8";
  pyproject-nix = "ddc400a6883b042646d0940e65971bb7f7e96107";
  qmd = "facd35e01359e59d938bc9418e93fb9318addee3";
  rust-overlay = "c7e9d512653a35ef4d5879c3df4d44d7b78d0e6d";
  samber-linter = "2728734d1b499b004c5e9e59ad1a8822d23a98db";
  signoz-collector-src = "b8fed011eafe8f2acaf204d4a7c8abedc1654cc8";
  signoz-src = "375b3f8305720b236a83b50955269c60d96e1f9e";
  silent-sddm = "d477613b07ca13729af20cb4699b308ac7348d2f";
  sops-nix = "60182817ee048ac94b4c68ea76d5ef2e8aac730d";
  storage-collector = "0569c46c3ca4c2959e711a5cf8f0d3545f912436";
  superfile = "97af177d4790cec601dc3a45a1e7c2983bb0dfc5";
  systems = "d36eeed142f88b5a636f2e3856a53c61654cf29b";
  templ = "f6492f22bef32521a9d90400ec44de5ed3b7546b";
  todo-list-ai = "903e88a93b8fa8fcb04d8f160557a9c9953527ed";
  treefmt-full-flake = "d4817f5494feca3c5e927b58032ddcd718dbfdff";
  treefmt-nix = "0d6d739a833ba9a9c93034862e4a7b061a062a1c";
  uv2nix = "0fdaa03ea3c3c16dbb1fe4d69108f07227a4b42d";
  vision-review-agent = "8cbb0ec900a84426a6e82ce1f9e5e2ff245c9f45";
  wallpapers-src = "1a67f4c8a3e4bab30ab7d4a0156439dfb5c6638b";
}
