# mic-monitor Capture Fix: the "Recordings" Were cava, Snippets Off Until the Upstream Wave Lands (2026-11-27 01:50 CET)

> **In progress at 01:50 CET.** This file exists so the inline corrections in the three 2026-11-21/22 reports have a target. Sections are written as their evidence lands; nothing below a "written" line is claimed before it ran.

**Trigger:** the owner's "NOW GET SHIT DONE! The WHOLE TODO LIST!" on the follow-up list of [2026-11-26 23:10](./2026-11-26_23-10_mic-monitor-records-nothing-parecord-duration-unsupported-shim-committed-not-deployed-adhoc-capture-saved.md).

## Findings that changed the plan (written 01:50, evidence in the sections below)

1. **The 151 "recordings" are not microphone recordings.** A metadata-only watcher caught the stream at 01:15:50 CET: `cava -p /tmp/dms-cava-1795633885241-836864.conf`, parent `.dms-wrapped` (DankMaterialShell), source `16586` = `alsa_output.pci-0000_c6_00.1.hdmi-stereo-extra2.monitor`. PipeWire lists it with `Client: n/a` and no `application.*` property; only `node.name` and `media.name` say `cava`. DMS restarts it often (61 stream starts on 2026-11-25 UTC alone).
2. **The shim alone would have recorded the wrong thing.** The deployed mic-monitor ignores the device and refuses nothing, so with the shim each cava restart would have attached 5 s of the default microphone to a system-audio tap. `capture_snippets` is therefore set to `false` in tree until the fixed engine is floated.
