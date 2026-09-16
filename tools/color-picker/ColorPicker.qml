import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

PanelWindow {
  id: root

  property bool active: false
  property var hostScreen: null
  property string fontFamily: Style.font.family
  property string hex: ""
  property string rgb: ""
  property string hsl: ""
  signal copyRequested(string value)
  signal dismissed()

  screen: root.hostScreen
  visible: root.active
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  WlrLayershell.namespace: "omatoys-color-picker"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: root.active
    ? WlrKeyboardFocus.Exclusive
    : WlrKeyboardFocus.None

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  Item {
    id: focusTarget
    anchors.fill: parent
    focus: root.active
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) root.dismissed()
      event.accepted = true
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    onClicked: root.dismissed()
  }

  BorderSurface {
    id: card
    z: 1
    anchors.centerIn: parent
    width: Style.space(430)
    height: Style.space(270)
    radius: Style.cornerRadius
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Style.space(2))

    Column {
      anchors.fill: parent
      anchors.margins: Style.space(24)
      spacing: Style.space(10)

      Text {
        text: "Color picked"
        color: Color.popups.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Rectangle {
        width: parent.width
        height: Style.space(34)
        radius: Style.spacing.labelGap
        color: root.hex
      }

      Repeater {
        model: [
          { label: "HEX", value: root.hex },
          { label: "RGB", value: root.rgb },
          { label: "HSL", value: root.hsl },
        ]

        delegate: Row {
          required property var modelData
          width: parent.width
          height: Style.space(32)
          spacing: Style.space(10)

          Text {
            width: Style.space(38)
            text: modelData.label
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            width: parent.width - Style.space(102)
            text: modelData.value
            color: Color.popups.text
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
          }

          BorderSurface {
            width: Style.space(44)
            height: Style.space(28)
            radius: Style.spacing.labelGap
            color: copyMouse.containsMouse
              ? Style.hoverFillFor(Color.popups.text, Color.accent)
              : Style.normalFillFor(Color.popups.text, Color.accent)
            borderSpec: Border.controlSpec(
              copyMouse.containsMouse ? "hover-cursor" : "normal",
              Color.popups.text,
              Color.accent)

            Text {
              anchors.centerIn: parent
              text: "󰆏"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.icon
            }

            MouseArea {
              id: copyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.copyRequested(modelData.value)
            }
          }
        }
      }

      Text {
        text: "Press Escape to close"
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.horizontalCenter: parent.horizontalCenter
      }
    }
  }

  onVisibleChanged: {
    if (visible) Qt.callLater(function() { focusTarget.forceActiveFocus() })
  }
}
