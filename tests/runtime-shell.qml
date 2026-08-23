import QtQuick
import Quickshell
import "Plugin" as Plugin

ShellRoot {
  id: root

  function fail(message) {
    console.error("OMAFORGE_RUNTIME_FAIL=" + message)
  }

  function inspectPlugin() {
    if (typeof plugin.close !== "function") {
      fail("entry point has no close function")
      return
    }
    if (!isFinite(plugin.implicitWidth) || !isFinite(plugin.implicitHeight)) {
      fail("entry point has non-finite implicit geometry")
      return
    }
    plugin.settings = ({})
    var state = Quickshell.env("OMAFORGE_DEV_STATE") || ""
    if (state !== "") {
      if (typeof plugin.setDemoState !== "function") {
        fail("entry point has no setDemoState function")
        return
      }
      if (plugin.setDemoState(state) !== "ok") {
        fail("entry point rejected demo state " + state)
        return
      }
      plugin.open()
      settleTimer.start()
      return
    }
    if (typeof plugin.refresh !== "function") {
      fail("entry point has no refresh function")
      return
    }
    plugin.refresh()
    finish()
  }

  function finish() {
    var screenshot = Quickshell.env("OMAFORGE_SCREENSHOT_PATH") || ""
    if (screenshot !== "") {
      var target = plugin.forgeScreenshotTarget
      if (!target || typeof target.grabToImage !== "function") {
        fail("entry point has no forgeScreenshotTarget item")
        return
      }
      var width = Math.max(1, Math.ceil(target.width || target.implicitWidth || 1))
      var height = Math.max(1, Math.ceil(target.height || target.implicitHeight || 1))
      target.grabToImage(function(result) {
        if (!result || !result.saveToFile(screenshot)) {
          fail("could not save plugin screenshot")
          return
        }
        plugin.close()
        console.log("OMAFORGE_RUNTIME_PASS")
      }, Qt.size(width, height))
      return
    }
    plugin.close()
    console.log("OMAFORGE_RUNTIME_PASS")
  }

  Plugin.Panel {
    id: plugin
  }

  Timer {
    interval: 250
    running: true
    onTriggered: root.inspectPlugin()
  }

  Timer {
    id: settleTimer
    interval: 750
    onTriggered: root.finish()
  }
}
