# Bridge-activity probe shared by the llama-chat and llama-vlm idle checks.
#
# Both checks must answer: did any per-connection bridge of this template run
# inside the keep-alive window? The first version asked journalctl with a unit
# glob (`-u 'llama-chat@*.service'`). A glob adds no index match, so journalctl
# reads every journal entry of the window and filters in the client. Measured
# 2026-11-26, on every 5-minute run: the 60-minute llama-chat window cost
# 1.5-4.1 GB of memory and 1.9-2.4 GB of disk reads (1-2 minutes of CPU), one
# 2-hour llama-vlm-cap run read 72 GB in 4 minutes 15 seconds, and the two
# kept io PSI some avg10 at 36-58 % for 17 hours, which gates deploys (20 %)
# and both backends (30 %).
#
# The lines are indexed by message id: every bridge instance logs "Starting"
# when the socket spawns it and "Consumed" when systemd unloads it. Matching
# the ids reads only those lines (0.8 s for the same 60-minute window) and the
# client filters them on UNIT, the field that names the instance.
{ lib, pkgs }:
let
  journalctl = lib.getExe' pkgs.systemd "journalctl";
  grep = lib.getExe pkgs.gnugrep;
  # Verified against the journal on 2026-11-26 over the 253 llama-chat
  # bridges of the preceding 6 hours: every instance logged the first two and
  # "Consumed"; the others are the remaining ways an instance ends.
  messageIds = [
    "7d4958e842da4a758f6c1cdc7b36dcc5" # Starting <unit>...
    "39f53479d3a045ac8e11786248231fbf" # Started <unit>.
    "7ad2d189f7e94e70a38c781354912448" # <unit>: Deactivated successfully.
    "ae8f7b866b0347b9af31fe1c80b127c0" # <unit>: Consumed <resources>.
    "d9b373ed55a64feb8242e02dbe79a49c" # <unit>: Failed with result ...
    "98e322203f7a4ed290d09fe03c09fe15" # <unit>: Main process exited ...
    "de5b426a63be47a7b6ac3eaac82e2f6f" # <unit>: Finished <description>.
    "9d1aaa27d60140bd96365438aad20286" # <unit>: Stopped <description>.
  ];
in
{
  # Usage: template-activity-since 'llama-chat@' 60min
  # Exit 0 when any instance of the template logged a lifecycle line inside the
  # window ("<since> ago"), exit 1 when none did. An unreadable journal is
  # treated as activity: the caller keeps a model it cannot prove idle.
  templateActivity = pkgs.writeShellApplication {
    name = "template-activity-since";
    runtimeInputs = [ pkgs.systemd pkgs.gnugrep ];
    text = ''
      template="''${1:?template prefix, e.g. llama-chat@}"
      since="''${2:?window, e.g. 60min}"
      lines=$(${journalctl} ${toString (map (id: "MESSAGE_ID=${id}") messageIds)} \
        --since "$since ago" --output=json --output-fields=UNIT --no-pager --quiet 2>/dev/null) && rc=0 || rc=$?
      count=$(printf '%s\n' "$lines" | ${grep} -c "\"UNIT\":\"$template") || true
      [ "$rc" -eq 0 ] || exit 0
      [ "''${count:-0}" -gt 0 ]
    '';
  };
}
