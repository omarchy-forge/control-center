import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// One row in the services list: status dot, name + configured command,
// url-or-status text, and per-state action buttons (Start, or
// Logs-select/Restart/Stop).
//
// `hasCursor`, `current`, and `foreground` come from the CursorSurface base
// (set by the caller); do not redeclare them here.
CursorSurface {
  id: root

  property var service: null
  property string procState: "stopped" // stopped | running | error
  property bool selected: false
  property bool interactive: true
  property string fontFamily: Style.font.family

  readonly property color dotColor: root.procState === "running" ? Color.accent
    : root.procState === "error" ? Color.urgent
    : Qt.darker(root.foreground, 1.7)
  readonly property string statusText: root.procState === "running"
    ? (root.service && root.service.url !== "" ? root.service.url : "running")
    : root.procState === "error" ? "error"
    : "stopped"

  signal selectRequested()
  signal startRequested()
  signal stopRequested()
  signal restartRequested()

  current: root.selected
  implicitHeight: contentRow.implicitHeight + Style.spacing.rowPaddingX

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.selectRequested()
    onClicked: root.selectRequested()
  }

  RowLayout {
    id: contentRow
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    spacing: Style.space(8)

    Rectangle {
      width: Style.space(8)
      height: Style.space(8)
      radius: width / 2
      color: root.dotColor
      Layout.alignment: Qt.AlignVCenter
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(1)

      Text {
        Layout.fillWidth: true
        text: root.service ? root.service.name : ""
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        Layout.fillWidth: true
        text: root.service ? root.service.command.join(" ") : ""
        textFormat: Text.PlainText
        color: Qt.darker(root.foreground, 1.45)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Text {
      text: root.statusText
      textFormat: Text.PlainText
      color: root.procState === "error" ? Color.urgent : Qt.darker(root.foreground, 1.2)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      Layout.maximumWidth: Style.space(140)
      Layout.alignment: Qt.AlignVCenter
    }

    RowLayout {
      visible: root.interactive
      spacing: Style.space(4)
      Layout.alignment: Qt.AlignVCenter

      Button {
        visible: root.procState !== "running"
        text: "Start"
        foreground: root.foreground
        fontFamily: root.fontFamily
        bordered: true
        onClicked: root.startRequested()
      }

      PanelActionButton {
        visible: root.procState === "running"
        iconText: "↻"
        tooltipText: "Restart"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.restartRequested()
      }

      PanelActionButton {
        visible: root.procState === "running"
        iconText: "■"
        tooltipText: "Stop"
        foreground: root.foreground
        fontFamily: root.fontFamily
        hoverColor: Color.urgent
        onClicked: root.stopRequested()
      }
    }
  }
}
