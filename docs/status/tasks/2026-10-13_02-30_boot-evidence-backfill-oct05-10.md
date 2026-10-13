# Boot evidence backfill: Oct 5 - Oct 10 boots (pre-vacuum gate)

Pulled 2026-10-13 00:06 UTC before journal vacuum pressure (7.1G of 8G SystemMaxUse);
includes late addition c819229e (2026-10-13 gate re-run); backfills the gate REFUSED list: every exposed boot with an open stability row lacking committed evidence.
Per boot: first/last journal lines (crash-vs-clean-shutdown discriminator), kernel OOM lines,
memory-emergency-guard lines, thermal THROTTLE lines, panic/BUG/oops counts.

## Boot 449ef290

### First 3 lines
    Oct 06 15:12:57.618501 evo-x2 bank-sync[224245]:   │ [corruption] wise.exchange_rate: wise: exchange rate PLN-EUR
    Oct 06 15:12:57.618501 evo-x2 bank-sync[224245]:   │   at: 2026-10-06T13:12:57Z

### Last 12 lines
    Oct 06 15:12:57.554804 evo-x2 systemd[1]: Started Session 16509 of User lars.
    Oct 06 15:12:57.560618 evo-x2 (systemd-stdio-bridge)[1587023]: gkr-pam: couldn't unlock the login keyring.
    Oct 06 15:12:57.566799 evo-x2 (sd-pam)[1587061]: pam_unix(login:session): session closed for user lars
    Oct 06 15:12:57.566940 evo-x2 systemd[1]: run-p1587021-i30834077.service: Deactivated successfully.
    Oct 06 15:12:57.574185 evo-x2 systemd[1]: Started [systemd-run] systemd-stdio-bridge --user --quiet.
    Oct 06 15:12:57.574479 evo-x2 systemd[1]: session-16509.scope: Deactivated successfully.
    Oct 06 15:12:57.592444 evo-x2 (systemd-stdio-bridge)[1587068]: pam_unix(login:session): session opened for user lars(uid=1000) by (uid=0)
    Oct 06 15:12:57.618501 evo-x2 bank-sync[224245]: 2026/10/06 15:12:57 WARN  net worth FX total failed; rendering without total
    Oct 06 15:12:57.618501 evo-x2 bank-sync[224245]:   error=
    Oct 06 15:12:57.618501 evo-x2 bank-sync[224245]:   │ [corruption] wise.exchange_rate: wise: exchange rate PLN-EUR
    Oct 06 15:12:57.618501 evo-x2 bank-sync[224245]:   │   at: 2026-10-06T13:12:57Z

### Census: OOM-lines=0 guard-lines=2685 thermal-THROTTLE-lines=7 panic/BUG/oops=365

### Thermal (first 5 / last 5)
    Oct 05 19:57:02 evo-x2 thermal-pstate-guard-check[96746]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
    Oct 06 01:32:41 evo-x2 thermal-pstate-guard-check[484530]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=62C(hi:95/lo:80)
    Oct 06 01:40:28 evo-x2 thermal-pstate-guard-check[663221]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
    Oct 06 03:25:24 evo-x2 thermal-pstate-guard-check[4074995]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=64C(hi:95/lo:80)
    Oct 06 03:57:44 evo-x2 thermal-pstate-guard-check[229463]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
    Oct 06 01:40:28 evo-x2 thermal-pstate-guard-check[663221]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
    Oct 06 03:25:24 evo-x2 thermal-pstate-guard-check[4074995]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=64C(hi:95/lo:80)
    Oct 06 03:57:44 evo-x2 thermal-pstate-guard-check[229463]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
    Oct 06 04:47:27 evo-x2 thermal-pstate-guard-check[1425710]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=80C(hi:95/lo:80)
    Oct 06 13:30:25 evo-x2 thermal-pstate-guard-check[359256]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)

## Boot a855ff2d (2026-10-06T15:41:14+02:00 -> 2026-10-06T15:41:14+02:00)

### First 3 lines
    Oct 06 15:41:14.304475 evo-x2 pma[2024]: WARN  batch queue full, will retry on next stale sweep component=service project=/home/lars/projects/hardware-identity project=/home/lars/projects/hardware-identity
    Oct 06 15:41:14.705608 evo-x2 pma[2024]: WARN  batch queue full, will retry on next stale sweep component=service project=/home/lars/projects/hardware-identity project=/home/lars/projects/hardware-identity
    Oct 06 15:41:14.846496 evo-x2 pma[2024]: WARN  batch queue full, will retry on next stale sweep component=service project=/home/lars/projects/hardware-identity project=/home/lars/projects/hardware-identity

### Last 12 lines
    Oct 06 15:41:08.843431 evo-x2 runuser[537492]: pam_unix(runuser:session): session opened for user forgejo(uid=973) by (uid=0)
    Oct 06 15:41:08.908809 evo-x2 runuser[537492]: pam_unix(runuser:session): session closed for user forgejo
    Oct 06 15:41:08.909719 evo-x2 forgejo-gen-runner-token[523771]: ERROR: Failed to generate runner registration token
    Oct 06 15:41:08.910649 evo-x2 systemd[1]: gitea-runner-evo\x2dx2.service: Control process exited, code=exited, status=1/FAILURE
    Oct 06 15:41:08.910773 evo-x2 systemd[1]: gitea-runner-evo\x2dx2.service: Failed with result 'exit-code'.
    Oct 06 15:41:08.911340 evo-x2 systemd[1]: Failed to start Gitea Actions Runner.
    Oct 06 15:41:08.911525 evo-x2 systemd[1]: gitea-runner-evo\x2dx2.service: Consumed 620ms CPU time over 1min 2.653s wall clock time, 34.8M memory peak, 5.8K incoming IP traffic, 8.2K outgoing IP traffic.
    Oct 06 15:41:10.487708 evo-x2 geometrikks-server[4844]: 2026-10-06T13:41:10.486720Z [info     ] HTTP Request                   [litestar] method=GET path=/health/ready path_params={} query={}
    Oct 06 15:41:13.285006 evo-x2 emeet-pixyd[15281]: 2026/10/06 15:41:13 INFO http request method=GET path=/metrics status=200 duration=1.997552ms
    Oct 06 15:41:14.304475 evo-x2 pma[2024]: WARN  batch queue full, will retry on next stale sweep component=service project=/home/lars/projects/hardware-identity project=/home/lars/projects/hardware-identity
    Oct 06 15:41:14.705608 evo-x2 pma[2024]: WARN  batch queue full, will retry on next stale sweep component=service project=/home/lars/projects/hardware-identity project=/home/lars/projects/hardware-identity
    Oct 06 15:41:14.846496 evo-x2 pma[2024]: WARN  batch queue full, will retry on next stale sweep component=service project=/home/lars/projects/hardware-identity project=/home/lars/projects/hardware-identity

