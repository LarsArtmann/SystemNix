## Live pool addendum (2026-10-12 07:05)

New live report: `2026-10-12_07-00_catchall-404-dnsblockd-wildcard-fix-live.md`
— the owner-directed catch-all 404 root fix: dnsblockd wildcard support
upstream (d5a22a4b), lock bump, live on evo-x2 via the co-tenant deploy
train, end-to-end verified. Closes the DNS-premise row + 4 siblings on both
queue surfaces; harvests 3 new rows (NoRedirect script gap, upstream race
filing, gatus green-cycle watch).
