# Shared shell aliases (Fish, Zsh, Bash)
# Define once, use across all shells
_: {
  # Common aliases for all shells
  # Home Manager's shellAliases option will handle shell-specific translation
  commonShellAliases = {
    # Essential shortcuts
    l = "ls -laSh";
    t = "tree -h -L 2 -C --dirsfirst";

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
