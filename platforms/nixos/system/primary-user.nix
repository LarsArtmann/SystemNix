{ lib, ... }: {
  options.users.primaryUser = lib.mkOption {
    type = lib.types.str;
    default = "lars";
    description = "Primary user account for the system (used by service modules for file ownership, home dir, etc.)";
  };
}
