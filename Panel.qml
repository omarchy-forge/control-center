import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui
import "components"
import "services"

Panel {
  id: root
  moduleName: "omaforge.control.center"
  ipcTarget: "omaforge.control.center"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property Item forgeScreenshotTarget: content

  property string focusPane: "services" // services | logs
  property int selectedIndex: 0
  property bool cursorActive: false

  readonly property var services: projectService.services
  readonly property bool isDemo: projectService.demoState !== ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() { projectService.refresh() }
  function setDemoState(state) { return projectService.setDemoState(state) }

  function idsOf(list) {
    var out = []
    for (var i = 0; i < list.length; i++) out.push(list[i].id)
    return out
  }

  function statusFor(service) {
    if (!service) return "stopped"
    if (root.isDemo) return service.demoStatus || "stopped"
    return pool.stateFor(service.id)
  }

  function logsFor(service) {
    if (!service) return []
    if (root.isDemo) return projectService.demoLogsFor(service.id)
    return pool.logsFor(service.id)
  }

  function runningCount() {
    if (root.isDemo) {
      var count = 0
      for (var i = 0; i < services.length; i++) if ((services[i].demoStatus || "stopped") === "running") count++
      return count
    }
    return pool.runningCount(idsOf(services))
  }

  function selectedService() {
    if (services.length === 0) return null
    var idx = Math.max(0, Math.min(selectedIndex, services.length - 1))
    return services[idx]
  }

  function ensureSelection() {
    if (services.length === 0) { selectedIndex = 0; return }
    if (selectedIndex >= services.length) selectedIndex = services.length - 1
    if (selectedIndex < 0) selectedIndex = 0
  }

  onServicesChanged: ensureSelection()

  function selectIndex(index) {
    cursorActive = true
    focusPane = "services"
    selectedIndex = index
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    if (dx !== 0) {
      focusPane = dx > 0 ? "logs" : "services"
      return
    }
    if (focusPane !== "services" || services.length === 0) return
    selectedIndex = Math.max(0, Math.min(services.length - 1, selectedIndex + dy))
  }

  function activateCursor() {
    cursorActive = true
    if (focusPane !== "services" || root.isDemo) return
    var svc = selectedService()
    if (svc && svc.url !== "") root.openUrl(svc.url)
  }

  function openUrl(url) {
    if (!/^https?:\/\//.test(url)) return
    openProcess.command = ["xdg-open", url]
    openProcess.running = true
    openTimeout.restart()
  }

  function restartSelected() {
    if (root.isDemo) return
    var svc = selectedService()
    if (svc) pool.restart(svc.id, svc.command, svc.cwd)
  }

  function stopSelected() {
    if (root.isDemo) return
    var svc = selectedService()
    if (svc) pool.stop(svc.id)
  }

  function runAllServices() { if (!root.isDemo) pool.runAll(services) }
  function stopAllServices() { if (!root.isDemo) pool.stopAll(idsOf(services)) }

  function emptyMessage() {
    if (projectService.emptyReason === "no-project") {
      return "No project directory configured. Set this widget's \"Project directory\" setting to a local git project. Add another instance of this widget for each additional project you want to monitor."
    }
    var name = projectService.displayProjectName !== "" ? projectService.displayProjectName : "this project"
    if (projectService.emptyReason === "invalid") {
      return "Could not read " + projectService.configRelPath + " in " + name + ": " + projectService.configParseError
    }
    return "No " + projectService.configRelPath + " found in " + name + ". Create it to list the dev services you want to start, stop, and watch here, e.g.:\n"
      + "{\"services\":[{\"id\":\"web\",\"name\":\"Web\",\"command\":[\"pnpm\",\"dev\"],\"url\":\"http://localhost:3000\"}]}"
  }

  onOpenedChanged: if (opened) {
    projectService.refreshIfStale()
    cursorActive = false
    focusPane = "services"
    ensureSelection()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  ProjectService {
    id: projectService
    settings: root.settings
  }

  ProcessPool {
    id: pool
  }

  Process {
    id: openProcess
    running: false
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
  }

  Timer {
    id: openTimeout
    interval: 5000
    onTriggered: if (openProcess.running) openProcess.running = false
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
    function setDemoState(state: string): string { return root.setDemoState(state) }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰔟"
    active: root.opened
    tooltipText: projectService.loading
      ? "Refreshing Omaforge Local Control Center"
      : projectService.status === "error"
        ? "Omaforge Local Control Center — needs attention"
        : projectService.status === "ready"
          ? "Omaforge Local Control Center — " + root.runningCount() + " running"
          : "Omaforge Local Control Center"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: popout
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popout.fittedContentWidth(Style.space(380))
    contentHeight: popout.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onDeleteRequested: root.stopSelected()
      onTextKey: function(text) {
        if (text === "r") {
          if (root.focusPane === "services" && root.selectedService() && !root.isDemo) root.restartSelected()
          else root.refresh()
        } else if (text === "R") {
          root.refresh()
        }
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: content
        width: panelFlick.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: projectService.displayProjectName !== "" ? projectService.displayProjectName : "Omaforge Local Control Center"
          meta: projectService.status === "error" ? "Needs attention"
            : projectService.status === "empty" ? "No services"
            : projectService.status === "loading" ? "Loading"
            : "Updated locally"
          detail: projectService.status === "ready" ? (root.runningCount() + " running") : ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "󰔟"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Text {
          visible: projectService.displayPath !== "" && (projectService.status === "ready" || projectService.status === "empty")
          width: parent.width
          text: "⎇ " + (projectService.branchKnown || root.isDemo ? projectService.branch : "unknown") + "  ·  " + projectService.displayPath
          textFormat: Text.PlainText
          color: Qt.darker(root.foreground, 1.45)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        PanelSeparator { foreground: root.foreground }

        LoadingState {
          visible: projectService.status === "loading"
          width: parent.width
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        EmptyState {
          visible: projectService.status === "empty"
          width: parent.width
          message: root.emptyMessage()
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ErrorState {
          visible: projectService.status === "error"
          width: parent.width
          message: projectService.lastError
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Column {
          visible: projectService.status === "ready"
          width: parent.width
          spacing: Style.space(10)

          Text {
            visible: projectService.refreshWarning !== ""
            width: parent.width
            text: projectService.refreshWarning
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Button {
              text: "Run all"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              enabled: !root.isDemo
              onClicked: root.runAllServices()
            }
            Button {
              text: "Stop all"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              enabled: !root.isDemo
              onClicked: root.stopAllServices()
            }
          }

          Column {
            id: servicesColumn
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: root.services
              ServiceRow {
                required property var modelData
                required property int index
                width: servicesColumn.width
                service: modelData
                procState: root.statusFor(modelData)
                selected: root.selectedIndex === index
                hasCursor: root.cursorActive && root.focusPane === "services" && root.selectedIndex === index
                interactive: !root.isDemo
                foreground: root.foreground
                fontFamily: root.fontFamily
                onSelectRequested: root.selectIndex(index)
                onStartRequested: { root.selectIndex(index); pool.start(modelData.id, modelData.command, modelData.cwd) }
                onRestartRequested: { root.selectIndex(index); pool.restart(modelData.id, modelData.command, modelData.cwd) }
                onStopRequested: { root.selectIndex(index); pool.stop(modelData.id) }
              }
            }
          }

          Text {
            visible: projectService.configSkipped.length > 0
            width: parent.width
            text: projectService.configSkipped.length + " entr" + (projectService.configSkipped.length === 1 ? "y" : "ies")
              + " in " + projectService.configRelPath + " could not be shown; see README for the schema."
            textFormat: Text.PlainText
            color: Qt.darker(root.foreground, 1.3)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.foreground }

          LogPanel {
            width: parent.width
            title: (root.selectedService() ? root.selectedService().name.toUpperCase() : "SELECTED") + " LOGS"
            lines: root.logsFor(root.selectedService())
            hasCursorRing: root.cursorActive && root.focusPane === "logs"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClearRequested: if (!root.isDemo && root.selectedService()) pool.clearLogsFor(root.selectedService().id)
          }
        }

        Text {
          width: parent.width
          text: "j/k Navigate · h/l Focus · Enter Open · r Restart · x Stop · Esc Close"
          textFormat: Text.PlainText
          color: Qt.darker(root.foreground, 1.45)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }
      }
    }
  }
}
