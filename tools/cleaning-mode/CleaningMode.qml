import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Scope {
  id: root

  property bool active: false
  property int escapeCount: 0
  // The screen that owns keyboard focus. Every other screen is still covered,
  // so the pointer cannot reach a window on a second monitor.
  property var hostScreen: null
  property string fontFamily: Style.font.family
  property string layerNamespace: "omatoys-cleaning"
  signal escapePressed()

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      // Exactly one panel takes keyboard focus: the one on the bar's screen,
      // or the first screen when that is unknown.
      readonly property bool focusOwner: root.hostScreen
        ? modelData === root.hostScreen
        : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]

      screen: modelData
      visible: root.active
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.namespace: root.layerNamespace
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: root.active && panel.focusOwner
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
        focus: root.active && panel.focusOwner
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.escapePressed()
          }
          event.accepted = true
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: function(mouse) { mouse.accepted = true }
        onClicked: function(mouse) { mouse.accepted = true }
      }

      BorderSurface {
        id: card
        anchors.centerIn: parent
        width: Style.space(440)
        height: Style.space(250)
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Style.space(2))
        padding: Style.space(28)

        Column {
          anchors.fill: parent
          spacing: Style.space(14)

          Text {
            text: "󰃢"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.displayLarge
            anchors.horizontalCenter: parent.horizontalCenter
          }

          Text {
            text: "Keyboard locked for cleaning"
            color: Color.popups.text
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
          }

          Text {
            text: "Press Escape five times to exit"
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
          }

          Item {
            width: parent.width
            height: Style.space(34)

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)

              Repeater {
                model: 5

                delegate: BorderSurface {
                  required property int index

                  width: Style.space(36)
                  height: Style.space(30)
                  radius: Style.spacing.labelGap
                  color: index < root.escapeCount
                    ? Style.selectedFillFor(Color.popups.text, Color.accent)
                    : Style.normalFillFor(Color.popups.text, Color.accent)
                  borderSpec: Border.controlSpec(
                    index < root.escapeCount ? "selected" : "normal",
                    Color.popups.text,
                    Color.accent)

                  Text {
                    anchors.centerIn: parent
                    text: "Esc"
                    color: index < root.escapeCount ? Color.accent : Color.popups.text
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }
        }
      }

      onVisibleChanged: {
        if (visible && panel.focusOwner) {
          Qt.callLater(function() { focusTarget.forceActiveFocus() })
        }
      }
    }
  }
}
