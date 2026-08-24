import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var settings: ({})
  property string status: "loading"
  property string emptyReason: ""
  property string lastError: ""
  property string actionWarning: ""
  property string discoveryWarning: ""
  property var configSkipped: []
  property var services: []
  property string demoState: ""
  property double lastRefreshMs: 0
  property bool hasSnapshot: false
  property bool refreshing: false
  readonly property bool loading: status === "loading"
  readonly property string refreshWarning: actionWarning !== "" ? actionWarning : discoveryWarning
  readonly property string displayProjectName: demoState !== "" ? "User processes" : "User processes"
  readonly property string displayPath: (Quickshell.env("USER") || "current user") + " · " + services.length + " open"
  readonly property string branch: "LIVE"
  readonly property bool branchKnown: true
  readonly property string helperPath: Qt.resolvedUrl("../scripts/process-control").toString().replace(/^file:\/\//, "")
  readonly property int refreshIntervalSec: Math.max(5, Math.min(300, parseInt(settings.refreshIntervalSec || 10)))

  function refreshIfStale() { if (Date.now() - lastRefreshMs >= refreshIntervalSec * 1000) refresh() }
  function refresh() {
    if (demoState !== "") { demoTimer.restart(); return }
    if (listProcess.running) return
    if (!hasSnapshot) status = "loading"
    refreshing = true
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
    var rows = String(text || "").split("\n"), out = [], portPids = ({})
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].indexOf("@ports ") === 0) {
        var portList = rows[i].substr(7).split(",")
        for (var p = 0; p < portList.length; p++) if (/^\d+$/.test(portList[p])) portPids[portList[p]] = true
        continue
      }
      var match = rows[i].match(/^\s*(\d+)\s+(\S+)\s+(\S+)\s*(.*)$/)
      if (!match) continue
      var protectedProcess = /^(quickshell|Hyprland|systemd|dbus-broker|uwsm|process-control)$/.test(match[3])
      var commandText = match[4] || match[3]
      var listening = portPids[match[1]] === true
      var server = listening || /(^|[\s\/])(node|deno|bun|python|ruby|php|java|go)([\s\/]|$)|server|serve|dev|worker/i.test(commandText)
      var system = protectedProcess || /d$/.test(match[3]) || /^(pipewire|wireplumber|xdg-|gpg-agent|ssh-agent)/.test(match[3])
      out.push({ id: match[1], pid: match[1], name: match[3], command: [commandText], cwd: "", url: "", demoStatus: "running", protectedProcess: protectedProcess, processState: match[2], listening: listening, server: server, systemProcess: system })
    }
    services = out
    status = out.length ? "ready" : "empty"
    emptyReason = "no-processes"
    lastError = ""
    discoveryWarning = ""
    hasSnapshot = true
    lastRefreshMs = Date.now()
  }
  function applyDemo() {
    if (demoState === "error") { status = "error"; lastError = "Could not read the current user's process table. (Fictional demo error.)"; services = []; return }
    if (demoState === "empty") { status = "empty"; services = []; return }
    services = [
      {id:"4210",pid:"4210",name:"node",command:["node server.js"],url:"",demoStatus:"running",protectedProcess:false,processState:"Sl",listening:true,server:true,systemProcess:false},
      {id:"4388",pid:"4388",name:"python",command:["python worker.py"],url:"",demoStatus:"running",protectedProcess:false,processState:"S",listening:false,server:true,systemProcess:false},
      {id:"328014",pid:"328014",name:"quickshell",command:["quickshell shell session"],url:"",demoStatus:"running",protectedProcess:true,processState:"Sl",listening:false,server:false,systemProcess:true}
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
      root.refreshing = false
      if (code === 0) {
        root.parse(listOut.text)
      } else if (root.hasSnapshot) {
        root.discoveryWarning = "Could not refresh the current user's process table; showing the last successful snapshot."
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
      root.actionWarning = code === 0 ? "" : String(controlErr.text || "Process action failed.").trim()
      root.refresh()
    }
  }
}
