# Jujutsu (jj) — Git-compatible DVCS. Mirrors the identity/signing setup in git.nix.
# NOTE: pkgs.jj is a JSON stream editor, NOT this tool. The HM module installs
# pkgs.jujutsu and renders ~/.config/jj/config.toml.
{ ... }: {
  programs.jujutsu = {
    enable = true;

    settings = {
      user = {
        name = "Lars Artmann";
        email = "git@lars.software";
      };

      ui = {
        editor = "code --wait";
      };

      # SSH signing, same key as git (git.nix). behavior = "own" signs all
      # commits authored by us whenever we modify them — the jj equivalent of
      # git's commit.gpgSign = true.
      signing = {
        behavior = "own";
        backend = "ssh";
        key = "~/.ssh/id_ed25519.pub";
        backends.ssh.allowed-signers = "~/.ssh/allowed_signers";
      };
    };
  };
}
