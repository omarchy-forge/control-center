import QtQuick
import qs.Commons

Row {
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  spacing: Style.space(8)

  Text {
    text: "󰑐"
    color: parent.foreground
    font.family: parent.fontFamily
    font.pixelSize: Style.font.icon
    RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: true }
  }
  Text {
    text: "Loading local data…"
    color: parent.foreground
    font.family: parent.fontFamily
    font.pixelSize: Style.font.body
  }
}
