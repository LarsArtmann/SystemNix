# Eval-time assertion: OTel exporter endpoint env vars must match the parsing
# contract of the consuming SDK. The format is language/protocol-specific and a
# wrong shape is NOT caught by `nix eval` — it validates string rendering, not
# API contract correctness:
#
#   - Go otlptracehttp:      localhost:4318        (bare host:port, NO scheme —
#                            the SDK builds the URL itself; a scheme produces
#                            http://http:%2F%2Flocalhost:4318/v1/traces)
#   - Go otlptracegrpc:      http://127.0.0.1:4317 (WITH scheme — upstream
#                            normalizes it; URL parsers need the scheme)
#   - Rust tonic (gRPC):     http://localhost:4317 (WITH scheme)
#   - Python / Node SDKs:    http://localhost:4318 (WITH scheme)
#   - Docker containers:     http://host.docker.internal:4318
#
# Bug class history: browser-history hung at startup with
#   parse "127.0.0.1:4317": first path segment in URL cannot contain colon
# because a schemeless gRPC endpoint was passed where a URL parser runs
# (2026-08-14 outage, 20-35 report §b.1). The generic rule below catches that
# class for ANY service: gRPC-port endpoints REQUIRE the http:// scheme.
#
# Scans systemd.services.<name>.environment, .serviceConfig.Environment, and
# virtualisation.oci-containers.containers.<name>.environment. Env vars baked
# into generated docker-compose files (e.g. manifest) are NOT visible here —
# register those services in `expectations` only when they become scannable.
_: {
  flake.nixosModules.otel-endpoint-audit =
    {
      config,
      options,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) ports;

      cfg = config.services.otel-endpoint-audit;

      grpcPort = toString ports.signoz-otlp-grpc;
      httpPort = toString ports.signoz-otlp-http;
      allowedHosts = [
        "localhost"
        "127.0.0.1"
        "host.docker.internal"
      ];

      isOtelEndpointVar =
        name: builtins.match "OTEL_EXPORTER_OTLP(_TRACES|_METRICS|_LOGS)?_ENDPOINT" name != null;

      # systemd.services.<name>.environment is attrsOf (either str (listOf str)).
      envAttrEntries =
        env:
        lib.mapAttrsToList (k: v: {
          name = k;
          value =
            if builtins.isString v then v else builtins.concatStringsSep " " (map toString (lib.toList v));
        }) (lib.filterAttrs (n: _: isOtelEndpointVar n) env);

      # serviceConfig.Environment is nullOr (either str (listOf "K=V")).
      serviceConfigEntries =
        scEnv:
        let
          entries =
            if scEnv == null then
              [ ]
            else if builtins.isString scEnv then
              [ scEnv ]
            else if builtins.isList scEnv then
              lib.filter builtins.isString scEnv
            else
              [ ];
          parsed = map (e: builtins.match "([^=]+)=(.*)" e) entries;
          kept = lib.filter (p: p != null && isOtelEndpointVar (builtins.head p)) parsed;
        in
        map (p: {
          name = builtins.elemAt p 0;
          value = builtins.elemAt p 1;
        }) kept;

      # Validate one endpoint value. Returns a list of error strings (empty = ok).
      validate =
        context: varName: value: expectation:
        let
          prefix = "${context}: ${varName}=\"${value}\"";
          schemeMatch = builtins.match "^([a-zA-Z][a-zA-Z0-9+.-]*)://(.*)$" value;
          scheme = if schemeMatch == null then null else builtins.elemAt schemeMatch 0;
          rest = if schemeMatch == null then value else builtins.elemAt schemeMatch 1;
          hostPort = lib.splitString ":" rest;
          host = if builtins.length hostPort == 2 then builtins.head hostPort else null;
          port = if builtins.length hostPort == 2 then builtins.elemAt hostPort 1 else null;
          shapeOk = host != null && port != null && builtins.match "[0-9]+" port != null;

          genericErrors =
            (
              if scheme != null && scheme != "http" then
                [
                  "${prefix}: scheme \"${scheme}://\" is not supported — the SigNoz OTLP receiver is plaintext localhost. Use \"http://\" or no scheme."
                ]
              else
                [ ]
            )
            ++ (
              if !shapeOk then
                [
                  "${prefix}: expected host:port or http://host:port with a numeric port (no path, no IPv6 brackets)."
                ]
              else
                [ ]
            )
            ++ (lib.optionals shapeOk (
              if !(builtins.elem host allowedHosts) then
                [
                  "${prefix}: host \"${host}\" is not in the allowlist (${lib.concatStringsSep ", " allowedHosts}) — traces must not leave this machine."
                ]
              else if port != grpcPort && port != httpPort then
                [
                  "${prefix}: port ${port} is not a SigNoz OTLP receiver port (gRPC ${grpcPort} / HTTP ${httpPort} from lib/ports.nix)."
                ]
              else if port == grpcPort && scheme == null then
                [
                  "${prefix}: gRPC OTLP endpoint (port ${grpcPort}) REQUIRES the http:// scheme. Go otlptracegrpc and Rust tonic parse the value as a URL — a schemeless value hangs startup with: parse \"${rest}\": first path segment in URL cannot contain colon. (browser-history incident, 2026-08-14)"
                ]
              else
                [ ]
            ));

          expectationErrors =
            if expectation == null || !shapeOk then
              [ ] # unregistered service: generic rules only; malformed shape already reported
            else
              let
                schemeProblems =
                  if expectation == "http-host-port" then
                    (
                      if scheme != null then
                        [
                          "${prefix}: Go otlptracehttp expects bare host:port WITHOUT scheme (expectation \"http-host-port\") — the SDK constructs the URL itself; a scheme yields http://http:%2F%2F${rest}/v1/traces."
                        ]
                      else
                        [ ]
                    )
                  else
                    (
                      if scheme != "http" then
                        [
                          "${prefix}: expectation \"${expectation}\" requires the http:// scheme — this SDK parses the value as a URL."
                        ]
                      else
                        [ ]
                    );
                expectedPort = if expectation == "grpc-url" then grpcPort else httpPort;
                portProblems =
                  if port != expectedPort then
                    [
                      "${prefix}: expectation \"${expectation}\" requires port ${expectedPort}, got ${port}."
                    ]
                  else
                    [ ];
              in
              schemeProblems ++ portProblems;
        in
        genericErrors ++ expectationErrors;

      serviceViolations = lib.concatMap (
        svcName:
        let
          svc = config.systemd.services.${svcName};
          entries =
            envAttrEntries svc.environment ++ serviceConfigEntries (svc.serviceConfig.Environment or null);
        in
        lib.concatMap (
          entry:
          let
            errors = validate "systemd service \"${svcName}\"" entry.name entry.value (
              cfg.expectations.${svcName} or null
            );
          in
          lib.optional (errors != [ ]) {
            context = "systemd service \"${svcName}\"";
            inherit errors;
          }
        ) entries
      ) (builtins.attrNames config.systemd.services);

      # oci-containers env (attrsOf (either str (listOf str))). The option is
      # part of base NixOS but guard anyway for exotic minimal evals.
      containerViolations =
        let
          containersResult = builtins.tryEval (
            if options ? virtualisation.oci-containers then
              config.virtualisation.oci-containers.containers
            else
              { }
          );
          containers = if containersResult.success then containersResult.value else { };
        in
        lib.concatMap (
          ctrName:
          let
            entries = envAttrEntries (
              config.virtualisation.oci-containers.containers.${ctrName}.environment or { }
            );
          in
          lib.concatMap (
            entry:
            let
              errors = validate "container \"${ctrName}\"" entry.name entry.value (
                cfg.expectations.${ctrName} or null
              );
            in
            lib.optional (errors != [ ]) {
              context = "container \"${ctrName}\"";
              inherit errors;
            }
          ) entries
        ) (builtins.attrNames containers);

      allViolations = serviceViolations ++ containerViolations;
    in
    {
      options.services.otel-endpoint-audit = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Eval-time validation of OTel exporter endpoint env vars
            (OTEL_EXPORTER_OTLP*_ENDPOINT) across all systemd services and
            OCI containers. Catches wrong-scheme / wrong-port / remote-host
            endpoints at `nix flake check` time instead of as runtime
            startup hangs or silently dropped traces.
          '';
        };

        expectations = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.enum [
              "grpc-url"
              "http-url"
              "http-host-port"
            ]
          );
          default = {
            # gRPC (port 4317), scheme REQUIRED
            browser-history = "grpc-url"; # Go otlptracegrpc (upstream v0.5.0+ normalizes)
            monitor365-server = "grpc-url"; # Rust tonic
            # OTLP HTTP (port 4318) via URL-parsing SDKs, scheme REQUIRED
            hermes = "http-url"; # Python opentelemetry-sdk
            # OTLP HTTP (port 4318), Go otlptracehttp — bare host:port, NO scheme
            discordsync = "http-host-port";
            crush-daily = "http-host-port";
            overview = "http-host-port";
            projects-management-automation = "http-host-port";
            file-and-image-renamer = "http-host-port";
            file-and-image-renamer-health = "http-host-port";
            papdashboard = "http-host-port";
            cv-server = "http-host-port";
            bank-sync = "http-host-port";
            gotenberg = "http-url"; # upstream autoexport parses a full URL
          };
          description = ''
            Per-service OTLP endpoint shape contract. Register EVERY service
            that sets OTEL_EXPORTER_OTLP_ENDPOINT so its scheme-ness is
            enforced (unregistered services get generic rules only):

            - "grpc-url":        http://host:4317 — Go otlptracegrpc and Rust
                                 tonic (both parse the value as a URL)
            - "http-url":        http://host:4318 — Python / Node / Docker SDKs
                                 (read the env var as a full URL)
            - "http-host-port":  host:4318 — Go otlptracehttp (the SDK builds
                                 the URL itself; a scheme corrupts it)
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = map (violation: {
          assertion = false;
          message = ''
            otel-endpoint-audit: ${violation.context} violates the OTel endpoint contract:
            ${lib.concatStringsSep "\n" (map (e: "  - ${e}") violation.errors)}

            Convention (AGENTS.md "For OTLP tracing"): Go http = host:4318 (no
            scheme), Go/Rust gRPC = http://host:4317, Python = http://host:4318,
            Docker = http://host.docker.internal:4318.
          '';
        }) allViolations;
      };
    };
}
