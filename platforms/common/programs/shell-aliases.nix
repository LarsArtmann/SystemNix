# Shared shell aliases (Fish, Zsh, Bash)
# Define once, use across all shells
_: {
  # Common aliases for all shells
  # Home Manager's shellAliases option will handle shell-specific translation
  commonShellAliases = {
    # Essential shortcuts
    l = "ls -laSh";
    t = "tree -h -L 2 -C --dirsfirst";

    # NOTE: superfile (`spf`) deliberately has NO alias here — the nixpkgs/upstream
    # flake binary is named `superfile`, and cd-on-quit needs a shell FUNCTION
    # (defined in fish.nix / zsh.nix / bash.nix). An alias of the same name
    # would shadow the function (fish resolves config-defined functions before
    # autoload files; zsh/bash expand aliases before function lookup).

    # Password manager shortcuts
    kop = "keepassxc &";

    # Development shortcuts
    gs = "git status";
    gd = "git diff";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gl = "git log --oneline --graph --decorate --all";
  };
}