### Census: OOM-lines=0 guard-lines=59 thermal-THROTTLE-lines=2 panic/BUG/oops=21

### Thermal (first 5 / last 5)
    Oct 06 15:17:17 evo-x2 thermal-pstate-guard-check[24380]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
    Oct 06 15:30:18 evo-x2 thermal-pstate-guard-check[241185]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=70C(hi:95/lo:80)
    Oct 06 15:17:17 evo-x2 thermal-pstate-guard-check[24380]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
    Oct 06 15:30:18 evo-x2 thermal-pstate-guard-check[241185]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=70C(hi:95/lo:80)

## Boot bdc8eac4 (2026-10-06T21:08:23+02:00 -> 2026-10-06T21:08:23+02:00)

### First 3 lines
    Oct 06 21:08:23.368942 evo-x2 browser-history-server[2857657]: {"time":"2026-10-06T21:07:58.894862623+02:00","level":"INFO","msg":"http request","method":"GET","path":"/","status":302,"duration":15519,"request_id":"01M499V4HEBQXSK13ZY8008ARM"}
    Oct 06 21:08:23.368942 evo-x2 browser-history-server[2857657]: {"time":"2026-10-06T21:07:58.905120545+02:00","level":"INFO","msg":"http request","method":"GET","path":"/register","status":200,"duration":201054,"request_id":"01M499V4HRXR6H9SG84G008ARN"}
    Oct 06 21:08:23.729074 evo-x2 storage-collector[1475]: 2026-10-06T19:07:55.938781Z  WARN storage_collector::procfs: statvfs failed; skipping mount this cycle mount_point=/run/credentials/immich-server.service fs_type=tmpfs error=permission denied: statvfs /run/credentials/immich-server.service: Permission denied (os error 13)

### Last 12 lines
    Oct 06 21:08:21.651063 evo-x2 node_exporter[1943]: time=2026-10-06T21:07:40.706+02:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9100->127.0.0.1:48792: write: connection reset by peer"
    Oct 06 21:08:21.651063 evo-x2 node_exporter[1943]: time=2026-10-06T21:07:40.706+02:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9100->127.0.0.1:48792: write: connection reset by peer"
    Oct 06 21:08:21.651063 evo-x2 node_exporter[1943]: time=2026-10-06T21:07:40.706+02:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9100->127.0.0.1:48792: write: connection reset by peer"
    Oct 06 21:08:21.651063 evo-x2 node_exporter[1943]: time=2026-10-06T21:07:40.706+02:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9100->127.0.0.1:48792: write: connection reset by peer"
    Oct 06 21:08:21.651063 evo-x2 node_exporter[1943]: time=2026-10-06T21:07:40.706+02:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9100->127.0.0.1:48792: write: connection reset by peer"
    Oct 06 21:08:21.651063 evo-x2 node_exporter[1943]: time=2026-10-06T21:07:40.706+02:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9100->127.0.0.1:48792: write: connection reset by peer"
    Oct 06 21:08:21.651063 evo-x2 node_exporter[1943]: time=2026-10-06T21:07:40.706+02:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9100->127.0.0.1:48792: write: connection reset by peer"
    Oct 06 21:08:21.651063 evo-x2 node_exporter[1943]: time=2026-10-06T21:07:40.706+02:00 level=ERROR source=http.go:231 msg="error encoding and sending metric family: write tcp 127.0.0.1:9100->127.0.0.1:48792: write: connection reset by peer"
    Oct 06 21:08:23.368942 evo-x2 browser-history-server[2857657]: {"time":"2026-10-06T21:07:58.712416274+02:00","level":"INFO","msg":"http request","method":"GET","path":"/","status":200,"duration":2748620,"user_id":"01M2X007JZB9Y1WDYF35AD5GSD","request_id":"01M499V4BNMSV6HGG8Y4008ARK"}
    Oct 06 21:08:23.368942 evo-x2 browser-history-server[2857657]: {"time":"2026-10-06T21:07:58.894862623+02:00","level":"INFO","msg":"http request","method":"GET","path":"/","status":302,"duration":15519,"request_id":"01M499V4HEBQXSK13ZY8008ARM"}
    Oct 06 21:08:23.368942 evo-x2 browser-history-server[2857657]: {"time":"2026-10-06T21:07:58.905120545+02:00","level":"INFO","msg":"http request","method":"GET","path":"/register","status":200,"duration":201054,"request_id":"01M499V4HRXR6H9SG84G008ARN"}
    Oct 06 21:08:23.729074 evo-x2 storage-collector[1475]: 2026-10-06T19:07:55.938781Z  WARN storage_collector::procfs: statvfs failed; skipping mount this cycle mount_point=/run/credentials/immich-server.service fs_type=tmpfs error=permission denied: statvfs /run/credentials/immich-server.service: Permission denied (os error 13)

### Census: OOM-lines=0 guard-lines=760 thermal-THROTTLE-lines=8 panic/BUG/oops=154

### Thermal (first 5 / last 5)
    Oct 06 15:48:39 evo-x2 thermal-pstate-guard-check[57273]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
    Oct 06 17:01:41 evo-x2 thermal-pstate-guard-check[1477581]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=67C(hi:95/lo:80)
    Oct 06 17:06:05 evo-x2 thermal-pstate-guard-check[1611072]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
    Oct 06 17:13:34 evo-x2 thermal-pstate-guard-check[1693903]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=80C(hi:95/lo:80)
    Oct 06 18:23:15 evo-x2 thermal-pstate-guard-check[2536972]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
    Oct 06 17:13:34 evo-x2 thermal-pstate-guard-check[1693903]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=80C(hi:95/lo:80)
    Oct 06 18:23:15 evo-x2 thermal-pstate-guard-check[2536972]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
    Oct 06 18:31:07 evo-x2 thermal-pstate-guard-check[2697068]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=76C(hi:95/lo:80)
    Oct 06 19:59:34 evo-x2 thermal-pstate-guard-check[601744]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
    Oct 06 20:02:26 evo-x2 thermal-pstate-guard-check[705076]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=74C(hi:95/lo:80)

