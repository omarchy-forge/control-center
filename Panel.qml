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
  readonly property color brandOrange: "#ff5a00"
  readonly property color brandCyan: "#52e7f0"
  readonly property url brandIcon: Qt.resolvedUrl("references/omaforge-final-logo-300-app-icon.png")
  property Item forgeScreenshotTarget: content

  property string focusPane: "services" // services | logs
  property int selectedIndex: 0
  property bool cursorActive: false
  property string processFilter: "all"

  readonly property var allServices: projectService.services
  readonly property var services: filteredServices()
  readonly property bool isDemo: projectService.demoState !== ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() { projectService.refresh() }
  function setDemoState(state) { return projectService.setDemoState(state) }

  function filteredServices() {
    var out = []
    for (var i = 0; i < allServices.length; i++) {
      var process = allServices[i]
      if (processFilter === "all"
          || (processFilter === "system" && process.systemProcess)
          || (processFilter === "servers" && process.server)
          || (processFilter === "ports" && process.listening)
          || (processFilter === "apps" && !process.systemProcess && !process.server)) out.push(process)
    }
    return out
  }

  function setProcessFilter(nextFilter) {
    processFilter = nextFilter
    selectedIndex = 0
    cursorActive = false
  }

  function idsOf(list) {
    var out = []
    for (var i = 0; i < list.length; i++) out.push(list[i].id)
    return out
  }

  function statusFor(service) {
    return service ? (service.demoStatus || "running") : "stopped"
  }

  function logsFor(service) {
    if (!service) return []
    if (root.isDemo) return projectService.demoLogsFor(service.id)
    return projectService.demoLogsFor(service.id)
  }

  function runningCount() {
    if (root.isDemo) {
      var count = 0
      for (var i = 0; i < services.length; i++) if ((services[i].demoStatus || "stopped") === "running") count++
      return count
    }
    return services.length
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
    if (svc && !svc.protectedProcess) projectService.control("restart", svc.pid)
  }

  function stopSelected() {
    if (root.isDemo) return
    var svc = selectedService()
    if (svc && !svc.protectedProcess) projectService.control("stop", svc.pid)
  }

  function runAllServices() { root.refresh() }
  function stopAllServices() { root.stopSelected() }

  function emptyMessage() {
    return "No user-owned processes are currently visible."
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
    iconComponent: Component {
      Image {
        source: root.brandIcon
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
      }
    }
    active: root.opened
    tooltipText: projectService.refreshing
      ? "Refreshing omaforge-control-center"
      : projectService.status === "error"
        ? "omaforge-control-center — needs attention"
        : projectService.status === "ready"
          ? "omaforge-control-center — " + root.runningCount() + " running"
          : "omaforge-control-center"
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
    contentWidth: popout.fittedContentWidth(Style.space(500))
    contentHeight: popout.fittedContentHeight(content.implicitHeight, Style.space(720))

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

        RowLayout {
          width: parent.width
          spacing: Style.space(12)

          Image {
            source: root.brandIcon
            Layout.preferredWidth: Style.space(42)
            Layout.preferredHeight: Style.space(42)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }

          Text {
            text: "Process Center"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            Layout.fillWidth: true
          }

          Text {
            visible: projectService.status === "ready"
            text: root.services.length + "/" + root.allServices.length + " shown  ●"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            text: "×"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
          }
        }

        Rectangle {
          visible: projectService.displayPath !== "" && (projectService.status === "ready" || projectService.status === "empty")
          width: parent.width
          height: projectIdentity.implicitHeight + Style.space(20)
          radius: Style.cornerRadius
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025)
          border.width: Style.normalBorderWidth
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.24)

          Column {
            id: projectIdentity
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(12)
            spacing: Style.space(4)

            Text {
              width: parent.width
              text: projectService.displayProjectName
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: (projectService.branchKnown || root.isDemo ? projectService.branch : "unknown") + "  ●  " + projectService.displayPath
              color: Qt.darker(root.foreground, 1.35)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
            }
          }
        }

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
              text: "↻  Refresh"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              accent: root.brandOrange
              active: true
              Layout.fillWidth: true
              enabled: !root.isDemo
              onClicked: root.runAllServices()
            }
            Button {
              text: "■  Stop selected"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              accent: root.brandOrange
              Layout.fillWidth: true
              enabled: !root.isDemo && root.selectedService() && !root.selectedService().protectedProcess
              onClicked: root.stopAllServices()
            }
          }

          PanelSectionHeader {
            text: "PROCESSES"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          RowLayout {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: [
                {key: "all", label: "All"},
                {key: "apps", label: "Apps"},
                {key: "system", label: "System"},
                {key: "servers", label: "Servers"},
                {key: "ports", label: "Ports"}
              ]
              Button {
                required property var modelData
                text: modelData.label
                foreground: root.foreground
                fontFamily: root.fontFamily
                bordered: true
                selected: root.processFilter === modelData.key
                accent: root.brandOrange
                Layout.fillWidth: true
                onClicked: root.setProcessFilter(modelData.key)
              }
            }
          }

          Column {
            id: servicesColumn
            width: parent.width
            spacing: 0

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
                accent: root.brandOrange
                linkColor: root.brandCyan
                onSelectRequested: root.selectIndex(index)
                onStartRequested: { root.selectIndex(index); projectService.control("restart", modelData.pid) }
                onRestartRequested: { root.selectIndex(index); projectService.control("restart", modelData.pid) }
                onStopRequested: { root.selectIndex(index); projectService.control("stop", modelData.pid) }
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
            onClearRequested: {}
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
