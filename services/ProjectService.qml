import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var settings: ({})
  property string status: "loading"
  property string emptyReason: ""
  property string lastError: ""
  property string refreshWarning: ""
  property var configSkipped: []
  property var services: []
  property string demoState: ""
  property double lastRefreshMs: 0
  readonly property bool loading: status === "loading"
  readonly property string displayProjectName: demoState !== "" ? "User processes" : "User processes"
  readonly property string displayPath: (Quickshell.env("USER") || "current user") + " · " + services.length + " open"
  readonly property string branch: "LIVE"
  readonly property bool branchKnown: true
  readonly property string helperPath: Qt.resolvedUrl("../scripts/process-control").toString().replace(/^file:\/\//, "")
  readonly property int refreshIntervalSec: Math.max(5, Math.min(300, parseInt(settings.refreshIntervalSec || 10)))

  function refreshIfStale() { if (Date.now() - lastRefreshMs >= refreshIntervalSec * 1000) refresh() }
  function refresh() {
    if (demoState !== "") { demoTimer.restart(); return }
    status = "loading"
    listProcess.command = [helperPath, "list"]
    listProcess.running = true
  }
  function control(action, pid) {
    if (!/^\d+$/.test(String(pid))) return
    controlProcess.command = [helperPath, action, String(pid)]
    controlProcess.running = true
  }
  function setDemoState(next) {
    if (next !== "ready" && next !== "empty" && next !== "error") return "invalid"
    demoState = next; demoTimer.restart(); return "ok"
  }
  function parse(text) {
    var rows = String(text || "").split("\n"), out = []
    for (var i = 0; i < rows.length; i++) {
      var match = rows[i].match(/^\s*(\d+)\s+(\S+)\s+(\S+)\s*(.*)$/)
      if (!match) continue
      var protectedProcess = /^(quickshell|Hyprland|systemd|dbus-broker|uwsm|process-control)$/.test(match[3])
      out.push({ id: match[1], pid: match[1], name: match[3], command: [match[4] || match[3]], cwd: "", url: "", demoStatus: "running", protectedProcess: protectedProcess, processState: match[2] })
    }
    services = out; status = out.length ? "ready" : "empty"; emptyReason = "no-processes"; lastRefreshMs = Date.now()
  }
  function applyDemo() {
    if (demoState === "error") { status = "error"; lastError = "Could not read the current user's process table. (Fictional demo error.)"; services = []; return }
    if (demoState === "empty") { status = "empty"; services = []; return }
    services = [
      {id:"4210",pid:"4210",name:"node",command:["node server.js"],url:"",demoStatus:"running",protectedProcess:false,processState:"Sl"},
      {id:"4388",pid:"4388",name:"python",command:["python worker.py"],url:"",demoStatus:"running",protectedProcess:false,processState:"S"},
      {id:"328014",pid:"328014",name:"quickshell",command:["quickshell shell session"],url:"",demoStatus:"running",protectedProcess:true,processState:"Sl"}
    ]; status = "ready"
  }
  function demoLogsFor(id) { var s = services.find(function(x){return x.id===id}); return s ? [{text:"PID " + s.pid + " · state " + s.processState,stream:"out"},{text:s.command[0],stream:"out"}] : [] }

  Timer { interval: root.refreshIntervalSec*1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
  Timer { id: demoTimer; interval: 100; onTriggered: root.applyDemo() }
  Process {
    id: listProcess
    running: false
    command: []
    stdout: StdioCollector { id: listOut; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      if (code === 0) {
        root.parse(listOut.text)
      } else {
        root.status = "error"
        root.lastError = "Could not read the current user's process table."
      }
    }
  }

  Process {
    id: controlProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { id: controlErr; waitForEnd: true }
    onExited: function(code) {
      root.refreshWarning = code === 0 ? "" : String(controlErr.text || "Process action failed.").trim()
      root.refresh()
    }
  }
}
