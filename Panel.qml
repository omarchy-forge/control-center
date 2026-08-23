import QtQuick
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

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() { dataService.refresh() }
  function setDemoState(state) { return dataService.setDemoState(state) }

  onOpenedChanged: if (opened) {
    dataService.refreshIfStale()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  DataService {
    id: dataService
    settings: root.settings
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
    tooltipText: dataService.loading ? "Refreshing Omaforge Local Control Center" : "Omaforge Local Control Center"
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
    contentWidth: popout.fittedContentWidth(Style.space(360))
    contentHeight: popout.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.refresh()
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Omaforge Local Control Center"
          meta: dataService.statusLabel
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

        PanelSeparator { foreground: root.foreground }

        LoadingState {
          visible: dataService.state === "loading"
          width: parent.width
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        EmptyState {
          visible: dataService.state === "empty"
          width: parent.width
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ErrorState {
          visible: dataService.state === "error"
          width: parent.width
          message: dataService.lastError
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        DetailsPopout {
          visible: dataService.state === "ready"
          width: parent.width
          value: dataService.value
          updatedAt: dataService.updatedAt
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Button {
          width: parent.width
          text: dataService.loading ? "Refreshing…" : "Refresh"
          iconText: "󰑐"
          foreground: root.foreground
          fontFamily: root.fontFamily
          focusable: true
          hasCursor: keyCatcher.activeFocus
          enabled: !dataService.loading
          onClicked: root.refresh()
        }

        Text {
          width: parent.width
          text: "Press R or Enter to refresh · Esc to close"
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