## Boot 83ab0312 (2026-10-06T21:50:42+02:00 -> 2026-10-06T21:50:42+02:00)

### First 3 lines
    Oct 06 21:50:38.833623 evo-x2 file-renamer[1992]: 2026-10-06T21:50:38+02:00 INFO  watcher: request method=GET path=/ status=200 duration=2.85049ms client_ip=192.168.1.150 request_id=6ac5510e00000078a7346ac938bf3ef1
    Oct 06 21:50:39.211457 evo-x2 dms[16585]:   WARN qml: [WeatherService:699] Weather fetch failed: no output from fetcher
    Oct 06 21:50:42.859097 evo-x2 pma[2107]:  processing batch component=service project=/home/lars/projects/DiscordSync events=4 files=4 project=/home/lars/projects/DiscordSync events=4 files=4

### Last 12 lines
    Oct 06 21:50:38.751231 evo-x2 browser-history-server[10241]: {"time":"2026-10-06T21:50:38.751039662+02:00","level":"INFO","msg":"http request","method":"GET","path":"/","status":302,"duration":12830,"request_id":"01M49C98CYSEE8Z9D2R8008A19"}
    Oct 06 21:50:38.752537 evo-x2 pocket-id-start[2255]: Oct  6 21:50:38 INF HTTP request completed app=pocket-id version=2.16.0 request_id=f4ebde0a-40ca-46f7-bd28-016ef580fc9f status=200 method=GET path=/ query="" route="" ip=192.168.1.150 latency=118.958µs referer="" user_agent=Go-http-client/1.1 body_size=5434
    Oct 06 21:50:38.763647 evo-x2 browser-history-server[10241]: {"time":"2026-10-06T21:50:38.763212847+02:00","level":"INFO","msg":"http request","method":"GET","path":"/register","status":200,"duration":279914,"request_id":"01M49C98DAY7PSKDDGRM008A1A"}
    Oct 06 21:50:38.764778 evo-x2 discordsync[20393]: {"time":"2026-10-06T21:50:38.764264984+02:00","level":"INFO","source":{"function":"github.com/larsartmann/DiscordSync/internal/api.traceAwareLogging.func1.1","file":"github.com/larsartmann/DiscordSync/internal/api/middleware.go","line":59},"msg":"request","method":"GET","path":"/","status":200,"duration":6893075,"client_ip":"192.168.1.150","request_id":"6ac5510e0000020897601593de956631","trace_id":"bda69e3430a1be24d652f5cb6e4923db","span_id":"9c595a5dcb914ce5"}
    Oct 06 21:50:38.775304 evo-x2 cv[5394]: INFO  request method=GET path=/ status=200 duration=627.417µs client_ip=192.168.1.150 request_id=6ac5510e0000054937aac6e3fc436ad5
    Oct 06 21:50:38.780907 evo-x2 postgres[1002201]: [1002201] WARNING:  database "paperless" has a collation version mismatch
    Oct 06 21:50:38.780907 evo-x2 postgres[1002201]: [1002201] DETAIL:  The database was created using collation version 2.42, but the operating system provides version 2.44.
    Oct 06 21:50:38.784981 evo-x2 indexer-web[2038]: INFO request method=GET path=/ status=200 duration=10.252725ms client_ip=192.168.1.150 request_id=6ac5510e0000008036704a845929039a
    Oct 06 21:50:38.786424 evo-x2 nsfw-server[2092]: 2026/10/06 21:50:38 INFO  request method=GET path=/ status=200 duration=732.175µs client_ip=192.168.1.150
    Oct 06 21:50:38.833623 evo-x2 file-renamer[1992]: 2026-10-06T21:50:38+02:00 INFO  watcher: request method=GET path=/ status=200 duration=2.85049ms client_ip=192.168.1.150 request_id=6ac5510e00000078a7346ac938bf3ef1
    Oct 06 21:50:39.211457 evo-x2 dms[16585]:   WARN qml: [WeatherService:699] Weather fetch failed: no output from fetcher
    Oct 06 21:50:42.859097 evo-x2 pma[2107]:  processing batch component=service project=/home/lars/projects/DiscordSync events=4 files=4 project=/home/lars/projects/DiscordSync events=4 files=4

### Census: OOM-lines=0 guard-lines=95 thermal-THROTTLE-lines=2 panic/BUG/oops=25

### Thermal (first 5 / last 5)
    Oct 06 21:12:00 evo-x2 thermal-pstate-guard-check[23079]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
    Oct 06 21:29:49 evo-x2 thermal-pstate-guard-check[350099]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=77C(hi:95/lo:80)
    Oct 06 21:12:00 evo-x2 thermal-pstate-guard-check[23079]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
    Oct 06 21:29:49 evo-x2 thermal-pstate-guard-check[350099]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=77C(hi:95/lo:80)

## Boot 47864c87 (2026-10-07T00:00:59+02:00 -> 2026-10-07T00:00:59+02:00)

### First 3 lines
    Oct 07 00:00:59.147003 evo-x2 nix-gc-start[461818]: deleting '/nix/store/mg50gc1ip3rgi6fradxf92fxyam31406-crate-windows-registry-0.6.1.tar.gz.drv'
    Oct 07 00:00:59.147232 evo-x2 nix-gc-start[461818]: deleting '/nix/store/grnbah9npjfhjsjijjdqijx2z6ccf08s-windows-strings-0.5.1'
    Oct 07 00:00:59.147749 evo-x2 nix-gc-start[461818]: deleting '/nix/store/f1sva6gv2npmz6m3vyr7m3a09irrb0px-windows-strings-0.5.1.drv'

