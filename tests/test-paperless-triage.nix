# VM test for the paperless-triage confidence gate (decision-triage plan P1,
# 2026-10-27).
#
# Verifies the runtime behavior nix eval CANNOT check:
#   1. paperless-triage-token mints a 0400 env file owned by the triage user
#      (paperless-gpt-token pattern, end-to-end).
#   2. The sweep's margin parser passes its --selftest fixtures.
#   3. END-TO-END verdict routing against a MOCK llama-chat (an in-VM
#      python server speaking the llama.cpp chat-completions + logprobs
#      shape): a Faktura document lands margin >= threshold -> tagged
#      `paperless-gpt-auto` (admitted to extraction); a letter lands below
#      -> tagged `needs-review`. The burn-class guarantee rides on this:
#      admission happens ONLY through a verdict, never by default.
#   4. Declarative entity provisioning: the needs-review tag + the
#      "Needs Review (triage)" saved view exist after the dashboard
#      provisioner runs (ensureTags before views — the ordering fix).
#   5. Metrics + state: the textfile .prom is written with counters, and
#      the watermark advanced past the terminally-decided docs.
#
# The verdict provider is an OPTIONS-ONLY llama-chat mock (enable/port/
# alias — no real model, no real unit): the sweep never starts the real
# llama-chat in this VM, the mock server owns :8850.
{
  pkgs,
}:
let
  paperlessFlakeOutput = (import ../modules/nixos/services/paperless.nix) { };
  paperlessNixosModule = paperlessFlakeOutput.flake.nixosModules.paperless;

  paperlessTriageFlakeOutput = (import ../modules/nixos/services/paperless-triage.nix) { };
  paperlessTriageNixosModule = paperlessTriageFlakeOutput.flake.nixosModules.paperless-triage;

  # Option-only mock (fastflowlmOptionsMock pattern from test-paperless-gpt):
  # declares exactly the leaves the triage module reads. enable=true
  # satisfies the logprobs-endpoint assertion without any real units.
  llamaChatOptionsMock = { lib, ... }: {
    options.services.llama-chat = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8850;
      };
      alias = lib.mkOption {
        type = lib.types.str;
        default = "vm-mock-verdict-model";
      };
    };
  };

  # Mock llama-chat: YES with high margin when the request mentions a
  # Faktura/receipt, NO with high margin otherwise — the exact llama.cpp
  # response shape the margin parser consumes.
  mockVerdictServer = pkgs.writeText "mock-llama-chat.py" ''
    import http.server
    import json
    import re

    def completion(yes: bool):
        top = "YES" if yes else "NO"
        other = "NO" if yes else "YES"
        return {
            "choices": [
                {
                    "message": {"role": "assistant", "content": top},
                    "logprobs": {
                        "content": [
                            {
                                "top_logprobs": [
                                    {"token": top, "logprob": -0.01},
                                    {"token": other, "logprob": -5.0},
                                ]
                            }
                        ]
                    },
                }
            ],
            "usage": {"prompt_tokens": 42},
        }

    class H(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8", "replace")
            yes = bool(re.search(r"faktura|receipt|brutto|vat", body, re.I))
            payload = json.dumps(completion(yes)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, *_):
            pass

    http.server.HTTPServer(("127.0.0.1", 8850), H).serve_forever()
  '';

  # Options-only mocks copied from test-paperless-gpt.nix: the paperless
  # module's registry entry fans into pocket-id-config.provision and reads
  # mail-relay.enable — the option PATHS must exist in this minimal VM.
  pocketIdOptionsMock = { lib, ... }: {
    options.services.pocket-id-config = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      provision.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      provision.extraOidcClients = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
      };
      provision.userGroups = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
      };
      provision.adminUser.username = lib.mkOption {
        type = lib.types.str;
        default = "vm-admin";
      };
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/pocket-id";
      };
    };
  };

  mailRelayOptionsMock = { lib, ... }: {
    options.services.mail-relay = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      fromAddress = lib.mkOption {
        type = lib.types.str;
        default = "noreply@larsartmann.cloud";
      };
    };
  };
