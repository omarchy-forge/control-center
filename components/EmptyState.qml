import QtQuick
import qs.Commons

Text {
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  text: "No local data is available yet."
  color: Qt.darker(foreground, 1.35)
  font.family: fontFamily
  font.pixelSize: Style.font.body
  wrapMode: Text.WordWrap
}
