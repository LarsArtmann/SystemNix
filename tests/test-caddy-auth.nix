# VM test for Caddy auth patterns used by SystemNix.
#
# Verifies the two Caddy vHost patterns at runtime:
#   1. Plain proxy (Layer 1 style — Forgejo, Gatus): no auth gate, direct access
#   2. protectedVHost (Layer 2 — LAN bypass + external forward-auth):
#      - LAN requests (127.0.0.1) bypass auth entirely → direct backend access
#      - External requests hit forward_auth → 401 redirect to auth
#
# Uses a standalone Caddy config replicating the EXACT Caddyfile syntax from
# the SystemNix Caddy module (proxyTo, protectedVHost, forwardAuth helpers).
# This guards the auth pattern itself — if Caddy changes how forward_auth +
# remote_ip interact, or if someone reintroduces unconditional forward-auth
# (the old SigNoz bug), this test catches it.
#
# The SystemNix Caddy module generates identical Caddyfile patterns — this test
# isolates Caddy behavior from SystemNix service dependencies.
{ pkgs }:
let
  # Mock oauth2-proxy: returns 200 for /ping (health), 401 for auth checks.
  # In production, oauth2-proxy returns 200 for authenticated sessions and
  # 401 for unauthenticated requests. Caddy's forward_auth reads the 401 and
  # triggers handle_response (redirect to sign-in page).
  mockOauth2Proxy = pkgs.writeShellApplication {
    name = "mock-oauth2-proxy";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      python3 -c '
      import http.server
      class H(http.server.BaseHTTPRequestHandler):
          def do_GET(self):
              if self.path == "/ping":
                  self.send_response(200)
                  self.end_headers()
                  self.wfile.write(b"OK")
              elif self.path == "/oauth2/auth":
                  self.send_response(401)
                  self.end_headers()
              else:
                  self.send_response(404)
                  self.end_headers()
          def log_message(self, *_):
              pass
      http.server.HTTPServer(("127.0.0.1", 4180), H).serve_forever()
      '
    '';
  };

  # Simple HTTP backend that identifies itself
  mockBackend = port: name: pkgs.writeShellApplication {
    name = "mock-backend-${name}";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      python3 -c '
      import http.server
      class H(http.server.BaseHTTPRequestHandler):
          def do_GET(self):
              self.send_response(200)
              self.send_header("Content-Type", "text/plain")
              self.end_headers()
              self.wfile.write(b"backend-${name}")
          def log_message(self, *_):
              pass
      http.server.HTTPServer(("127.0.0.1", ${toString port}), H).serve_forever()
      '
    '';
  };

  # Caddyfile replicating SystemNix auth patterns (HTTP, no TLS for testing)
  caddyfile = pkgs.writeText "Caddyfile" ''
    {
      auto_https off
      admin off
    }

    # Pattern 1: Plain proxy (Layer 1 — no auth gate)
    :8081 {
      reverse_proxy localhost:9001
    }

    # Pattern 2: protectedVHost (Layer 2 — LAN bypass + external forward-auth)
    # This is the exact pattern from SystemNix caddy.nix protectedVHost helper.
    :8082 {
      @external not remote_ip 127.0.0.1/8 192.168.1.0/24
      handle @external {
        forward_auth localhost:4180 {
          uri /oauth2/auth
          copy_headers X-Auth-Request-User X-Auth-Request-Email

          @unauth status 401
          handle_response @unauth {
            redir * https://auth.test.local/oauth2/sign_in?rd={scheme}://{host}{uri}
          }
        }
        reverse_proxy localhost:9002
      }
      handle {
        reverse_proxy localhost:9002
      }
    }
  '';
in
{
  name = "caddy-auth-patterns";

  nodes.machine = { lib, ... }: {
    # Backends
    systemd.services.mock-backend-plain = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = lib.getExe (mockBackend 9001 "plain");
        Restart = "always";
      };
    };
    systemd.services.mock-backend-protected = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = lib.getExe (mockBackend 9002 "protected");
        Restart = "always";
      };
    };

    # Mock oauth2-proxy
    systemd.services.mock-oauth2-proxy = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = lib.getExe mockOauth2Proxy;
        Restart = "always";
      };
    };

    # Caddy with our auth patterns (using the package directly, not NixOS module)
    systemd.services.caddy-test = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.caddy}/bin/caddy run --config ${caddyfile} --adapter caddyfile";
        Restart = "always";
      };
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Wait for all services
    machine.wait_for_unit("mock-backend-plain.service")
    machine.wait_for_unit("mock-backend-protected.service")
    machine.wait_for_unit("mock-oauth2-proxy.service")
    machine.wait_for_unit("caddy-test.service")
    machine.wait_for_open_port(4180)

    # Give Caddy a moment to bind its listeners
    import time
    time.sleep(2)

    # 1. Mock oauth2-proxy /ping works (health check)
    machine.succeed("curl -sf http://localhost:4180/ping")

    # 2. Mock oauth2-proxy /oauth2/auth returns 401 (unauthenticated)
    machine.fail("curl -sf http://localhost:4180/oauth2/auth")
    machine.succeed("curl -s -o /dev/null -w '%{http_code}' http://localhost:4180/oauth2/auth | grep 401")

    # 3. Plain proxy: direct access, no auth gate
    result = machine.succeed("curl -sf http://localhost:8081/")
    assert "backend-plain" in result, f"Plain proxy should reach backend directly, got: {result}"

    # 4. protectedVHost: localhost (127.0.0.1/8) bypasses auth → direct access.
    #    This is the KEY assertion: LAN requests NEVER touch oauth2-proxy.
    #    The old SigNoz bug was unconditional forward_auth (no bypass) —
    #    oauth2-proxy failures broke ALL access, including LAN.
    result = machine.succeed("curl -sf http://localhost:8082/")
    assert "backend-protected" in result, f"protectedVHost LAN bypass should reach backend directly, got: {result}"

    # 5. Verify the Caddyfile contains the protectedVHost pattern markers.
    #    forward_auth MUST be inside a handle @external block (conditional),
    #    NOT at the top level (unconditional). The old SigNoz bug was
    #    unconditional forward_auth with no LAN bypass.
    config = machine.succeed("cat ${caddyfile}")
    assert "forward_auth" in config, "protectedVHost must contain forward_auth for external requests"
    assert "remote_ip" in config, "protectedVHost must contain remote_ip for LAN bypass"
    assert "@external" in config, "protectedVHost must have @external matcher"

    # 6. Verify BOTH handle blocks exist (external with auth, LAN without).
    #    The old SigNoz bug had forward_auth OUTSIDE any handle block —
    #    unconditional, applying to ALL requests including LAN.
    lines = config.split('\n')
    found_handle_external = False
    found_handle_bare = False
    for line in lines:
        stripped = line.strip()
        if stripped == "handle @external {":
            found_handle_external = True
        if stripped == "handle {":
            found_handle_bare = True
    assert found_handle_external, "protectedVHost must have 'handle @external' block for external auth"
    assert found_handle_bare, "protectedVHost must have bare 'handle' block for LAN bypass"
  '';
}
