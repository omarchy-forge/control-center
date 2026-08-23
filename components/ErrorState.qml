import QtQuick
import qs.Commons

Column {
  property string message: "Unknown error"
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  spacing: Style.space(4)

  Text {
    width: parent.width
    text: "Could not load data"
    color: Color.urgent
    font.family: parent.fontFamily
    font.pixelSize: Style.font.subtitle
    font.bold: true
  }
  Text {
    width: parent.width
    text: parent.message
    color: parent.foreground
    font.family: parent.fontFamily
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }
}
