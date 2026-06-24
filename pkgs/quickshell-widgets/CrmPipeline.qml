// SystemNix Quickshell Widgets — CRM Pipeline (Twenty)
// Polls Twenty CRM for active opportunity count
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: crm

  readonly property string apiUrl: "http://127.0.0.1:3200"
  property int activeOpportunities: 0
  property string pipelineValue: "—"
  readonly property string displayText: activeOpportunities > 0 ? activeOpportunities + " opps" : ""

  function refresh() {
    crmProcess.running = true;
  }

  Process {
    id: crmProcess
    command: ["curl", "-sf", "--connect-timeout", "2",
      crm.apiUrl + "/rest/opportunities?take=100"]
    running: true

    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(this.text);
          var opps = data.opportunities || data.data || data || [];
          if (Array.isArray(opps)) {
            crm.activeOpportunities = opps.length;
            var totalValue = 0;
            for (var i = 0; i < opps.length; i++) {
              totalValue += parseFloat(opps[i].amount || opps[i].value || 0);
            }
            if (totalValue > 0) {
              crm.pipelineValue = "$" + (totalValue >= 1000
                ? (totalValue / 1000).toFixed(1) + "k"
                : totalValue.toFixed(0));
            }
          }
        } catch (e) {
          crm.activeOpportunities = 0;
        }
      }
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: crm.refresh()
  }
}
