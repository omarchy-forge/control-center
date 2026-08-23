import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Scrollable, plain-text (never interpreted) log viewer for the selected
// service, with a header naming it and a Clear action.
Column {
  id: root

  property string title: "LOGS"
  property var lines: [] // [{ text, stream }]
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property bool hasCursorRing: false

  signal clearRequested()

  spacing: Style.space(6)

  Row {
    width: parent.width
    height: header.implicitHeight

    PanelSectionHeader {
      id: header
      text: root.title
      foreground: root.foreground
      fontFamily: root.fontFamily
    }

    Item {
      width: Math.max(0, parent.width - header.implicitWidth - clearText.implicitWidth)
      height: 1
    }

    Text {
      id: clearText
      text: "Clear"
      textFormat: Text.PlainText
      color: root.lines.length > 0 ? root.foreground : Qt.darker(root.foreground, 2.0)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.underline: clearArea.containsMouse && root.lines.length > 0

      MouseArea {
        id: clearArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.lines.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.lines.length > 0
        onClicked: root.clearRequested()
      }
    }
  }

  Rectangle {
    width: parent.width
    height: Style.space(230)
    radius: Style.cornerRadius
    color: Qt.darker(Color.background, 1.28)
    border.width: root.hasCursorRing ? Style.hoverBorderWidth : Style.normalBorderWidth
    border.color: root.hasCursorRing ? Style.hoverBorderColor : Style.normalBorderColor

    Text {
      visible: root.lines.length === 0
      anchors.centerIn: parent
      text: "No log output yet."
      textFormat: Text.PlainText
      color: Qt.darker(root.foreground, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    ListView {
      id: logList
      visible: root.lines.length > 0
      anchors.fill: parent
      anchors.margins: Style.space(8)
      clip: true
      model: root.lines
      spacing: Style.space(1)
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      delegate: Text {
        required property var modelData
        width: logList.width
        text: modelData.text
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: modelData.stream === "err" ? Color.urgent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      onCountChanged: Qt.callLater(function() { logList.positionViewAtEnd() })
    }
  }
}
