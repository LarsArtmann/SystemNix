{lib}: {
  name,
  description,
  after ? [],
  partOf ? [],
  environment ? {},
  serviceConfig ? {},
  wantedBy ? ["graphical-session.target"],
  ...
}: {
  Unit = {
    Description = description;
    After = after ++ ["graphical-session.target"];
    PartOf = partOf ++ ["graphical-session.target"];
  };
  Service = lib.mkMerge [
    {
      Environment = lib.mapAttrsToList (k: v: "${k}=${v}") environment;
    }
    serviceConfig
  ];
  Install = {inherit wantedBy;};
}
