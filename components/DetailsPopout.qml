import QtQuick
import qs.Commons

Column {
  id: root
  property string value: ""
  property date updatedAt: new Date(0)
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  spacing: Style.space(6)

  Text {
    width: parent.width
    text: root.value
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.subtitle
    font.bold: true
    wrapMode: Text.WrapAnywhere
  }

  Text {
    width: parent.width
    text: root.updatedAt.getTime() > 0 ? "Updated " + root.updatedAt.toLocaleTimeString() : "Not updated yet"
    color: Qt.darker(root.foreground, 1.45)
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
