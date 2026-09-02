# VM test for the central mail relay (Postfix null client).
#
# Locks down the null-client contract end-to-end:
#   1. postfix starts and answers SMTP on 127.0.0.1:25 ONLY (loopback-only,
#      never a LAN-reachable relay)
#   2. Config is the null client: empty mydestination (nothing delivered
#      locally), forced-TLS authenticated relayhost, sops-rendered SASL map,
#      sender generic map + RECIPIENT canonical map (aliases(5) is inert on a
#      null client — local(8) never runs — so root@/postmaster@ system mail
#      needs recipient canonicalization to become routable)
#   3. E2E queue phase: a sendmail submission from root is QUEUED with the
#      recipient already rewritten (canonical maps apply at cleanup, BEFORE
#      queuing); relayHost points at a connection-refused address so the
#      message defers deterministically without any network dependency
#   4. The mail-relay-metrics collector reports the real queue depth, flags
#      the PLACEHOLDER credential fail-closed, and reports zero scrape errors
#   5. E2E delivery phase against a FAKE upstream SMTP server captured in-VM:
#      proves the smtp client rewrites the envelope sender (generic maps are
#      delivery-time, invisible in the queue), authenticates from the
#      rendered SASL map, and relays the canonicalized recipient
{ pkgs }:
let
  mailRelayModule =
    ((import ../modules/nixos/services/mail-relay.nix) { }).flake.nixosModules.mail-relay;

  # Deterministic offline upstream: connection refused = 4xx defer, so the
  # test message stays queued (a real provider would 5xx-bounce the
  # placeholder-auth attempt, emptying the queue and flaking the assertion
  # on internet-connected build hosts).
  relayHost = "127.0.0.2";
  relayPort = 1;
