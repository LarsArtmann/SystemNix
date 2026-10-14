{
  description = "flake-input-pin-audit selftest fixture — every pin class + clean classes";
  nixConfig.warn-dirty = false;

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # clean: branch in path
    branch-path = {
      url = "github:example/branch-path/nixos-unstable";
    };

    # clean: master/main refs, both forms
    ref-master = {
      url = "github:example/ref-master?ref=master";
    };
    ref-heads-main.url = "github:example/ref-heads-main?ref=refs/heads/main";

    # clean: bare branch name + refs/heads/<other-branch>
    stable-branch = {
      url = "github:example/stable-branch/stable";
    };
    fork-branch = {
      url = "git+https://github.com/example/fork-branch?ref=refs/heads/fork";
    };

    # clean: git+file interim pin (exempt class)
    local-interim = {
      url = "git+file:/home/worktrees/local-interim?rev=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    };

    # VIOLATION: 40-hex rev in path (block form)
    sha40-path = {
      url = "github:example/sha40-path/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    };

    # VIOLATION: 7-hex short rev in path (dotted form)
    sha7-path.url = "github:example/sha7-path/d46cb98";

    # VIOLATION: semver tag in path (the qmd form)
    tag-path = {
      url = "github:example/tag-path/v2.8.3";
    };

    # VIOLATION: bare dotted version in path
    dotted-path.url = "github:example/dotted-path/24.05";

    # VIOLATION: ?ref=refs/tags/
    ref-tags = {
      url = "github:example/ref-tags?ref=refs/tags/v1.0.0";
    };

    # VIOLATION: ?ref=<sha>
    ref-sha = {
      url = "git+ssh://git@example.com/example/ref-sha?ref=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    };

    # VIOLATION: ?rev= query on a remote scheme
    rev-query.url = "https://example.com/example/rev-query?rev=cccccccccccccccccccccccccccccccccccccccc";
  };
}
