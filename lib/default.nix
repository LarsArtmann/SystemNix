lib: let
  harden = import ./systemd.nix {inherit lib;};
  inherit (import ./systemd/service-defaults.nix lib) serviceDefaults serviceDefaultsUser onFailure;
in {
  inherit harden;
  hardenUser = args: harden (args // {mode = "user";});
  inherit serviceDefaults serviceDefaultsUser onFailure;
  serviceTypes = import ./types.nix lib;
  mkDockerServiceFactory = {pkgs}: import ./docker.nix {inherit pkgs lib harden serviceDefaults;};

  mkStateDir = path: mode: user: group: "d ${path} ${mode} ${user} ${group} -";

  mkHttpCheck = {
    name,
    group,
    url,
    interval ? "30s",
    conditions ? ["[STATUS] == 200"],
    alerts ? [],
  }: {
    inherit name group url interval conditions alerts;
  };

  ports = let
    raw = (import ./ports.nix).ports;
    values = builtins.attrValues raw;
    deduped = map (x: x.key) (builtins.genericClosure {
      startSet = map (v: {key = v;}) values;
      operator = _: [];
    });
  in
    assert builtins.length values == builtins.length deduped; raw;
}