in
{
  name = "mail-relay";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        mailRelayModule
        ./mock-sops.nix
      ];

      # The module interpolates hostName/domain into myorigin and the
      # sender/recipient maps — give it the production SHAPE (FQDN host).
      networking.hostName = "testhost";
      networking.domain = "home.lan";

      services.mail-relay = {
        enable = true;
        inherit relayHost relayPort;
      };

      # mock-sops provides the options and renders secrets, but NOT
      # templates — create the rendered SASL map exactly as sops-nix would
      # (postfix-owned 0400, the smtp client daemon reads it as mail_owner).
      sops.templates."mail-relay-sasl".content =
        "[${relayHost}]:${toString relayPort} resend:PLACEHOLDER";
      systemd.tmpfiles.rules = [
        "f /run/secrets-rendered/mail-relay-sasl 0400 postfix postfix -"
      ];

      environment.systemPackages = [
        pkgs.iproute2
        pkgs.netcat
        pkgs.jq
        pkgs.python3
      ];

      # Fake upstream for the delivery-time E2E: smtp_generic_maps and the
      # SASL handshake happen in the smtp CLIENT at DELIVERY, invisible in
      # the deferred queue record — this captures the actual conversation.
      environment.etc."fake-relay/fake-relay.py".text = ''
        import socket
        s = socket.socket()
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("127.0.0.2", ${toString relayPort}))
        s.listen(1)
        c, _ = s.accept()
        f = c.makefile("rwb", 0)
        log = []
        def send(x):
            f.write((x + "\r\n").encode())
        send("220 fake.relay ESMTP")
        while True:
            line = f.readline().decode().strip()
            if not line:
                break
            log.append(line)
            u = line.upper()
            if u.startswith("EHLO") or u.startswith("HELO"):
                send("250-fake.relay")
                send("250 AUTH PLAIN LOGIN")
            elif u.startswith("AUTH"):
                send("235 ok")
            elif u.startswith(("MAIL", "RCPT")):
                send("250 ok")
            elif u == "DATA":
                send("354 go")
            elif u == ".":
                send("250 accepted")
                break
            elif u.startswith("QUIT"):
                break
            else:
                send("250 ok")
        c.close()
        with open("/tmp/fake-relay-capture.txt", "w") as out:
            out.write("\n".join(log))
      '';
    };

  testScript = ''
    import json

    start_all()

    machine.wait_for_unit("postfix.service")
    machine.wait_for_open_port(25)

    # 1. Loopback-only listener: the relay accepts submissions from local
    #    services, never from the network.
    ss = machine.succeed("ss -tln")
    assert "127.0.0.1:25" in ss, f"loopback :25 not listening:\n{ss}"
    assert "0.0.0.0:25" not in ss, f":25 listening on all interfaces:\n{ss}"
    assert "[::]:25" not in ss, f":25 listening on IPv6 any:\n{ss}"

    # SMTP banner proves a live smtpd, not just an open socket. Send NOTHING
    # first — postfix rejects pre-greeting input as a pipelining violation
    # ("554 5.5.0 SMTP protocol synchronization"); just connect and read the
    # greeting (head exits after line 1, timeout bounds the idle nc).
    banner = machine.succeed("timeout 5 nc 127.0.0.1 25 </dev/null | head -1")
    assert banner.startswith("220"), f"no SMTP greeting: {banner}"

    # 2. Null-client config via the LIVE /etc/postfix/main.cf (symlinked to
    #    /var/lib/postfix/conf by postfix-setup).
    def postconf(key):
        return machine.succeed(f"postconf -h {key}").strip()

    assert postconf("mydestination") == "", (
        f"mydestination must be empty on a null client, got: {postconf('mydestination')}"
    )
    assert postconf("relayhost") == "[${relayHost}]:${toString relayPort}", (
        f"unexpected relayhost: {postconf('relayhost')}"
    )
    assert postconf("smtp_tls_security_level") == "encrypt", (
        f"TLS not mandatory: {postconf('smtp_tls_security_level')}"
    )
    assert "mail-relay-sasl" in postconf("smtp_sasl_password_maps"), (
        f"SASL map not wired: {postconf('smtp_sasl_password_maps')}"
    )
    assert "postfix-generic-map" in postconf("smtp_generic_maps"), (
        f"sender generic map not wired: {postconf('smtp_generic_maps')}"
    )
    assert "postfix-canonical-recipient" in postconf("recipient_canonical_maps"), (
        f"recipient canonical map not wired: {postconf('recipient_canonical_maps')}"
    )

    # 3. E2E submission from root: the recipient canonical map runs at
    #    CLEANUP, so the queued message must ALREADY carry the rewritten
    #    recipient. The envelope sender is NOT yet rewritten in the queue
    #    record — smtp_generic_maps applies in the smtp CLIENT at delivery
    #    (step 4). Because the upstream refuses connections, the message
    #    defers (stays queued) instead of bouncing.
    machine.succeed(
        "printf 'Subject: vm relay test\\n\\nbody\\n' | sendmail root@testhost.home.lan"
    )
    machine.wait_until_succeeds("postqueue -j | grep -q noreply@larsartmann.cloud", timeout=60)
    # postqueue -j is JSON Lines — wrap into an array with jq -s.
    entries = json.loads(machine.succeed("postqueue -j | jq -s '.'"))
    assert len(entries) == 1, f"expected exactly 1 queued message, got {len(entries)}"
    rcpt = entries[0]["recipients"][0]["address"]
    assert rcpt == "noreply@larsartmann.cloud", f"recipient not rewritten: {rcpt}"

    # 4. Collector: real queue depth, placeholder flagged fail-closed,
    #    scrape clean (asserted BEFORE the fake-relay delivery adds a second
    #    message to the queue).
    machine.succeed("systemctl restart mail-relay-metrics.service")
    prom = machine.succeed(
        "cat /var/lib/prometheus-node-exporter/textfile_collectors/mail-relay.prom"
    )
    assert "mail_relay_queue_messages 1" in prom, f"queue depth wrong:\n{prom}"
    assert "mail_relay_queue_over_threshold 0" in prom, f"threshold flapped:\n{prom}"
    assert "mail_relay_credential_placeholder 1" in prom, f"placeholder not flagged:\n{prom}"
    assert "mail_relay_scrape_errors 0" in prom, f"scrape errors:\n{prom}"

    # 5. Delivery-time E2E against a fake upstream: proves the smtp client
    #    rewrote the envelope sender (generic map), authenticated with the
    #    rendered SASL map, and relayed the canonicalized recipient.
    machine.succeed(
        "openssl req -x509 -newkey rsa:2048 -keyout /tmp/fake-relay-key.pem "
        "-out /tmp/fake-relay-cert.pem -days 1 -nodes -subj '/CN=fake.relay'"
    )
    machine.execute("nohup python3 /etc/fake-relay/fake-relay.py >/dev/null 2>&1 &")
    machine.wait_until_succeeds("ss -tln | grep -q '127.0.0.2:1'", timeout=30)
    machine.succeed(
        "printf 'Subject: vm relay delivery\\n\\nbody\\n' | sendmail root@testhost.home.lan"
    )
    machine.wait_until_succeeds("test -s /tmp/fake-relay-capture.txt", timeout=90)
    capture = machine.succeed("cat /tmp/fake-relay-capture.txt")
    assert "MAIL FROM:<noreply@larsartmann.cloud>" in capture, (
        f"envelope sender not rewritten at delivery:\n{capture}"
    )
    assert "RCPT TO:<noreply@larsartmann.cloud>" in capture, (
        f"recipient not relayed canonicalized:\n{capture}"
    )
    assert "AUTH " in capture, f"smtp client did not authenticate upstream:\n{capture}"
  '';
}
