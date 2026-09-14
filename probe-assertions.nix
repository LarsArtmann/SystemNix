let
  f = builtins.getFlake (toString ./.);
  lst = f.nixosConfigurations.evo-x2.config.assertions;
  failed = builtins.filter (a: !a.assertion) lst;
in
{
  total = builtins.length lst;
  failedMessages = map (a: a.message) failed;
}
