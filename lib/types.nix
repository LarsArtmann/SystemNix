lib:
let
  inherit (lib) mkOption types;

  # Pocket ID OIDC client registration — shared by
  # services.pocket-id-config.provision.{oidcClients,extraOidcClients} and
  # services.integration.<name>.oidc so service modules can register their
  # own clients without editing pocket-id.nix's default list. Lives in the
  # let so the list-shaped option below can reference it lexically.
  oidcClientType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Display name for the OIDC client";
      };
      clientId = mkOption {
        type = types.str;
        description = "Client ID (must be unique)";
      };
      callbackURLs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Allowed callback URLs";
      };
      logoutCallbackURLs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Allowed logout callback URLs";
      };
      launchURL = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Launch URL shown in Pocket ID UI (clicking the app redirects here)";
      };
      pkceEnabled = mkOption {
        type = types.bool;
        default = false;
        description = "Whether PKCE is enabled for this client";
      };
      isPublic = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this is a public client (no client secret)";
      };
      requiresReauthentication = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to force passkey re-authentication on each login";
      };
      logoFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to logo image for the client (PNG or SVG)";
      };
    };
  };
in
{
  systemdServiceIdentity =
    {
      defaultUser,
      defaultGroup ? defaultUser,
      defaultStateDir ? "/var/lib/${defaultUser}",
    }:
    {
      user = mkOption {
        type = types.str;
        default = defaultUser;
        description = "User account for the service";
      };
      group = mkOption {
        type = types.str;
        default = defaultGroup;
        description = "Group for the service";
      };
      stateDir = mkOption {
        type = types.str;
        default = defaultStateDir;
        description = "State directory for the service";
      };
    };

  servicePort =
    default: description:
    mkOption {
      type = types.port;
      inherit default description;
    };

  restartDelay =
    default:
    mkOption {
      type = types.str;
      inherit default;
      description = "Delay before restarting after failure";
    };

  stopTimeout =
    default:
    mkOption {
      type = types.str;
      inherit default;
      description = "Timeout for graceful shutdown";
    };

  dockerImageTag =
    default:
    mkOption {
      type = types.str // {
        check = x: types.str.check x && x != "latest";
        description = types.str.description + " (must not be 'latest')";
      };
      inherit default;
      description = "Pinned Docker image tag (must not be 'latest')";
    };

  # List-of-clients option built from oidcClientType. Options compose via
  # `//` (e.g. pocket-id overrides the default list) — the raw type is
  # exported separately for single-client options (services.integration).
  oidcClients = mkOption {
    type = types.listOf oidcClientType;
    default = [ ];
    description = "Pocket ID OIDC client registrations";
  };

  # Raw single-client type for options like services.integration.<name>.oidc.
  inherit oidcClientType;
}
