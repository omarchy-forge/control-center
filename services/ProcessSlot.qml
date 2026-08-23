import QtQuick
import Quickshell.Io

// One reusable managed-process slot. A fixed pool of these (see
// ProcessPool.qml) is declared once in QML so that reloading the service
// configuration file never recreates (and thereby orphans/kills) an
// already-running process — only explicit start()/stop()/restart() calls
// touch the underlying Process.
Item {
  id: root

  property string serviceId: ""
  property string procState: "stopped" // stopped | running | error
  property string lastError: ""
  property int lastExitCode: -1
  property var logLines: [] // [{ text, stream }]
  readonly property int maxLogLines: 500
  readonly property bool running: process.running

  property var pendingCommand: []
  property string pendingCwd: ""
  property bool pendingRestart: false
  property bool intentionalStop: false

  signal logsChanged()

  function assign(id) {
    serviceId = id
  }

  function release() {
    pendingRestart = false
    serviceId = ""
    if (process.running) process.running = false
    logLines = []
    procState = "stopped"
    lastError = ""
  }

  function start(command, cwd) {
    if (process.running) return
    pendingRestart = false
    intentionalStop = false
    lastError = ""
    process.command = command
    process.workingDirectory = cwd
    process.running = true
  }

  function stop() {
    pendingRestart = false
    if (process.running) {
      intentionalStop = true
      process.running = false
    }
  }

  function restart(command, cwd) {
    if (process.running) {
      pendingRestart = true
      intentionalStop = true
      pendingCommand = command
      pendingCwd = cwd
      process.running = false
    } else {
      start(command, cwd)
    }
  }

  function clearLogs() {
    logLines = []
    logsChanged()
  }

  function appendLog(text, stream) {
    var next = logLines.concat([{ text: text, stream: stream }])
    if (next.length > maxLogLines) next = next.slice(next.length - maxLogLines)
    logLines = next
    logsChanged()
  }

  Process {
    id: process
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { root.appendLog(data, "out") }
    }
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(data) { root.appendLog(data, "err") }
    }
    onRunningChanged: {
      if (process.running) {
        root.procState = "running"
        root.lastError = ""
      }
    }
    onExited: function(exitCode, exitStatus) {
      root.lastExitCode = exitCode
      var crashed = exitStatus === 1 // QProcess::CrashExit
      if (root.pendingRestart) {
        root.pendingRestart = false
        root.intentionalStop = false
        var cmd = root.pendingCommand
        var cwd = root.pendingCwd
        Qt.callLater(function() { root.start(cmd, cwd) })
        return
      }
      // A user-requested Stop terminates the process with a signal, which
      // QProcess reports as a "crash" even though it was intentional — do
      // not surface that as an error status.
      if (root.intentionalStop) {
        root.intentionalStop = false
        root.procState = "stopped"
        return
      }
      if (crashed || exitCode !== 0) {
        root.procState = "error"
        root.lastError = crashed
          ? "Process was terminated"
          : "Exited with code " + exitCode
      } else {
        root.procState = "stopped"
      }
    }
  }
}
