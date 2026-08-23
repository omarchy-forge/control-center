import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var settings: ({})
  property string state: "loading"
  property string value: ""
  property string lastError: ""
  property date updatedAt: new Date(0)
  property double lastRefreshMs: 0
  property bool timedOut: false
  property string output: ""
  readonly property bool loading: state === "loading"
  readonly property string statusLabel: state === "error" ? "Needs attention"
    : state === "empty" ? "No data"
    : state === "ready" ? "Updated locally"
    : "Loading"
  readonly property int refreshIntervalSec: boundedInteger("refreshIntervalSec", 60, 10, 3600)
  property string demoState: ""

  function setting(name, fallback) {
    var candidate = settings ? settings[name] : undefined
    return candidate === undefined || candidate === null ? fallback : candidate
  }

  function boundedInteger(name, fallback, minimum, maximum) {
    var candidate = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(candidate)) candidate = fallback
    return Math.max(minimum, Math.min(maximum, candidate))
  }

  function refreshIfStale() {
    if (Date.now() - lastRefreshMs >= refreshIntervalSec * 1000) refresh()
  }

  function setDemoState(nextState) {
    var candidate = String(nextState || "")
    if (candidate !== "ready" && candidate !== "empty" && candidate !== "error") return "invalid"
    demoState = candidate
    refresh()
    return "ok"
  }

  function refresh() {
    if (process.running) return
    state = "loading"
    value = ""
    lastError = ""
    timedOut = false
    output = ""

    if (demoState !== "") {
      demoTimer.restart()
      return
    }

    // Array-form arguments avoid shell interpolation. Replace `date` with the
    // local command your plugin documents, keeping this argument-safe shape.
    process.command = ["date", "--iso-8601=seconds"]
    process.running = true
    timeoutTimer.restart()
  }

  function applyDemoState() {
    if (demoState === "error") {
      state = "error"
      lastError = "Fictional demo error"
    } else if (demoState === "empty") {
      state = "empty"
    } else {
      state = "ready"
      value = "2026-08-22T12:00:00-04:00"
      updatedAt = new Date("2026-08-22T12:00:00-04:00")
    }
    lastRefreshMs = Date.now()
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

  Timer {
    id: timeoutTimer
    interval: 5000
    onTriggered: if (process.running) {
      root.timedOut = true
      process.running = false
      root.state = "error"
      root.lastError = "Local command timed out after 5 seconds"
      root.lastRefreshMs = Date.now()
    }
  }

  Process {
    id: process
    running: false
    command: []
    stdout: StdioCollector {
      id: stdoutCollector
      waitForEnd: true
      onStreamFinished: root.output = text
    }
    stderr: StdioCollector {
      id: stderrCollector
      waitForEnd: true
    }
    onExited: function(exitCode) {
      timeoutTimer.stop()
      if (root.timedOut) return
      root.lastRefreshMs = Date.now()
      if (exitCode !== 0) {
        root.state = "error"
        root.lastError = String(stderrCollector.text || "Local command failed").trim()
        return
      }
      var result = String(stdoutCollector.text || root.output).trim()
      if (result === "") {
        root.state = "empty"
        return
      }
      root.value = result
      root.updatedAt = new Date()
      root.state = "ready"
    }
  }
}
