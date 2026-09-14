let
  f = builtins.getFlake (toString ./.);
  lst = f.nixosConfigurations.evo-x2.config.assertions;
  ours = builtins.filter (a: a.message != null && builtins.match "systemd-shape-audit:.*" a.message != null) lst;
in
{
  total = builtins.length lst;
  failed = map (a: a.message) (builtins.filter (a: !a.assertion) ours);
}
