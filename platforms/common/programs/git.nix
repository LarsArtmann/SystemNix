{pkgs, ...}: {
  programs.git = {
    enable = true;
    lfs.enable = true;

    # SSH signing — fully declarative (key managed by nix-ssh-config)
    signing.format = "ssh";

    settings = {
      user = {
        name = "Lars Artmann";
        email = "git@lars.software";
      };

      signing = {
        key = "~/.ssh/id_ed25519.pub";
        signByDefault = true;
      };

      core = {
        autocrlf = "input";
        compression = 9;
        packedGitLimit = "512m";
        packedGitWindowSize = "512m";
        quotePath = false;
        editor = "code --wait";
      };

      commit.gpgsign = true;
      tag.gpgsign = true;

      "gpg.ssh" = {
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

      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };
      };

      gc = {
        auto = 6700;
        autopacklimit = 50;
        autodetach = true;
        pruneexpire = "2 weeks ago";
      };

      credential = {
        helper =
          if pkgs.stdenv.isDarwin
          then "osxkeychain"
          else "${pkgs.gitFull}/bin/git-credential-libsecret";
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
      "npm-debug.log*"
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
      "*_templ.go" ## https://templ.guide/
      "*.sql.go" ## https://sqlc.dev

      # AI tools
      ".crush"
    ];
  };

  # SSH allowed signers — lets git verify SSH signatures
  home.file.".ssh/allowed_signers".source = ./git-allowed-signers;
}
