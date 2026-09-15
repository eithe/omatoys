import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "local.omatoys"

  property bool cleaningMode: false
  property bool menuOpen: false
  property bool keyFilterEnabled: false
  property bool clickFilterEnabled: false
  property int escapeCount: 0

  function startCleaning() {
    menuOpen = false
    escapeCount = 0
    cleaningMode = true
  }

  function stopCleaning() {
    cleaningMode = false
    escapeCount = 0
  }

  function close() {
    menuOpen = false
  }

  function toggleKeyFilter() {
    keyFilterAction.command = ["pkexec", "systemctl", keyFilterEnabled ? "disable" : "enable", "--now", "omatoys-key-filter.service"]
    keyFilterAction.running = true
  }

  function toggleClickFilter() {
    clickFilterAction.command = ["pkexec", "systemctl", clickFilterEnabled ? "disable" : "enable", "--now", "omatoys-click-filter.service"]
    clickFilterAction.running = true
  }

  function refreshFilterStates() {
    keyFilterState.command = ["systemctl", "is-enabled", "omatoys-key-filter.service"]
    keyFilterState.running = true
    clickFilterState.command = ["systemctl", "is-enabled", "omatoys-click-filter.service"]
    clickFilterState.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈸"
    tooltipText: "Omatoys"
    active: root.cleaningMode
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.menuOpen = !root.menuOpen
    }
  }

  PopupCard {
    id: menu
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.menuOpen
    contentWidth: menu.fittedContentWidth(Style.space(322))
    contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        text: "Omatoys"
        color: Color.popups.text
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        text: "Small tools for everyday work"
        color: Color.muted
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      BorderSurface {
        width: parent.width
        height: Style.space(56)
        radius: Style.cornerRadius
        color: toolMouse.containsMouse
          ? Style.hoverFillFor(Color.popups.text, Color.accent)
          : Style.normalFillFor(Color.popups.text, Color.accent)
        borderSpec: toolMouse.containsMouse
          ? Border.controlSpec("hover-cursor", Color.popups.text, Color.accent)
          : Border.controlSpec("normal", Color.popups.text, Color.accent)

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(12)

          Text {
            text: "󰃢"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.icon
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Cleaning Mode"
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }

            Text {
              text: "Lock input while wiping your keyboard"
              color: Qt.lighter(Color.muted, 1.25)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

          }
        }

        MouseArea {
          id: toolMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.startCleaning()
        }
      }

      BorderSurface {
        width: parent.width
        height: Style.space(56)
        radius: Style.cornerRadius
        color: filterToggle.containsMouse
          ? Style.hoverFillFor(Color.popups.text, Color.accent)
          : Style.normalFillFor(Color.popups.text, Color.accent)
        borderSpec: filterToggle.containsMouse
          ? Border.controlSpec("hover-cursor", Color.popups.text, Color.accent)
          : Border.controlSpec("normal", Color.popups.text, Color.accent)

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(12)

          Text {
            id: filterIcon
            width: Style.space(24)
            text: "󰌌"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.icon
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            id: filterText
            width: parent.width - filterIcon.width - filterSwitch.width - Style.space(24)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Key filter"
              width: parent.width
              elide: Text.ElideRight
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }

            Text {
              text: root.keyFilterEnabled ? "On - filters double presses" : "Off - filter is disabled"
              width: parent.width
              elide: Text.ElideRight
              color: Qt.lighter(Color.muted, 1.25)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Item {
            id: filterSwitch
            width: Style.space(42)
            height: Style.space(24)
            anchors.verticalCenter: parent.verticalCenter

            BorderSurface {
              anchors.fill: parent
              radius: height / 2
              color: root.keyFilterEnabled
                ? Style.selectedFillFor(Color.popups.text, Color.accent)
                : Style.normalFillFor(Color.popups.text, Color.accent)
              borderSpec: Border.controlSpec(
                root.keyFilterEnabled ? "selected" : "normal",
                Color.popups.text,
                Color.accent)

              Rectangle {
                width: Style.space(16)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: root.keyFilterEnabled ? parent.width - width - Style.space(4) : Style.space(4)
                color: root.keyFilterEnabled ? Color.accent : Color.muted
                Behavior on x { NumberAnimation { duration: 120 } }
              }
            }

          }
        }

        MouseArea {
          id: filterToggle
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleKeyFilter()
        }
      }

      BorderSurface {
        width: parent.width
        height: Style.space(56)
        radius: Style.cornerRadius
        color: clickToggle.containsMouse
          ? Style.hoverFillFor(Color.popups.text, Color.accent)
          : Style.normalFillFor(Color.popups.text, Color.accent)
        borderSpec: clickToggle.containsMouse
          ? Border.controlSpec("hover-cursor", Color.popups.text, Color.accent)
          : Border.controlSpec("normal", Color.popups.text, Color.accent)

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(12)

          Text {
            width: Style.space(24)
            text: "󰍽"
            color: Color.accent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.icon
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            width: parent.width - Style.space(24) - Style.space(42) - Style.space(24)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Click filter"
              width: parent.width
              elide: Text.ElideRight
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
            }

            Text {
              text: root.clickFilterEnabled ? "On - filters rapid extra clicks" : "Off - filter is disabled"
              width: parent.width
              elide: Text.ElideRight
              color: Qt.lighter(Color.muted, 1.25)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Item {
            width: Style.space(42)
            height: Style.space(24)
            anchors.verticalCenter: parent.verticalCenter

            BorderSurface {
              anchors.fill: parent
              radius: height / 2
              color: root.clickFilterEnabled
                ? Style.selectedFillFor(Color.popups.text, Color.accent)
                : Style.normalFillFor(Color.popups.text, Color.accent)
              borderSpec: Border.controlSpec(
                root.clickFilterEnabled ? "selected" : "normal",
                Color.popups.text,
                Color.accent)

              Rectangle {
                width: Style.space(16)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: root.clickFilterEnabled ? parent.width - width - Style.space(4) : Style.space(4)
                color: root.clickFilterEnabled ? Color.accent : Color.muted
                Behavior on x { NumberAnimation { duration: 120 } }
              }
            }
          }
        }

        MouseArea {
          id: clickToggle
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleClickFilter()
        }
      }
    }
  }

  Process {
    id: keyFilterAction
    onExited: if (exitCode === 0) root.refreshFilterStates()
  }

  Process {
    id: clickFilterAction
    onExited: if (exitCode === 0) root.refreshFilterStates()
  }

  Process {
    id: keyFilterState
    stdout: StdioCollector {
      onStreamFinished: root.keyFilterEnabled = text.trim() === "enabled"
    }
  }

  Process {
    id: clickFilterState
    stdout: StdioCollector {
      onStreamFinished: root.clickFilterEnabled = text.trim() === "enabled"
    }
  }

  Component.onCompleted: refreshFilterStates()

  PanelWindow {
    id: cleaningPanel
    screen: button.QsWindow.window ? button.QsWindow.window.screen : null
    visible: root.cleaningMode
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "local-omatoys-cleaning"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.cleaningMode
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
      focus: root.cleaningMode
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.escapeCount += 1
          if (root.escapeCount >= 5) root.stopCleaning()
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
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.displayLarge
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
          text: "Keyboard locked for cleaning"
          color: Color.popups.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
        }

        Text {
          text: "Press Escape five times to exit"
          color: Color.muted
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
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
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }
      }
    }

    onVisibleChanged: {
      if (visible) Qt.callLater(function() { focusTarget.forceActiveFocus() })
    }
  }
}
