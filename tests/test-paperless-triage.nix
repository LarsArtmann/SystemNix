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

  # Option-only mock (fastflowlmOptionsMock pattern from test-paperless-gpt):
  # paperless.nix reads config.services.fastflowlm.model for its native-AI
  # env wiring — no flm units run in this VM.
  fastflowlmOptionsMock = { lib, ... }: {
    options.services.fastflowlm = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      model = lib.mkOption {
        type = lib.types.str;
        default = "vm-mock-model";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 52625;
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
            # Classify on the DOCUMENT EXCERPT only: decode the JSON first
            # (the wire body has escaped newlines), then take what sits
            # between the sweep's --- markers — the surrounding prompt
            # template itself contains "receipt"/"VAT" and would YES every
            # request if matched against the whole content.
            try:
                content = json.loads(body)["messages"][-1]["content"]
            except Exception:
                content = ""
            m = re.search(r"---\n(.*)\n---", content, re.S)
            excerpt = m.group(1) if m else ""
            yes = bool(re.search(r"faktura|receipt|brutto|vat", excerpt, re.I))
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
        fastflowlmOptionsMock
        pocketIdOptionsMock
        mailRelayOptionsMock
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      virtualisation.memorySize = 4096;

      environment.systemPackages = [ pkgs.jq ];

      sops.secrets.paperless_admin_password = { };

      services.llama-chat.enable = true;
      # The HOST's IO storms bleed into the guest's /proc/pressure/io via
      # virtiofs (avg10 can exceed 100% on multicore) and the gate has its
      # own selftest check elsewhere — this test exercises the sweep logic,
      # not the gate. Effectively-unbounded band, test-scoped.
      systemd.services.paperless-triage.environment.PSI_MAX = lib.mkForce "100000";
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
    import json

    machine.start()

    # 1. Paperless first (PG migrations + superuser bootstrap), then the
    #    mock verdict endpoint + the provisioner. The token unit has no
    #    wantedBy (paperless-gpt-token pattern): it is pulled by the SWEEP's
    #    requires= when the timer fires or the test starts the service.
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("paperless-scheduler.service")
    machine.wait_for_unit("paperless-web.service")
    machine.wait_for_unit("mock-llama-chat.service")
    machine.wait_for_unit("paperless-triage.timer")

    # Diagnostic: the shared textfile dir must be 1777 (the sweep mktemps
    # its .prom there).
    machine.succeed("stat -c '%a' /var/lib/prometheus-node-exporter/textfile_collectors | grep 1777")

    # 3. The sweep script's margin parser passes its fixtures.
    sweep = machine.succeed(
      "grep -h -oP '^ExecStart=\\K\\S+' /etc/systemd/system/paperless-triage.service"
    ).strip()
    machine.succeed(f"{sweep} --selftest")

    # 4. Declarative entities: ensureTags ran before views (the needs-review
    #    tag and its saved view both exist after the provisioner). The unit
    #    is boot-triggered with a 60s preStart budget; under a loaded HOST
    #    the VM's Django first response can exceed it (boot flake class),
    #    so converge it explicitly once the login page genuinely serves —
    #    the same action deploy.sh performs.
    machine.wait_until_succeeds(
      "curl -sf -o /dev/null http://127.0.0.1:2892/accounts/login/", timeout=300
    )
    machine.succeed("systemctl restart paperless-dashboard-provision.service")
    machine.wait_for_unit("paperless-dashboard-provision.service")
    token = machine.succeed(
      "runuser -u paperless -- /run/current-system/sw/bin/paperless-manage drf_create_token admin | grep -oE '[0-9a-f]{40}'"
    ).strip()

    def api(path):
      return machine.succeed(
        f"curl -sf -H 'Authorization: Token {token}' 'http://127.0.0.1:2892{path}'"
      )

    def tag_id_by_name(name):
        # paperless 3.3.1: ?name= is not a server-side filter (declared
        # lookups are name__iexact etc.), so an unmatched param silently
        # returns ALL tags — exact-match client-side.
        out = json.loads(api("/api/tags/?page_size=100000"))
        ids = [t["id"] for t in out["results"] if t["name"] == name]
        assert len(ids) == 1, f"tag {name!r} not uniquely present: {out}"
        return ids[0]

    review_id = tag_id_by_name("needs-review")
    views = json.loads(api("/api/saved_views/?page_size=100"))
    view_names = [v["name"] for v in views["results"]]
    assert "Needs Review (triage)" in view_names, f"saved view missing: {view_names}"

    # 5. Consume one Faktura (should PASS -> paperless-gpt-auto) and one
    #    letter (should land below threshold -> needs-review).
    machine.succeed(
      "printf 'Faktura VAT Nr FA/2026/10/27 Data wystawienia: 2026-10-27 Brutto: 86,84 PLN VAT 23%%' > /tmp/faktura.txt"
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

    # 6. Run the sweep synchronously (systemctl start blocks a oneshot;
    #    requires= pulls the token mint first — assert its artifacts now).
    machine.succeed("systemctl start paperless-triage.service")
    machine.succeed("stat -c '%a %U %G' /run/paperless-triage/env | grep '400 paperless-triage paperless-triage'")

    def tags_of(doc_id):
      out = machine.succeed(
        f"curl -sf -H 'Authorization: Token {token}' http://127.0.0.1:2892/api/documents/{doc_id}/"
      )
      return json.loads(out)["tags"]

    pass_tag = tag_id_by_name("paperless-gpt-auto")

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