### Last 12 lines
    Oct 07 00:00:59.143668 evo-x2 nix-gc-start[461818]: deleting '/nix/store/0mivb79xpza75mr87zan6iyx6knq7qbs-windows-implement-0.60.2'
    Oct 07 00:00:59.144392 evo-x2 nix-gc-start[461818]: deleting '/nix/store/snxb7mvcfnx1n75kam02f77l229bj1gf-windows-interface-0.59.3'
    Oct 07 00:00:59.144887 evo-x2 nix-gc-start[461818]: deleting '/nix/store/mn28xhzzpla5ifjb4mfx8vc815jxf4q8-windows-interface-0.59.3.drv'
    Oct 07 00:00:59.145187 evo-x2 nix-gc-start[461818]: deleting '/nix/store/4p521ap0bki70yqq8j5lra2gahnj93xs-crate-windows-interface-0.59.3.tar.gz.drv'
    Oct 07 00:00:59.145424 evo-x2 nix-gc-start[461818]: deleting '/nix/store/j33yyfz04xwhsgxk4n81nvp4rs99hx34-windows-numerics-0.3.1'
    Oct 07 00:00:59.145858 evo-x2 nix-gc-start[461818]: deleting '/nix/store/7zyhcj5440fg7mcqzw9448cai59hz5i7-windows-numerics-0.3.1.drv'
    Oct 07 00:00:59.146007 evo-x2 nix-gc-start[461818]: deleting '/nix/store/an2saiw0kf49kky4fww0ibl2h1f8y247-crate-windows-numerics-0.3.1.tar.gz.drv'
    Oct 07 00:00:59.146229 evo-x2 nix-gc-start[461818]: deleting '/nix/store/xdqj0q7mg4h4yhnyxbddaphqd9irlhaw-windows-registry-0.6.1'
    Oct 07 00:00:59.146728 evo-x2 nix-gc-start[461818]: deleting '/nix/store/51r6ljb7dxwx7r5rd8gy63mi1d8pyfih-windows-registry-0.6.1.drv'
    Oct 07 00:00:59.147003 evo-x2 nix-gc-start[461818]: deleting '/nix/store/mg50gc1ip3rgi6fradxf92fxyam31406-crate-windows-registry-0.6.1.tar.gz.drv'
    Oct 07 00:00:59.147232 evo-x2 nix-gc-start[461818]: deleting '/nix/store/grnbah9npjfhjsjijjdqijx2z6ccf08s-windows-strings-0.5.1'
    Oct 07 00:00:59.147749 evo-x2 nix-gc-start[461818]: deleting '/nix/store/f1sva6gv2npmz6m3vyr7m3a09irrb0px-windows-strings-0.5.1.drv'

### Census: OOM-lines=0 guard-lines=299 thermal-THROTTLE-lines=1 panic/BUG/oops=109

### Thermal (first 5 / last 5)
    Oct 06 21:54:50 evo-x2 thermal-pstate-guard-check[26044]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
    Oct 06 21:54:50 evo-x2 thermal-pstate-guard-check[26044]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)

## Boot c58ced55 (2026-10-07T00:58:02+02:00 -> 2026-10-07T00:58:02+02:00)

### First 3 lines
    Oct 07 00:58:02.404758 evo-x2 postgres[1660566]: [1660566] WARNING:  database "paperless" has a collation version mismatch
    Oct 07 00:58:02.404758 evo-x2 postgres[1660566]: [1660566] DETAIL:  The database was created using collation version 2.42, but the operating system provides version 2.44.
    Oct 07 00:58:02.404758 evo-x2 postgres[1660566]: [1660566] HINT:  Rebuild all objects in this database that use the default collation and run ALTER DATABASE paperless REFRESH COLLATION VERSION, or build PostgreSQL with the right library version.

### Last 12 lines
    Oct 07 00:58:01.197998 evo-x2 signoz-wrapper[22606]: {"timestamp":"2026-10-07T00:58:01.197942951+02:00","level":"INFO","msg":"number of alerts found","rule.id":"01a00809-9297-744d-9285-a6dc2bbf0a48","alert.count":0,"code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).Eval","code.lineno":249}
    Oct 07 00:58:01.250315 evo-x2 nix-daemon[2053]: accepted connection from pid 1660422, user lars
    Oct 07 00:58:01.533210 evo-x2 nix-daemon[2053]: accepted connection from pid 1660500, user lars
    Oct 07 00:58:01.644402 evo-x2 oauth2-proxy[25522]: 127.0.0.1 - 4d6dca5b-2a6c-4dfb-ad92-6f0895c429b5 - - [2026/10/07 00:58:01] localhost:4180 GET - "/ping" HTTP/1.1 "Gatus/1.0" 200 2 0.000
    Oct 07 00:58:01.978911 evo-x2 postgres[1660557]: [1660557] WARNING:  database "paperless" has a collation version mismatch
    Oct 07 00:58:01.978911 evo-x2 postgres[1660557]: [1660557] DETAIL:  The database was created using collation version 2.42, but the operating system provides version 2.44.
    Oct 07 00:58:01.978911 evo-x2 postgres[1660557]: [1660557] HINT:  Rebuild all objects in this database that use the default collation and run ALTER DATABASE paperless REFRESH COLLATION VERSION, or build PostgreSQL with the right library version.
    Oct 07 00:58:02.372175 evo-x2 systemd[1]: Starting SEV1 escalation bridge: local overlay + notification for critical conditions...
    Oct 07 00:58:02.373981 evo-x2 systemd[1]: Starting Thermal pstate guard: switch amd_pstate to guided at the thermal ceiling, restore active when cool...
    Oct 07 00:58:02.404758 evo-x2 postgres[1660566]: [1660566] WARNING:  database "paperless" has a collation version mismatch
    Oct 07 00:58:02.404758 evo-x2 postgres[1660566]: [1660566] DETAIL:  The database was created using collation version 2.42, but the operating system provides version 2.44.
    Oct 07 00:58:02.404758 evo-x2 postgres[1660566]: [1660566] HINT:  Rebuild all objects in this database that use the default collation and run ALTER DATABASE paperless REFRESH COLLATION VERSION, or build PostgreSQL with the right library version.

### Census: OOM-lines=0 guard-lines=134 thermal-THROTTLE-lines=3 panic/BUG/oops=50

### Thermal (first 5 / last 5)
    Oct 07 00:12:25 evo-x2 thermal-pstate-guard-check[72567]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
    Oct 07 00:27:03 evo-x2 thermal-pstate-guard-check[761967]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=73C(hi:95/lo:80)
    Oct 07 00:48:08 evo-x2 thermal-pstate-guard-check[1300717]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
    Oct 07 00:12:25 evo-x2 thermal-pstate-guard-check[72567]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
    Oct 07 00:27:03 evo-x2 thermal-pstate-guard-check[761967]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=73C(hi:95/lo:80)
    Oct 07 00:48:08 evo-x2 thermal-pstate-guard-check[1300717]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)

## Boot 1ffa1610 (2026-10-07T01:28:03+02:00 -> 2026-10-07T01:28:03+02:00)

