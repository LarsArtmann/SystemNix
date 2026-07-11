# Starship Prompt Configuration (Cross-Platform)
# Performance-optimized config migrated from dotfiles/.config/starship.toml
{ colorScheme, ... }:
let
  colors = colorScheme.palette;
in
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;

    settings = {
      # Performance optimization settings
      command_timeout = 400; # 400ms max per command
      scan_timeout = 100; # 100ms max scanning

      # Format: Enhanced prompt with performance budget
      format = "$directory$git_branch$git_status$nix_shell$golang$nodejs$cmd_duration$character";

      # Directory: Minimal path display
      directory = {
        truncation_length = 1;
        truncation_symbol = "";
        truncate_to_repo = false;
        style = "bold #${colors.base0C}";
        read_only = " 🔒";
        format = "[$path]($style) ";
      };

      # Git branch: Fast git operations
      git_branch = {
        symbol = "";
        style = "bold #${colors.base0B}";
        format = "[$symbol$branch]($style) ";
        truncation_length = 10;
        truncation_symbol = "…";
      };

      # Git status: Simplified status with fast checks
      git_status = {
        format = " [$all_status]($style)";
        style = "bold #${colors.base08}";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
        conflicted = "=";
        deleted = "✘";
        renamed = "»";
        modified = "+";
        staged = "+";
        untracked = "?";
        ignore_submodules = true; # Disable slow operations
      };

      # Character: Simple prompt character
      character = {
        success_symbol = "[❯](bold #${colors.base0B})";
        error_symbol = "[❯](bold #${colors.base08})";
        vicmd_symbol = "[❮](bold #${colors.base0A})";
      };

      # Disable ALL unnecessary modules for maximum performance
      aws.disabled = true;
      azure.disabled = true;
      battery.disabled = true;
      buf.disabled = true;
      c.disabled = true;
      cmake.disabled = true;
      cobol.disabled = true;
      conda.disabled = true;
      container.disabled = true;
      crystal.disabled = true;
      daml.disabled = true;
      dart.disabled = true;
      deno.disabled = true;
      docker_context.disabled = true;
      dotnet.disabled = true;
      elixir.disabled = true;
      elm.disabled = true;
      env_var.disabled = true;
      erlang.disabled = true;
      gcloud.disabled = true;
      git_commit.disabled = false;
      git_state.disabled = false;
      golang = {
        disabled = false;
        symbol = "🐹 ";
        style = "bold #${colors.base0C}";
        format = "via [$symbol($version )]($style)";
      };
      haskell.disabled = true;
      helm.disabled = true;
      hostname.disabled = true;
      java.disabled = true;
      julia.disabled = true;
      kotlin.disabled = true;
      kubernetes.disabled = true;
      line_break.disabled = true;
      lua.disabled = true;
      memory_usage.disabled = true;
      nim.disabled = true;
      nix_shell = {
        disabled = false;
        symbol = "❄ ";
        style = "bold #${colors.base0D}";
        format = "via [$symbol$state( \\($name\\))]($style) ";
      };
      nodejs = {
        disabled = false;
        symbol = "⬢ ";
        style = "bold #${colors.base0B}";
        format = "via [$symbol($version )]($style)";
      };
      ocaml.disabled = true;
      openstack.disabled = true;
      package.disabled = false;
      perl.disabled = true;
      php.disabled = true;
      pulumi.disabled = true;
      purescript.disabled = true;
      python.disabled = true;
      red.disabled = true;
      ruby.disabled = true;
      rust.disabled = true;
      scala.disabled = true;
      shell.disabled = false;
      shlvl.disabled = true;
      singularity.disabled = true;
      swift.disabled = true;
      terraform.disabled = true;
      time.disabled = false;
      username.disabled = false;
      vagrant.disabled = true;
      vlang.disabled = true;
      vcsh.disabled = true;
      zig.disabled = true;
      cmd_duration = {
        disabled = false;
        min_time = 2000; # Show duration for commands >2s
        style = "bold #${colors.base0A}";
        format = "took [$duration]($style) ";
      };
    };
  };
}