in
{
  name = "paperless-triage";

  nodes.machine =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        paperlessNixosModule
        paperlessTriageNixosModule
        # Options-only import: paperless.nix reads
        # config.services.llama-rag.embeddingsAlias (embedding model name).
        (import ../modules/nixos/services/llama-rag.nix { }).flake.nixosModules.llama-rag
        # co-import: the triage module declares a services.integration entry
        # (the options?-guard does not survive mkIf cfg.enable with
        # enable=true — the 2026-09-15 flake-check-proven caveat).
        (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration
        # co-import: unconditional services.catalog entry (ADR-008).
        (import ../modules/nixos/services/catalog.nix { }).flake.nixosModules.catalog
        llamaChatOptionsMock
        pocketIdOptionsMock
        mailRelayOptionsMock
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      virtualisation.memorySize = 4096;

      environment.systemPackages = [ pkgs.jq ];

      sops.secrets.paperless_admin_password = { };

      services.llama-chat.enable = true;
      services.paperless = {
        enable = true;
        dataDir = lib.mkForce "/var/lib/paperless";
        configureTika = lib.mkForce false;
      };
      services.paperless-dashboard.enable = true;
      services.paperless-triage.enable = true;

      # The mock verdict server owns :8850 (the options-only llama-chat mock
      # declares no units).
      systemd.services.mock-llama-chat = {
        description = "Mock llama-chat verdict endpoint (logprobs shape)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.python3}/bin/python3 ${mockVerdictServer}";
        };
      };
    };

  testScript = ''
    import re

    machine.start()

    # 1. Paperless first (PG migrations + superuser bootstrap), then the
    #    token mint, the mock verdict endpoint, the provisioner, the sweep.
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("paperless-scheduler.service")
    machine.wait_for_unit("paperless-web.service")
    machine.wait_for_unit("mock-llama-chat.service")
    machine.wait_for_unit("paperless-triage-token.service")

    # 2. Token mint artifacts: 0400, owned by the triage user.
    machine.succeed("stat -c '%a %U %G' /run/paperless-triage/env | grep '400 paperless-triage paperless-triage'")

    # 3. The sweep script's margin parser passes its fixtures.
    sweep = machine.succeed(
      "grep -h -oP '^ExecStart=\\K\\S+' /etc/systemd/system/paperless-triage.service"
    ).strip()
    machine.succeed(f"{sweep} --selftest")

    # 4. Declarative entities: ensureTags ran before views (the needs-review
    #    tag and its saved view both exist after the provisioner).
    machine.wait_for_unit("paperless-dashboard-provision.service")
    token = machine.succeed(
      "runuser -u paperless -- /run/current-system/sw/bin/paperless-manage drf_create_token admin | grep -oE '[0-9a-f]{40}'"
    ).strip()

    def api(path):
      return machine.succeed(
        f"curl -sf -H 'Authorization: Token {token}' 'http://127.0.0.1:2892{path}'"
      )

    review_tag = json.loads(api("/api/tags/?name=needs-review"))
    assert review_tag["count"] == 1, f"needs-review tag not provisioned: {review_tag}"
    views = json.loads(api("/api/saved_views/?page_size=100"))
    view_names = [v["name"] for v in views["results"]]
    assert "Needs Review (triage)" in view_names, f"saved view missing: {view_names}"

    # 5. Consume one Faktura (should PASS -> paperless-gpt-auto) and one
    #    letter (should land below threshold -> needs-review).
    machine.succeed(
      f"printf 'Faktura VAT Nr FA/2026/10/27 Data wystawienia: 2026-10-27 Brutto: 86,84 PLN VAT 23%%' > /tmp/faktura.txt"
    )
    machine.succeed(
      "printf 'Dear Customer, your subscription will renew automatically next month. Kind regards.' > /tmp/letter.txt"
    )
    machine.succeed(
      f"curl -sf -H 'Authorization: Token {token}' -F 'document=@/tmp/faktura.txt' http://127.0.0.1:2892/api/documents/post_document/"
    )
    machine.succeed(
      f"curl -sf -H 'Authorization: Token {token}' -F 'document=@/tmp/letter.txt' http://127.0.0.1:2892/api/documents/post_document/"
    )

    def doc_by_title(word):
      out = machine.wait_until_succeeds(
        f"curl -sf -H 'Authorization: Token {token}' 'http://127.0.0.1:2892/api/documents/?title__icontains={word}&format=json' | jq -e '.count >= 1' >/dev/null && "
        f"curl -sf -H 'Authorization: Token {token}' 'http://127.0.0.1:2892/api/documents/?title__icontains={word}&format=json'",
        timeout=300,
      )
      docs = json.loads(out)
      return docs["results"][0]

    faktura = doc_by_title("faktura")
    letter = doc_by_title("letter")

    # Content must be populated (consume finished) before triaging.
    machine.wait_until_succeeds(
      f"curl -sf -H 'Authorization: Token {token}' http://127.0.0.1:2892/api/documents/{faktura['id']}/ | jq -e '.content | length > 0'",
      timeout=300,
    )
    machine.wait_until_succeeds(
      f"curl -sf -H 'Authorization: Token {token}' http://127.0.0.1:2892/api/documents/{letter['id']}/ | jq -e '.content | length > 0'",
      timeout=300,
    )

    # 6. Run the sweep synchronously (systemctl start blocks a oneshot).
    machine.succeed("systemctl start paperless-triage.service")

    def tags_of(doc_id):
      out = machine.succeed(
        f"curl -sf -H 'Authorization: Token {token}' http://127.0.0.1:2892/api/documents/{doc_id}/"
      )
      return json.loads(out)["tags"]

    pass_tag = json.loads(api("/api/tags/?name=paperless-gpt-auto"))["results"][0]["id"]
    review_id = review_tag["results"][0]["id"]

    machine.wait_until_succeeds(
      f"test $(curl -sf -H 'Authorization: Token {token}' http://127.0.0.1:2892/api/documents/{faktura['id']}/ | jq '.tags | index({pass_tag}) != null') = true",
      timeout=60,
    )
    letter_tags = tags_of(letter["id"])
    assert review_id in letter_tags, f"letter not routed to review: {letter_tags}"
    assert pass_tag not in letter_tags, f"letter wrongly admitted: {letter_tags}"

    # 7. Metrics + state: the textfile landed with the decision counters.
    prom = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/paperless_triage.prom")
    assert "paperless_triage_decisions_total{verdict=\"pass\"} 1" in prom, prom
    assert "paperless_triage_decisions_total{verdict=\"review\"} 1" in prom, prom
    assert "paperless_triage_refusals_total{reason=\"verdict_down\"} 0" in prom, prom

    state = json.loads(machine.succeed("cat /var/lib/paperless-triage/state.json"))
    assert state["c"]["pass"] == 1 and state["c"]["review"] >= 1, state
    assert state["last_added"], state

    # 8. Sweep idempotence: a second run makes NO new decisions (MRU +
    #    watermark) and the unit stays exit-0 clean.
    machine.succeed("systemctl start paperless-triage.service")
    prom2 = machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/paperless_triage.prom")
    assert "paperless_triage_decisions_total{verdict=\"pass\"} 1" in prom2, prom2
  '';
}