### First 3 lines
    Oct 07 01:28:03.163504 evo-x2 cv[4203]: INFO  Health check completed overall_status=warn checks_count=41 uptime=28m1s
    Oct 07 01:28:03.163816 evo-x2 cv[4203]: INFO  request method=GET path=/health status=200 duration=233.024µs client_ip=127.0.0.1 request_id=6ac58403000002962f3e8fd0ebe39a9e
    Oct 07 01:28:03.613843 evo-x2 systemd[1]: Starting Memory + I/O pressure (PSI) metrics for node_exporter textfile...

### Last 12 lines
    Oct 07 01:28:01.165366 evo-x2 cv[4203]: INFO  request method=GET path=/health status=200 duration=339.721µs client_ip=127.0.0.1 request_id=6ac584010000029523ab3c12084cc1aa
    Oct 07 01:28:01.177637 evo-x2 signoz-wrapper[10482]: {"timestamp":"2026-10-07T01:28:01.177574713+02:00","level":"INFO","msg":"promql rule task","name":"01a00809-9297-744d-9285-a6dc2bbf0a48-groupname","eval_started_at":"2026-10-06T23:28:01.176475468Z","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule_task.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRuleTask).Eval","code.lineno":326}
    Oct 07 01:28:01.177946 evo-x2 signoz-wrapper[10482]: {"timestamp":"2026-10-07T01:28:01.177647471+02:00","level":"INFO","msg":"evaluating promql query","rule.id":"01a00809-9297-744d-9285-a6dc2bbf0a48","rule.query":"system_emeet_pixyd_expected_down","code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).buildAndRunQuery","code.lineno":101}
    Oct 07 01:28:01.194572 evo-x2 signoz-wrapper[10482]: {"timestamp":"2026-10-07T01:28:01.194517604+02:00","level":"INFO","msg":"number of alerts found","rule.id":"01a00809-9297-744d-9285-a6dc2bbf0a48","alert.count":0,"code.filepath":"github.com/SigNoz/signoz/pkg/query-service/rules/prom_rule.go","code.function":"github.com/SigNoz/signoz/pkg/query-service/rules.(*PromRule).Eval","code.lineno":249}
    Oct 07 01:28:01.831733 evo-x2 systemd[14261]: Detect niri DRM zombie state and restart niri skipped, unmet condition check ConditionEnvironment=XDG_SESSION_ID
    Oct 07 01:28:01.832801 evo-x2 systemd[1782]: Starting Remove stale SSH control-master sockets...
    Oct 07 01:28:01.865340 evo-x2 ssh-socket-cleanup[1110166]: ssh-socket-cleanup: checked 1, removed 0 stale socket(s)
    Oct 07 01:28:01.868548 evo-x2 systemd[1782]: Finished Remove stale SSH control-master sockets.
    Oct 07 01:28:02.067917 evo-x2 pma[2046]:  processing batch component=service project=/home/lars/projects/go-filewatcher events=1 files=1 project=/home/lars/projects/go-filewatcher events=1 files=1
    Oct 07 01:28:03.163504 evo-x2 cv[4203]: INFO  Health check completed overall_status=warn checks_count=41 uptime=28m1s
    Oct 07 01:28:03.163816 evo-x2 cv[4203]: INFO  request method=GET path=/health status=200 duration=233.024µs client_ip=127.0.0.1 request_id=6ac58403000002962f3e8fd0ebe39a9e
    Oct 07 01:28:03.613843 evo-x2 systemd[1]: Starting Memory + I/O pressure (PSI) metrics for node_exporter textfile...

### Census: OOM-lines=0 guard-lines=63 thermal-THROTTLE-lines=1 panic/BUG/oops=31

### Thermal (first 5 / last 5)
    Oct 07 01:03:33 evo-x2 thermal-pstate-guard-check[43418]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
    Oct 07 01:03:33 evo-x2 thermal-pstate-guard-check[43418]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)

## Boot c8cc4dee

### First 3 lines
    Oct 07 02:49:28.729809 evo-x2 file-renamer[1704]: 2026-10-07T02:49:28+02:00 INFO  watcher: Status requested status=warn fail_checks=0
    Oct 07 02:49:28.730215 evo-x2 file-renamer[1704]: 2026-10-07T02:49:28+02:00 INFO  watcher: request method=GET path=/status status=200 duration=844.849µs client_ip=127.0.0.1 request_id=6ac59718000000dea35a405f98a2c0c0

### Last 12 lines
    Oct 07 02:49:23.575503 evo-x2 bank-sync[909426]:   │ [corruption] wise.exchange_rate: wise: exchange rate PLN-EUR
    Oct 07 02:49:23.575503 evo-x2 bank-sync[909426]:   │   at: 2026-10-07T00:49:23Z
    Oct 07 02:49:23.575503 evo-x2 bank-sync[909426]:   │   caused by: map exchange rate PLN-EUR: [corruption:wise.rates.parse_time] parse time "2026-10-07T00:49:01+0000": parse Wise timestamp "2026-10-07T00:49:01+0000": matches none of the accepted layouts 2006-01-02T15:04:05Z07:00, 2006-01-02T15:04:05.000-0700, 2006-01-02T15:04:05.000Z0700, 2006-01-02T15:04:05, 2006-01-02 15:04:05
    Oct 07 02:49:23.873835 evo-x2 bank-sync[909426]: 2026/10/07 02:49:23 INFO  command dispatched command=balance_sync.update_balance aggregate_id=balance:wise:88937934 duration=666.460061ms
    Oct 07 02:49:24.050441 evo-x2 bank-sync[909426]: 2026/10/07 02:49:24 WARN  transactions fetched via degraded SCA transfers fallback balance_id=balance:88937934 hint="outgoing transfers only — deposits, card activity, and fees are missing until the challenge is cleared"
    Oct 07 02:49:24.050441 evo-x2 bank-sync[909426]: 2026/10/07 02:49:24 WARN  statements paused pending SCA approval — Run 'bank-sync sca approve' (or set wise.sca_approval_token) to clear the challenge balance_id=balance:88937934 approval_token_issued=false
    Oct 07 02:49:24.051884 evo-x2 bank-sync[909426]: 2026/10/07 02:49:24 INFO  sync diff preview balance_id=balance:88937934 new=0 already_known=0
    Oct 07 02:49:24.874104 evo-x2 (sd-pam)[3029781]: pam_unix(login:session): session closed for user lars
    Oct 07 02:49:28.729809 evo-x2 file-renamer[1704]: 2026-10-07T02:49:28+02:00 INFO  watcher: Status requested status=warn fail_checks=0
    Oct 07 02:49:28.730215 evo-x2 file-renamer[1704]: 2026-10-07T02:49:28+02:00 INFO  watcher: request method=GET path=/status status=200 duration=844.849µs client_ip=127.0.0.1 request_id=6ac59718000000dea35a405f98a2c0c0

