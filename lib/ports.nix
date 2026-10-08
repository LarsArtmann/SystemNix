{
  ports = {
    pocket-id = 1411;
    pocket-id-metrics = 9464;
    oauth2-proxy = 4180;
    caddy-metrics = 2019;

    # NetBird mesh VPN client (outbound WireGuard tunnel wt0 — see
    # modules/nixos/services/netbird.nix; control plane on the pbx server)
    netbird = 51820;

    dns-blocker = 53;
    dns-blocker-stats = 9090;
    dns-blocker-block = 8050;

    forgejo = 3000;

    # SMTP submission from local services to the Postfix null-client relay
    # (modules/nixos/services/mail-relay.nix) — loopback only, never exposed.
    mail-relay = 25;

    immich = 2283;
    redis = 6379;

    paperless = 2892;
    tika = 9998;
    gotenberg = 3199;

    monitor365-server = 3001;
    monitor365-metrics = 9191;

    openseo = 3002;

    signoz = 8080;
    signoz-otlp-grpc = 4317;
    signoz-otlp-http = 4318;
    signoz-node-exporter = 9100;
    signoz-collector-metrics = 8888;
    signoz-clickhouse = 9000;
    # ClickHouse HTTP interface (the /ping gatus check and any HTTP client);
    # the native TCP protocol keeps 9000 above.
    signoz-clickhouse-http = 8123;
    signoz-clickhouse-metrics = 9363;
    signoz-clickhouse-keeper = 9181;
    signoz-clickhouse-raft = 9234;

    taskchampion = 10222;

    ollama = 11434;

    gatus = 9110;

    emeet-pixyd = 8090;

    minecraft = 25565;

    crush-daily = 8081;

    bank-sync = 8097;

    overview = 8083;
    pma-health = 9190;

    activitywatch = 5600;

    discordsync-api = 8085;

    # Reserved for the upstream llamaServer unit (services.vision-review-agent).
    # evo-x2 does NOT enable it — the daemon reviews via llama-vlm's captioner
    # endpoint — but the wrapper module still defaults the option to the
    # registered port so a future llamaServer.enable stays registry-correct.
    visionreviewd-llama = 8390;

    file-and-image-renamer-health = 8086;

    browser-history = 8087;

    papdashboard = 8088;

    searxng = 8889;

    attic = 8200;

    # FastFlowLM NPU LLM server (OpenAI-compatible) — socket-activated frontend
    # on 52625, backend on 52626. The proxy unit forwards only when the
    # backend binds, so 52626 is internal.
    fastflowlm = 52625;
    fastflowlm-backend = 52626;

    # Review-only systemd tooling — exposed on LAN for ops review, no auth.
    # systemd-graph serves the live D-Bus-driven dependency graph UI.
    # systemd-timer-monitor is a static HTML report refreshed by a timer
    # (no port needed; served as a static dir by Caddy via the file_server).
    systemd-graph = 8847;

    # llama.cpp RAG servers (ROCm GPU) — embeddings for Paperless AI and
    # broader RAG pipelines. Two separate instances because llama.cpp's
    # --embedding and --reranking modes are mutually exclusive per server
    # instance. RERANKER LEG DROPPED 2026-10-02 (plan A13, consumerless —
    # zero /v1/rerank callers exist); the port stays RESERVED so the
    # dark-guard keeps catching rogues on it and no other service claims it.
    llama-embeddings = 8848;
    llama-reranker = 8849;

    # llama.cpp chat server (ROCm GPU, always-on) — the interactive agent
    # brain for InboxClean's dashboard chat (services.llama-chat). OpenAI-
    # compatible /v1 with native tool calls; distinct from FastFlowLM's
    # socket-activated NPU endpoint (:52625, async workloads only).
    llama-chat = 8850;

    # llama.cpp vision-language servers (CPU, socket-activated) — NSFW-audit
    # captioning/verdict stack (services.llama-vlm). Public socket on 812x,
    # internal backend on 813x (the socat bridge forwards only when the
    # backend binds). NOTE: 8123 is signoz-clickhouse-http — never use 812x
    # for anything ClickHouse-adjacent.
    llama-vlm-e4b = 8127;
    llama-vlm-e4b-backend = 8137;
    llama-vlm-cap = 8128;
    llama-vlm-cap-backend = 8138;

    # Ledger CRM — LarsArtmann's own event-sourced CRM (services.crm-server,
    # modules/nixos/services/crm.nix), loopback-only behind the crm vHost.
    # Same port the pre-module deploy unit and the CV syncer's base_url
    # always used (2026-09-18 standing decision) — the registry entry makes
    # it eval-enforced instead of hardcoded.
    crm = 8091;

    # CV — resume generator + career pipeline server (services.cv-server)
    cv = 8098;

    # InboxClean — Gmail AI assistant web dashboard (services.inboxclean)
    inboxclean = 8099;

    # go-taskqueue — read-only tq serve dashboard (services.tq-agent-pool)
    tq = 8100;

    # Miniflux — self-hosted RSS reader (services.miniflux), loopback-only;
    # Caddy proxies rss.home.lan to it.
    miniflux = 8101;

    # mr-sync — read-only repo-portfolio web dashboard
    # (services.mr-sync-dashboard), loopback-only; Caddy proxies
    # mr-sync.home.lan to it. 7331 is the tool's own default port
    # (mr-sync dashboard).
    mr-sync = 7331;

    # GeoMetrikks — reverse-proxy access-log geo analytics (services.geometrikks),
    # loopback-only; Caddy proxies geo.home.lan to it.
    geometrikks = 8102;

    # health-dashboard — federated go-health hub (services.health-dashboard),
    # loopback-only; Caddy proxies health.home.lan to it. Serves the merged
    # dashboard + kubelet probes; its readiness merges every federated remote.
    health-dashboard = 8103;

    # nsfw-classifier — NSFW image-filter server (services.nsfw-classifier),
    # bound to all interfaces so the browser extension's auto-discovery can
    # reach it at nsfw.home.lan:<port> (nsfw-extension/url-utils.js
    # DEFAULT_SERVER_URLS); the /classify endpoints gate on the pairing
    # token from --pair-token auto.
    nsfw = 8104;

    # indexer-web — event-sourced docs index WebUI (services.indexer-web),
    # loopback-only; Caddy proxies index.home.lan to it. Binary from the
    # index flake (github:LarsArtmann/index).
    indexer-web = 8105;

    # paperless-gpt — AI metadata enrichment + custom-field extraction
    # bridge (services.paperless-gpt). Loopback ONLY: the embedded web UI
    # has NO built-in auth, so it must never gain a vHost.
    paperless-gpt = 8106;
  };
}
