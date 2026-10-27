# SigNoz migrator-gap guard: join the KNOWN migration list (extracted from
# the pinned signoz-otel-collector source at build time) against the LIVE
# applied state (<db>.schema_migrations_v2). Shared by the
# signoz-migrator-guard collector and its fixture selftest — single source,
# the selftest dies if this file drifts from what the collector runs.
#
# stdin/args: known.tsv FIRST (db \t id \t group \t class — consumed via
# FNR==NR), then the applied TSV (db \t id \t status). Mode via -v:
#   rows          per-violation metric lines (missing/unknown/failed)
#   missing_total known incremental-sync migrations without a finished row
#   unknown_total applied rows unknown to the pinned source
#   failed_total  applied rows stuck in status=failed
# Semantics (manager.go IsAsyncOperation):
#   missing = the 1010 squash-gap class — the pinned source's incremental
#             series demands a finished row; anything else (absent,
#             in-progress, failed) means the schema is not converged.
#   squashed-group ids never participate in missing (install-time series,
#             legitimately absent on legacy-migrated hosts).
#   unknown op types classify conservatively as async upstream, so this
#             join can only UNDER-report, never false-alarm.
FNR == NR {
	if ($3 == "incremental" && $4 == "sync")
		needsync[$1 SUBSEP $2] = 1
	known[$1 SUBSEP $2] = 1
	next
}
NF >= 3 {
	status[$1 SUBSEP $2] = $3
	if (!($1 SUBSEP $2 in known))
		unknown++
	if ($3 == "failed")
		failed++
}
END {
	missing = 0
	for (k in needsync)
		if (status[k] != "finished")
			missing++
	if (mode == "missing_total") {
		print missing
	} else if (mode == "unknown_total") {
		print unknown + 0
	} else if (mode == "failed_total") {
		print failed + 0
	} else if (mode == "rows") {
		for (k in needsync)
			if (status[k] != "finished")
				printf "signoz_migrator_missing_applied{database=\"%s\",migration=\"%s\"} 1\n", substr(k, 1, index(k, SUBSEP) - 1), substr(k, index(k, SUBSEP) + 1)
		for (k in status) {
			if (!(k in known))
				printf "signoz_migrator_unknown_applied{database=\"%s\",migration=\"%s\"} 1\n", substr(k, 1, index(k, SUBSEP) - 1), substr(k, index(k, SUBSEP) + 1)
			if (status[k] == "failed")
				printf "signoz_migrator_failed_applied{database=\"%s\",migration=\"%s\"} 1\n", substr(k, 1, index(k, SUBSEP) - 1), substr(k, index(k, SUBSEP) + 1)
		}
	}
}
