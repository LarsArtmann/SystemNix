# Boot evidence backfill: Oct 5 - Oct 10 boots (pre-vacuum gate)

Pulled 2026-10-13 00:06 UTC before journal vacuum pressure (7.1G of 8G SystemMaxUse);
backfills the gate REFUSED list: every exposed boot with an open stability row lacking committed evidence.
Per boot: first/last journal lines (crash-vs-clean-shutdown discriminator), kernel OOM lines,
memory-emergency-guard lines, thermal THROTTLE lines, panic/BUG/oops counts.

## Boot 449ef290 ( -> )

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