### Census: OOM-lines=0 guard-lines=175 thermal-THROTTLE-lines=1 panic/BUG/oops=102

### Thermal (first 5 / last 5)
    Oct 07 01:46:55 evo-x2 thermal-pstate-guard-check[294485]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
    Oct 07 01:46:55 evo-x2 thermal-pstate-guard-check[294485]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)

## Boot 18fad0e3 (2026-10-07T11:03:54+02:00 -> 2026-10-07T11:03:54+02:00)

### First 3 lines
    Oct 07 11:03:53.993105 evo-x2 crush-daily[2385]: time=2026-10-07T11:03:53.978+02:00 level=INFO msg="http request" method=GET path=/ status=200 duration=11.428886ms
    Oct 07 11:03:54.022818 evo-x2 file-renamer[1992]: 2026-10-07T11:03:54+02:00 INFO  watcher: request method=GET path=/ status=200 duration=2.480945ms client_ip=192.168.1.150 request_id=6ac60afa000001c12823cd8c378062e4
    Oct 07 11:03:54.050768 evo-x2 helium-launch[51660]: [51660:52785:1007/110354.050726:ERROR:components/value_store/value_store_frontend.cc:62] Error while writing chphlpgkkbolifaimnlloiipkdnihall.context_menus to

### Last 12 lines
    Oct 07 11:03:50.755096 evo-x2 nsfw-server[2051]: 2026/10/07 11:03:50 INFO  request method=GET path=/health status=200 duration=1.132181ms client_ip=192.168.1.150
    Oct 07 11:03:50.781316 evo-x2 nsfw-server[2051]: 2026/10/07 11:03:50 INFO  request method=GET path=/metrics status=200 duration=30.459849ms client_ip=192.168.1.150
    Oct 07 11:03:51.041743 evo-x2 helium-launch[51660]: [51660:52785:1007/110351.033817:ERROR:components/value_store/value_store_frontend.cc:62] Error while writing hlepfoohegkhhmjieoechaddaejaokhf.context_menus to
    Oct 07 11:03:52.038004 evo-x2 helium-launch[51660]: [51660:52785:1007/110352.037970:ERROR:components/value_store/value_store_frontend.cc:62] Error while writing chphlpgkkbolifaimnlloiipkdnihall.context_menus to
    Oct 07 11:03:53.053036 evo-x2 helium-launch[51660]: [51660:52785:1007/110353.042316:ERROR:components/value_store/value_store_frontend.cc:62] Error while writing chphlpgkkbolifaimnlloiipkdnihall.context_menus to
    Oct 07 11:03:53.882120 evo-x2 ollama[1999]: [GIN] 2026/10/07 - 11:03:53 | 200 |    2.936369ms |       127.0.0.1 | GET      "/api/tags"
    Oct 07 11:03:53.986270 evo-x2 emeet-pixyd[51655]: 2026/10/07 11:03:53 INFO http request method=GET path=/ status=0 duration=228.982µs
    Oct 07 11:03:53.987086 evo-x2 nsfw-server[2051]: 2026/10/07 11:03:53 INFO  request method=GET path=/ status=200 duration=924.608µs client_ip=192.168.1.150
    Oct 07 11:03:53.987354 evo-x2 indexer-web[2147]: INFO request method=GET path=/ status=200 duration=8.739939ms client_ip=192.168.1.150 request_id=6ac60af9000001dd4ace6d04b38f8e0d
    Oct 07 11:03:53.993105 evo-x2 crush-daily[2385]: time=2026-10-07T11:03:53.978+02:00 level=INFO msg="http request" method=GET path=/ status=200 duration=11.428886ms
    Oct 07 11:03:54.022818 evo-x2 file-renamer[1992]: 2026-10-07T11:03:54+02:00 INFO  watcher: request method=GET path=/ status=200 duration=2.480945ms client_ip=192.168.1.150 request_id=6ac60afa000001c12823cd8c378062e4
    Oct 07 11:03:54.050768 evo-x2 helium-launch[51660]: [51660:52785:1007/110354.050726:ERROR:components/value_store/value_store_frontend.cc:62] Error while writing chphlpgkkbolifaimnlloiipkdnihall.context_menus to

### Census: OOM-lines=0 guard-lines=339 thermal-THROTTLE-lines=1 panic/BUG/oops=153

### Thermal (first 5 / last 5)
    Oct 07 08:36:17 evo-x2 thermal-pstate-guard-check[37196]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
    Oct 07 08:36:17 evo-x2 thermal-pstate-guard-check[37196]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)

## Boot ee5791b9 (2026-10-10T23:13:31+02:00 -> 2026-10-10T23:13:31+02:00)

### First 3 lines
    Oct 10 23:13:23.854164 evo-x2 file-renamer[4019365]: 2026-10-10T23:13:23+02:00 INFO  watcher: request method=GET path=/status status=200 duration=1.379567ms client_ip=127.0.0.1 request_id=6acaaa73000006f79f9294fb3217b358
    Oct 10 23:13:31.934966 evo-x2 emeet-pixyd[436890]: 2026/10/10 23:13:31 INFO http request method=GET path=/ status=0 duration=180.075µs
    Oct 10 23:13:31.942165 evo-x2 ollama[3913980]: [GIN] 2026/10/10 - 23:13:31 | 200 |    2.510602ms |       127.0.0.1 | GET      "/api/tags"

