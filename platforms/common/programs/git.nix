{pkgs, ...}: {
  programs.git = {
    enable = true;
    lfs.enable = true;

    # SSH signing via HM's structured option — sets user.signingKey, commit/tag.gpgSign,
    # gpg.format, and gpg.ssh.program. Do NOT use settings.signing: it writes an invalid
    # [signing] section that git ignores (leaving user.signingKey unset).
    signing = {
      format = "ssh";
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
    };

    settings = {
      user = {
        name = "Lars Artmann";
        email = "git@lars.software";
      };

      # Deliberately NOT setting core.compression — git default (zlib 6) is the
      # optimal speed/size tradeoff. Level 9 was 3-10x slower on every loose
      # object write for ~5% smaller objects. Do NOT re-add without benchmarks.
      # pack.compression inherits from core.compression when unset — this is fine.
      core = {
        autocrlf = "input";
        quotePath = false;
        editor = "code --wait";
      };

      # MUST use nested form (gpg.ssh), NOT dotted-key form ("gpg.ssh").
      # The signing module writes gpg.ssh.program (nested); gitFlattenAttrs in
      # toGitINI flattens it to dotted key "gpg.ssh". If settings also uses
      # "gpg.ssh" (dotted), gitFlattenAttrs' `//` shallow-merge drops one key.
      # Nested form lets mkMerge deep-merge gpg.ssh.{program,allowedSignersFile}
      # BEFORE flattening, so both survive.
      gpg.ssh = {
        allowedSignersFile = "~/.ssh/allowed_signers";
      };

      submodule = {
        fetchJobs = 8;
      };

      http = {
        postBuffer = 524288000;
      };

      ssh = {
        multiplexing = true;
      };

      pull = {
        rebase = true;
      };

      push = {
        autoSetupRemote = true;
      };

      "git-town" = {
        "sync-perennial-strategy" = "rebase";
      };

      pager = {
        diff = "bat";
      };

      init = {
        defaultBranch = "master";
      };

      credential = {
        helper =
          if pkgs.stdenv.isDarwin
          then "osxkeychain"
          else "${pkgs.gitFull}/bin/git-credential-libsecret";
      };

      # Rewrite HTTPS GitHub URLs to SSH. WARNING: this caused `nix flake lock`
      # to record `ssh://git@github.com/...` in lock files instead of `github:`
      # entries (removed 2026-07-29, restored on user demand). Run
      # `GIT_CONFIG_GLOBAL=/dev/null nix flake update` to refresh locks with
      # clean `github:` URLs when needed.
      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };

      "coderabbit" = {
        machineId = "cli/98a25a4615614fc5ae0c8a2718076dca";
      };

      safe = {
        "directory" = [
          "~" # User home directory (works on both Darwin and NixOS)
          "~/projects" # Projects directory
        ];
      };

      alias = {
        append = "town append";
        compress = "town compress";
        contribute = "town contribute";
        diff-parent = "town diff-parent";
        hack = "town hack";
        observe = "town observe";
        park = "town park";
        prepend = "town prepend";
        propose = "town propose";
        rename = "town rename";
        repo = "town repo";
        set-parent = "town set-parent";
        ship = "town ship";
        sync = "town sync";
        down = "town down";
        up = "town up";
      };
    };

    ignores = [
      # macOS system files
      ".DS_Store"
      ".DS_Store?"
      "._*"
      ".Spotlight-V100"
      ".Trashes"
      "ehthumbs.db"
      "Thumbs.db"

      # IDE and editor files
      ".vscode/"
      ".idea/"
      "*.swp"
      "*.swo"
      "*~"

      # Temporary files
      "*.tmp"
      "*.temp"
      ".cache/"
      ".temp/"

      # Build artifacts
      "dist/"
      "build/"
      "target/"
      "*.log"
      "*.pid"

      # Node.js
      "node_modules/"
      "pnpm-debug.log*"
      "yarn-debug.log*"
      "yarn-error.log*"

      # Python
      "__pycache__/"
      "*.py[cod]"
      "*$py.class"
      ".Python"
      "env/"
      "venv/"
      ".venv/"
      "pip-log.txt"
      "pip-delete-this-directory.txt"

      # Go
      "*.exe"
      "*.exe~"
      "*.dll"
      "*.dylib"
      "*.test"
      "go.work"

      # Rust
      "Cargo.lock"

      # Java
      "*.class"
      "*.jar"
      "*.war"
      "*.ear"
      "hs_err_pid*"

      # C/C++
      "*.o"
      "*.a"
      "*.out"

      # Environment and secrets
      ".env"
      ".env.local"
      ".env.private"
      "*.key"
      "*.pem"
      "*.p12"
      "*.pfx"

      # Backup files
      "*.bak"
      "*.backup"

      # Compressed files
      "*.7z"
      "*.dmg"
      "*.gz"
      "*.iso"
      "*.rar"
      "*.tar"
      "*.tar.gz"
      "*.zip"

      # Shared libraries (consolidated)
      "*.so"

      # Logs
      "logs/"

      # Generated files
      "*.sql.go" # # https://sqlc.dev

      # AI tools
      ".crush"
    ];
  };

  # SSH allowed signers — lets git verify SSH signatures
  home.file.".ssh/allowed_signers".source = ./git-allowed-signers;
}
