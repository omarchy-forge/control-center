import QtQuick

// Fixed-size pool of managed process slots, keyed by service id. Slots are
// declared once (via Repeater over a constant integer) so editing
// .omaforge/services.json and reloading the displayed list never recreates
// (and thereby orphans) a process that is already running.
Item {
  id: root

  readonly property int capacity: 16
  property var assignments: ({}) // serviceId -> slot index
  property int generation: 0

  function slotItem(id) {
    generation // dependency touch: re-evaluate callers when assignments change
    var idx = assignments[id]
    if (idx === undefined) return null
    return repeater.itemAt(idx)
  }

  function ensureSlot(id) {
    if (assignments[id] !== undefined) return assignments[id]
    var used = {}
    for (var key in assignments) used[assignments[key]] = true
    for (var i = 0; i < capacity; i++) {
      if (used[i]) continue
      var next = Object.assign({}, assignments)
      next[id] = i
      assignments = next
      generation++
      var item = repeater.itemAt(i)
      if (item) item.assign(id)
      return i
    }
    return -1
  }

  function start(id, command, cwd) {
    var idx = ensureSlot(id)
    if (idx < 0) return false
    repeater.itemAt(idx).start(command, cwd)
    return true
  }

  function stop(id) {
    var item = slotItem(id)
    if (item) item.stop()
  }

  function restart(id, command, cwd) {
    var idx = ensureSlot(id)
    if (idx < 0) return false
    repeater.itemAt(idx).restart(command, cwd)
    return true
  }

  function stateFor(id) {
    var item = slotItem(id)
    return item ? item.procState : "stopped"
  }

  function lastErrorFor(id) {
    var item = slotItem(id)
    return item ? item.lastError : ""
  }

  function logsFor(id) {
    var item = slotItem(id)
    return item ? item.logLines : []
  }

  function clearLogsFor(id) {
    var item = slotItem(id)
    if (item) item.clearLogs()
  }

  function runningCount(ids) {
    var count = 0
    for (var i = 0; i < ids.length; i++) if (stateFor(ids[i]) === "running") count++
    return count
  }

  function stopAll(ids) {
    for (var i = 0; i < ids.length; i++) stop(ids[i])
  }

  function runAll(services) {
    for (var i = 0; i < services.length; i++) {
      var svc = services[i]
      if (stateFor(svc.id) !== "running") start(svc.id, svc.command, svc.cwd)
    }
  }

  Repeater {
    id: repeater
    model: root.capacity
    delegate: ProcessSlot {}
  }
}