### Last 12 lines
    Oct 10 23:13:20.212043 evo-x2 discordsync[4019646]: {"time":"2026-10-10T23:13:20.211994589+02:00","level":"INFO","source":{"function":"github.com/larsartmann/DiscordSync/internal/bot.(*Bot).reconcileGCSURLs","file":"github.com/larsartmann/DiscordSync/internal/bot/reconcile_gcs.go","line":59},"msg":"refreshing GCS signed URLs","count":100}
    Oct 10 23:13:20.296234 evo-x2 discordsync[4019646]: {"time":"2026-10-10T23:13:20.296188583+02:00","level":"INFO","source":{"function":"github.com/larsartmann/DiscordSync/internal/bot.(*Bot).reconcileGCSURLs","file":"github.com/larsartmann/DiscordSync/internal/bot/reconcile_gcs.go","line":59},"msg":"refreshing GCS signed URLs","count":100}
    Oct 10 23:13:20.393581 evo-x2 discordsync[4019646]: {"time":"2026-10-10T23:13:20.39344593+02:00","level":"INFO","source":{"function":"github.com/larsartmann/DiscordSync/internal/bot.(*Bot).reconcileGCSURLs","file":"github.com/larsartmann/DiscordSync/internal/bot/reconcile_gcs.go","line":59},"msg":"refreshing GCS signed URLs","count":100}
    Oct 10 23:13:20.476024 evo-x2 discordsync[4019646]: {"time":"2026-10-10T23:13:20.475982355+02:00","level":"INFO","source":{"function":"github.com/larsartmann/DiscordSync/internal/bot.(*Bot).reconcileGCSURLs","file":"github.com/larsartmann/DiscordSync/internal/bot/reconcile_gcs.go","line":59},"msg":"refreshing GCS signed URLs","count":100}
    Oct 10 23:13:20.525460 evo-x2 systemd[1]: psi-metrics.service: Deactivated successfully.
    Oct 10 23:13:20.526386 evo-x2 systemd[1]: Finished Memory + I/O pressure (PSI) metrics for node_exporter textfile.
    Oct 10 23:13:20.563253 evo-x2 discordsync[4019646]: {"time":"2026-10-10T23:13:20.563205975+02:00","level":"INFO","source":{"function":"github.com/larsartmann/DiscordSync/internal/bot.(*Bot).reconcileGCSURLs","file":"github.com/larsartmann/DiscordSync/internal/bot/reconcile_gcs.go","line":59},"msg":"refreshing GCS signed URLs","count":100}
    Oct 10 23:13:23.409872 evo-x2 emeet-pixyd[436890]: 2026/10/10 23:13:23 INFO http request method=GET path=/api/health status=503 duration=45.068µs
    Oct 10 23:13:23.853739 evo-x2 file-renamer[4019365]: 2026-10-10T23:13:23+02:00 INFO  watcher: Status requested status=warn fail_checks=0
    Oct 10 23:13:23.854164 evo-x2 file-renamer[4019365]: 2026-10-10T23:13:23+02:00 INFO  watcher: request method=GET path=/status status=200 duration=1.379567ms client_ip=127.0.0.1 request_id=6acaaa73000006f79f9294fb3217b358
    Oct 10 23:13:31.934966 evo-x2 emeet-pixyd[436890]: 2026/10/10 23:13:31 INFO http request method=GET path=/ status=0 duration=180.075µs
    Oct 10 23:13:31.942165 evo-x2 ollama[3913980]: [GIN] 2026/10/10 - 23:13:31 | 200 |    2.510602ms |       127.0.0.1 | GET      "/api/tags"

### Census: OOM-lines=190 guard-lines=11677 thermal-THROTTLE-lines=69 panic/BUG/oops=2747

### OOM lines
    Oct 08 02:14:11 evo-x2 kernel: find invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    Oct 08 02:14:11 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=tq-agent-pool.service,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=113924,uid=1000
    Oct 08 02:14:11 evo-x2 kernel: Memory cgroup out of memory: Killed process 113924 (nix) total-vm:19333452kB, anon-rss:2154688kB, file-rss:35776kB, shmem-rss:0kB, UID:1000 pgtables:37208kB oom_score_adj:0
    Oct 09 00:06:47 evo-x2 kernel: bash invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    Oct 09 00:06:47 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3860871,uid=1000
    Oct 09 00:06:47 evo-x2 kernel: Memory cgroup out of memory: Killed process 3860871 (nix) total-vm:8728044kB, anon-rss:7673188kB, file-rss:67184kB, shmem-rss:0kB, UID:1000 pgtables:16344kB oom_score_adj:0
    Oct 09 00:08:34 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    Oct 09 00:08:34 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=4161814,uid=1000
    Oct 09 00:08:34 evo-x2 kernel: Memory cgroup out of memory: Killed process 4161814 (nix) total-vm:8271008kB, anon-rss:7892264kB, file-rss:35124kB, shmem-rss:0kB, UID:1000 pgtables:15680kB oom_score_adj:0
    Oct 09 00:14:48 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    Oct 09 00:14:48 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=844290,uid=1000
    Oct 09 00:14:48 evo-x2 kernel: Memory cgroup out of memory: Killed process 844290 (nix) total-vm:8023996kB, anon-rss:7417780kB, file-rss:35300kB, shmem-rss:0kB, UID:1000 pgtables:14776kB oom_score_adj:0
    Oct 09 00:16:44 evo-x2 kernel: compile invoked oom-killer: gfp_mask=0x100cca(GFP_HIGHUSER_MOVABLE), order=0, oom_score_adj=0
    Oct 09 00:16:44 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=1063034,uid=1000
    Oct 09 00:16:44 evo-x2 kernel: Memory cgroup out of memory: Killed process 1063034 (nix) total-vm:7793348kB, anon-rss:7413964kB, file-rss:35212kB, shmem-rss:0kB, UID:1000 pgtables:14772kB oom_score_adj:0
    Oct 09 00:23:37 evo-x2 kernel: crush invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    Oct 09 00:23:37 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=1977431,uid=1000
    Oct 09 00:23:37 evo-x2 kernel: Memory cgroup out of memory: Killed process 1977431 (nix) total-vm:6578364kB, anon-rss:6197084kB, file-rss:35060kB, shmem-rss:0kB, UID:1000 pgtables:12380kB oom_score_adj:0
    Oct 09 00:25:27 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    Oct 09 00:25:27 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=2161443,uid=1000
    Oct 09 00:25:27 evo-x2 kernel: Memory cgroup out of memory: Killed process 2161443 (nix) total-vm:7682572kB, anon-rss:7295008kB, file-rss:35260kB, shmem-rss:0kB, UID:1000 pgtables:14528kB oom_score_adj:0
    Oct 09 00:26:52 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    Oct 09 00:26:52 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=2318160,uid=1000
    Oct 09 00:26:52 evo-x2 kernel: Memory cgroup out of memory: Killed process 2318160 (nix) total-vm:8057536kB, anon-rss:7670580kB, file-rss:35096kB, shmem-rss:0kB, UID:1000 pgtables:15260kB oom_score_adj:0
    Oct 09 00:28:05 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    Oct 09 00:28:05 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=2482115,uid=1000
    Oct 09 00:28:05 evo-x2 kernel: Memory cgroup out of memory: Killed process 2482115 (nix) total-vm:8048316kB, anon-rss:7671016kB, file-rss:35092kB, shmem-rss:0kB, UID:1000 pgtables:15268kB oom_score_adj:0
    Oct 09 00:35:56 evo-x2 kernel: nix invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    Oct 09 00:35:56 evo-x2 kernel: oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/tq-agent-pool.service,task_memcg=/system.slice/tq-agent-pool.service,task=nix,pid=3440728,uid=1000
    Oct 09 00:35:56 evo-x2 kernel: Memory cgroup out of memory: Killed process 3440728 (nix) total-vm:6654032kB, anon-rss:6269296kB, file-rss:34988kB, shmem-rss:0kB, UID:1000 pgtables:12524kB oom_score_adj:0

