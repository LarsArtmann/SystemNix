# Pre-commit hooks configuration (Cross-Platform)
# Global default for repos without their own .pre-commit-config.yaml
# Note: SystemNix repo uses its own .pre-commit-config.yaml (root-level)
_: {
  home.file.".config/pre-commit/config.yaml" = {
    text = ''
      repos:
        # Standard formatting and linting hooks
        - repo: https://github.com/pre-commit/pre-commit-hooks
          rev: v6.0.0
          hooks:
            - id: check-added-large-files
              args: ['--maxkb=1000']
            - id: check-case-conflict
            - id: check-executables-have-shebangs
            - id: check-merge-conflict
            - id: check-symlinks
            - id: check-toml
            - id: check-yaml
              args: ['--allow-multiple-documents']
            - id: check-json
            - id: detect-private-key
            - id: end-of-file-fixer
            - id: trailing-whitespace
              args: ['--markdown-linebreak-ext=md']
            - id: mixed-line-ending
              args: ['--fix=lf']

        - repo: https://github.com/nix-community/nixpkgs-fmt
          rev: v1.3.0
          hooks:
            - id: nixpkgs-fmt

        - repo: https://github.com/koalaman/shellcheck-precommit
          rev: v0.9.0
          hooks:
            - id: shellcheck
              args: ['--severity=warning']

        - repo: https://github.com/igorshubovych/markdownlint-cli
          rev: v0.35.0
          hooks:
            - id: markdownlint
              args: ['--fix', '--disable', 'MD013', 'MD033', 'MD041']

      default_stages: [commit]
      fail_fast: false
    '';
  };
}
