import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "tools/cleaning-mode"

BarWidget {
  id: root
  moduleName: "io.github.eithe.omatoys"

  property bool cleaningMode: false
  property bool menuOpen: false
  property bool keyFilterEnabled: false
  property bool clickFilterEnabled: false
  property int escapeCount: 0
  readonly property string filterInstaller: Qt.resolvedUrl("install-filter-service.sh").toString().replace("file://", "")
  readonly property bool opened: menuOpen
  readonly property bool popoutSwitchClosing: false

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

  function open() {
    menuOpen = true
  }

  function toggle() {
    menuOpen = !menuOpen
  }

  function closeForPopoutSwitch() {
    close()
  }

  function toggleKeyFilter() {
    keyFilterAction.command = keyFilterEnabled
      ? ["pkexec", "systemctl", "disable", "--now", "omatoys-key-filter.service"]
      : ["pkexec", root.filterInstaller, "key"]
    keyFilterAction.running = true
  }

  function toggleClickFilter() {
    clickFilterAction.command = clickFilterEnabled
      ? ["pkexec", "systemctl", "disable", "--now", "omatoys-click-filter.service"]
      : ["pkexec", root.filterInstaller, "click"]
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
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  IpcHandler {
    target: root.moduleName

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
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

  CleaningMode {
    id: cleaningPanel
    active: root.cleaningMode
    escapeCount: root.escapeCount
    hostScreen: button.QsWindow.window ? button.QsWindow.window.screen : null
    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    onEscapePressed: {
      root.escapeCount += 1
      if (root.escapeCount >= 5) root.stopCleaning()
    }
  }
}