### Thermal (first 5 / last 5)
    Oct 07 11:06:47 evo-x2 thermal-pstate-guard-check[14806]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=96C(hi:95/lo:80)
    Oct 07 13:50:19 evo-x2 thermal-pstate-guard-check[2178225]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=71C(hi:95/lo:80)
    Oct 07 14:20:10 evo-x2 thermal-pstate-guard-check[3009617]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
    Oct 07 14:22:13 evo-x2 thermal-pstate-guard-check[3024097]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=61C(hi:95/lo:80)
    Oct 07 14:54:52 evo-x2 thermal-pstate-guard-check[3764041]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
    Oct 10 16:21:38 evo-x2 thermal-pstate-guard-check[3109791]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)
    Oct 10 17:29:45 evo-x2 thermal-pstate-guard-check[596163]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=68C(hi:95/lo:80)
    Oct 10 21:09:06 evo-x2 thermal-pstate-guard-check[3852457]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
    Oct 10 22:46:24 evo-x2 thermal-pstate-guard-check[2761271]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=70C(hi:95/lo:80)
    Oct 10 22:57:25 evo-x2 thermal-pstate-guard-check[2945332]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)

## Boot c819229e (first: Oct 07 02:51:12.145751 evo-x2 kernel: Linux version 7.2.9 (nixbld@localhost) (gcc (GCC) 16.2.0,

### First 3 lines
    Oct 07 08:32:54.476563 evo-x2 mr-sync[1463]: mr-sync: hierarchical-errors was renamed to erraudit on GitHub, but .mrconfig already tracks erraudit; leaving hierarchical-errors orphaned
    Oct 07 08:32:56.624960 evo-x2 emeet-pixyd[15602]: 2026/10/07 08:32:56 INFO http request method=GET path=/ status=0 duration=254.161µs
    Oct 07 08:32:56.650913 evo-x2 ollama[2016]: [GIN] 2026/10/07 - 08:32:56 | 200 |    3.383219ms |       127.0.0.1 | GET      "/api/tags"

### Last 12 lines
    Oct 07 08:32:52.971284 evo-x2 cv[4135]: INFO  request method=GET path=/health status=200 duration=246.512µs client_ip=127.0.0.1 request_id=6ac5e79400003096e8a5b2e3c218e3c6
    Oct 07 08:32:53.105359 evo-x2 clickhouse-server[6443]: 2026.10.07 08:32:53.097583 [ 6685 ] {} <Warning> Context: High CPU usage: 98% busy (>= 90%) for at least 600 second(s)
    Oct 07 08:32:53.662601 evo-x2 nix-daemon[2424]: accepted connection from pid 2500693, user lars
    Oct 07 08:32:53.876239 evo-x2 mr-sync[1463]: mr-sync: go-plugin-mvp was renamed to plugmarket on GitHub, but .mrconfig already tracks plugmarket; leaving go-plugin-mvp orphaned
    Oct 07 08:32:54.081906 evo-x2 systemd[1]: Starting SEV1 escalation bridge: local overlay + notification for critical conditions...
    Oct 07 08:32:54.089449 evo-x2 systemd[1]: Starting Thermal pstate guard: switch amd_pstate to guided at the thermal ceiling, restore active when cool...
    Oct 07 08:32:54.108111 evo-x2 nix-daemon[2424]: accepted connection from pid 2501268, user lars
    Oct 07 08:32:54.247619 evo-x2 systemd[1]: thermal-pstate-guard.service: Deactivated successfully.
    Oct 07 08:32:54.248557 evo-x2 systemd[1]: Finished Thermal pstate guard: switch amd_pstate to guided at the thermal ceiling, restore active when cool.
    Oct 07 08:32:54.476563 evo-x2 mr-sync[1463]: mr-sync: hierarchical-errors was renamed to erraudit on GitHub, but .mrconfig already tracks erraudit; leaving hierarchical-errors orphaned
    Oct 07 08:32:56.624960 evo-x2 emeet-pixyd[15602]: 2026/10/07 08:32:56 INFO http request method=GET path=/ status=0 duration=254.161µs
    Oct 07 08:32:56.650913 evo-x2 ollama[2016]: [GIN] 2026/10/07 - 08:32:56 | 200 |    3.383219ms |       127.0.0.1 | GET      "/api/tags"

### Census: OOM-lines=0 guard-lines=777 thermal-THROTTLE-lines=5 panic/BUG/oops=441
    Oct 07 02:58:35 evo-x2 thermal-pstate-guard-check[181651]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=98C(hi:95/lo:80)
    Oct 07 03:28:47 evo-x2 thermal-pstate-guard-check[1909693]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=66C(hi:95/lo:80)
    Oct 07 04:33:43 evo-x2 thermal-pstate-guard-check[724656]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=97C(hi:95/lo:80)
    Oct 07 05:05:04 evo-x2 thermal-pstate-guard-check[1769543]: thermal-pstate-guard: THERMAL THROTTLE EXIT: amd_pstate restored to active + performance after 12x cool ticks: k10temp=64C(hi:95/lo:80)
    Oct 07 05:09:58 evo-x2 thermal-pstate-guard-check[2079151]: thermal-pstate-guard: THERMAL THROTTLE ENTER: amd_pstate -> guided after 2x hot ticks: k10temp=95C(hi:95/lo:80)

