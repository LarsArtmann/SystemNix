{
  ports = {
    pocket-id = 1411;
    pocket-id-metrics = 9464;
    oauth2-proxy = 4180;
    caddy-metrics = 2019;

    dns-blocker = 53;
    dns-blocker-stats = 9090;
    dns-blocker-block = 8050;

    forgejo = 3000;

    homepage = 8082;

    immich = 2283;
    redis = 6379;

    paperless = 2892;
    tika = 9998;
    gotenberg = 3199;

    manifest = 2099;

    monitor365-server = 3001;
    monitor365-metrics = 9191;

    openseo = 3002;

    signoz = 8080;
    signoz-otlp-grpc = 4317;
    signoz-otlp-http = 4318;
    signoz-cadvisor = 9193;
    signoz-node-exporter = 9100;
    signoz-collector-metrics = 8888;
    signoz-clickhouse = 9000;
    signoz-clickhouse-metrics = 9363;
    signoz-clickhouse-keeper = 9181;
    signoz-clickhouse-raft = 9234;
    docker-engine-metrics = 9390;

    taskchampion = 10222;

    twenty = 3200;

    ollama = 11434;

    gatus = 9110;

    whisper = 7860;
    livekit = 7880;
    livekit-udp-start = 50000;
    livekit-udp-end = 51000;

    emeet-pixyd = 8090;

    minecraft = 25565;

    dozzle = 8084;

    crush-daily = 8081;

    bank-sync = 8097;

    overview = 8083;
    pma-health = 9190;

    activitywatch = 5600;

    discordsync-api = 8085;

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
  };
}
