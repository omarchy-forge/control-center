import QtQuick
import Quickshell
import Quickshell.Io
import "ServiceConfig.js" as ServiceConfig

// Read-only project status: git branch and the validated service list from
// <projectPath>/.omaforge/services.json. Owns no long-running processes —
// that is ProcessPool's job. See FORGE_SPEC.md "Data and commands".
Item {
  id: root

  property var settings: ({})
  // Named `status`, not `state` — Item already declares a `state` property
  // for QML's States system; shadowing it silently is a real bug, not style.
  property string status: "loading" // loading | ready | empty | error
  property string emptyReason: "" // no-project | no-config | invalid
  property string configParseError: ""
  property var configSkipped: []
  property string lastError: ""
  property string refreshWarning: ""
  property var services: []
  property string branch: ""
  property bool branchKnown: false
  property bool projectMissing: false
  property bool hasLoadedOnce: false
  property bool branchTimedOut: false
  property double lastRefreshMs: 0
  property date updatedAt: new Date(0)
  property string demoState: ""

  readonly property string projectPath: setting("projectPath", "")
  readonly property string projectName: root.projectPath === "" ? "" : basenameOf(root.projectPath)
  readonly property int refreshIntervalSec: boundedInteger("refreshIntervalSec", 60, 10, 3600)
  readonly property bool loading: status === "loading"
  readonly property string configRelPath: ".omaforge/services.json"
  readonly property string displayProjectName: demoState !== "" ? "demo-project" : projectName
  readonly property string displayPath: demoState !== "" ? "~/code/demo-project" : projectPath

  function setting(name, fallback) {
    var candidate = settings ? settings[name] : undefined
    return candidate === undefined || candidate === null ? fallback : candidate
  }

  function boundedInteger(name, fallback, minimum, maximum) {
    var candidate = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(candidate)) candidate = fallback
    return Math.max(minimum, Math.min(maximum, candidate))
  }

  function basenameOf(path) {
    var trimmed = String(path || "").replace(/\/+$/, "")
    var idx = trimmed.lastIndexOf("/")
    return idx >= 0 ? trimmed.substr(idx + 1) : trimmed
  }

  function refreshIfStale() {
    if (Date.now() - lastRefreshMs >= refreshIntervalSec * 1000) refresh()
  }

  function setDemoState(nextState) {
    var candidate = String(nextState || "")
    if (candidate !== "ready" && candidate !== "empty" && candidate !== "error") return "invalid"
    demoState = candidate
    demoTimer.restart()
    return "ok"
  }

  function refresh() {
    if (demoState !== "") {
      status = "loading"
      demoTimer.restart()
      return
    }
    if (root.projectPath === "") {
      status = "empty"
      emptyReason = "no-project"
      services = []
      lastRefreshMs = Date.now()
      return
    }
    status = hasLoadedOnce ? status : "loading"
    branchTimedOut = false
    branchProcess.command = ["git", "-C", root.projectPath, "rev-parse", "--abbrev-ref", "HEAD"]
    branchProcess.running = true
    branchTimeout.restart()
    configFile.reload()
  }

  function applyConfigText(text) {
    configResult = ServiceConfig.parseConfig(text, root.projectPath)
    recomputeState()
  }

  property var configResult: ({ services: [], skipped: [], error: "" })

  function recomputeState() {
    if (demoState !== "") return
    if (root.projectPath === "") {
      status = "empty"
      emptyReason = "no-project"
      services = []
      return
    }
    if (root.projectMissing) {
      if (root.hasLoadedOnce) {
        status = "ready"
        refreshWarning = "Could not verify the git repository at " + root.projectPath + " (git failed or did not respond within 5s — check that git is installed and the path is a repository). Showing last known status."
      } else {
        status = "error"
        lastError = "Could not open \"" + root.projectPath + "\" as a git repository. Check that git is installed and the project directory setting points at a git repository."
      }
      return
    }
    var result = root.configResult
    configParseError = result.error
    configSkipped = result.skipped
    if (result.services.length === 0) {
      status = "empty"
      emptyReason = result.error !== "" ? "invalid" : "no-config"
      services = []
      hasLoadedOnce = true
      return
    }
    services = result.services
    status = "ready"
    refreshWarning = ""
    hasLoadedOnce = true
  }

  function applyDemoState() {
    lastRefreshMs = Date.now()
    updatedAt = new Date()
    if (demoState === "error") {
      status = "error"
      lastError = "Could not open \"~/code/demo-project\" as a git repository. (Fictional demo error.)"
      services = []
      branch = ""
      branchKnown = false
      return
    }
    if (demoState === "empty") {
      status = "empty"
      emptyReason = "no-config"
      services = []
      branch = "main"
      branchKnown = true
      return
    }
    branch = "main"
    branchKnown = true
    services = [
      { id: "web", name: "Web", command: ["pnpm", "dev"], cwd: "~/code/demo-project", url: "http://localhost:3000", demoStatus: "running" },
      { id: "api", name: "API", command: ["uv", "run", "fastapi", "dev"], cwd: "~/code/demo-project/api", url: "http://localhost:8000", demoStatus: "running" },
      { id: "worker", name: "Worker", command: ["pnpm", "worker"], cwd: "~/code/demo-project", url: "", demoStatus: "stopped" }
    ]
    status = "ready"
    refreshWarning = ""
  }

  readonly property var demoLogs: ({
    "web": ["$ pnpm dev", "  VITE  ready in 312 ms", "  ➜  Local:   http://localhost:3000/"],
    "api": ["$ uv run fastapi dev", "INFO  Server started", "INFO  Listening on 0.0.0.0:8000", "GET   /health  200"],
    "worker": []
  })

  function demoLogsFor(id) {
    var lines = demoLogs[id] || []
    var out = []
    for (var i = 0; i < lines.length; i++) out.push({ text: lines[i], stream: "out" })
    return out
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: demoTimer
    interval: 250
    onTriggered: root.applyDemoState()
  }

  // Safety net for both a hung git process and a missing `git` executable:
  // Quickshell's Process type exposes no "failed to start" signal to QML
  // (only `exited`, which never fires if the program can't launch at all),
  // so an unresponsive/absent git falls back to this bounded timeout rather
  // than hanging indefinitely. See FORGE_SPEC.md "Safe behavior when
  // dependencies are missing".
  Timer {
    id: branchTimeout
    interval: 5000
    onTriggered: if (branchProcess.running) {
      root.branchTimedOut = true
      branchProcess.running = false
      root.branch = ""
      root.branchKnown = false
      root.projectMissing = true
      root.lastRefreshMs = Date.now()
      root.recomputeState()
    }
  }

  Process {
    id: branchProcess
    running: false
    command: []
    stdout: StdioCollector { id: branchOut; waitForEnd: true }
    stderr: StdioCollector { id: branchErr; waitForEnd: true }
    onExited: function(exitCode) {
      branchTimeout.stop()
      if (root.branchTimedOut) return
      if (exitCode === 0) {
        root.branch = String(branchOut.text || "").trim()
        root.branchKnown = true
        root.projectMissing = false
      } else {
        root.branch = ""
        root.branchKnown = false
        root.projectMissing = true
      }
      root.lastRefreshMs = Date.now()
      root.recomputeState()
    }
  }

  FileView {
    id: configFile
    path: root.projectPath !== "" ? root.projectPath + "/.omaforge/services.json" : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyConfigText(text())
    onLoadFailed: root.applyConfigText("")
  }
}
