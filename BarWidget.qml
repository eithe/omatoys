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
  property int escapeCount: 0

  // Filter state, as reported by systemd.
  property bool keyFilterEnabled: false
  property bool keyFilterHealthy: true
  property bool keyFilterBusy: false
  property bool clickFilterEnabled: false
  property bool clickFilterHealthy: true
  property bool clickFilterBusy: false
  property bool focusMouseEnabled: true
  property bool focusMouseBusy: false

  // Last failure, shown at the bottom of the menu until it is superseded.
  property string statusMessage: ""

  // True once the privileged helper has been copied into a root-owned
  // directory, which happens the first time a filter is enabled.
  property bool filtersStaged: false

  readonly property string stagedInstaller: "/usr/local/lib/omatoys/install-filter-service.sh"
  readonly property string pluginInstaller: root.scriptPath("tools/install-filter-service.sh")
  readonly property string focusMouseToggle: root.scriptPath("tools/focus-follows-mouse/toggle.sh")
  readonly property bool opened: menuOpen
  readonly property bool popoutSwitchClosing: false

  // Prefer the root-owned copy. The plugin directory is writable by the user,
  // so running it as root is only acceptable for the one-time bootstrap; once
  // a staged copy exists it is the only thing this widget will elevate.
  readonly property string filterInstaller: root.filtersStaged
    ? root.stagedInstaller
    : root.pluginInstaller

  // Qt.resolvedUrl percent-encodes the path, so a plugin installed under a
  // directory with spaces would otherwise produce an unusable command.
  function scriptPath(relative: string): string {
    return decodeURIComponent(Qt.resolvedUrl(relative).toString().replace(/^file:\/\//, ""))
  }

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

  function reportFailure(label: string, exitCode: int, details: string) {
    // pkexec exits 126 when the authentication dialog is dismissed, which is a
    // deliberate user action rather than something worth reporting as an error.
    if (exitCode === 126) {
      root.statusMessage = ""
      return
    }
    const trimmed = details ? details.trim().split("\n").pop() : ""
    root.statusMessage = trimmed
      ? `${label} failed: ${trimmed}`
      : `${label} failed (exit ${exitCode})`
  }

  function toggleKeyFilter() {
    if (keyFilterBusy) return
    keyFilterBusy = true
    statusMessage = ""
    keyFilterAction.command = keyFilterEnabled
      ? ["pkexec", "systemctl", "disable", "--now", "omatoys-key-filter.service"]
      : ["pkexec", "bash", root.filterInstaller, "key"]
    keyFilterAction.running = true
  }

  function toggleClickFilter() {
    if (clickFilterBusy) return
    clickFilterBusy = true
    statusMessage = ""
    clickFilterAction.command = clickFilterEnabled
      ? ["pkexec", "systemctl", "disable", "--now", "omatoys-click-filter.service"]
      : ["pkexec", "bash", root.filterInstaller, "click"]
    clickFilterAction.running = true
  }

  function toggleFocusMouse() {
    if (focusMouseBusy) return
    focusMouseBusy = true
    statusMessage = ""
    focusMouseAction.command = ["bash", root.focusMouseToggle, root.focusMouseEnabled ? "off" : "on"]
    focusMouseAction.running = true
  }

  // Parses `systemctl show` key=value output into a plain object.
  function parseUnitStatus(text: string): var {
    const status = {}
    for (const line of text.split("\n")) {
      const split = line.indexOf("=")
      if (split > 0) status[line.slice(0, split)] = line.slice(split + 1).trim()
    }
    return status
  }

  function unitStatusCommand(unit: string): var {
    return ["systemctl", "show", unit, "--property=ActiveState", "--property=UnitFileState"]
  }

  function refreshFilterStates() {
    keyFilterState.command = root.unitStatusCommand("omatoys-key-filter.service")
    keyFilterState.running = true
    clickFilterState.command = root.unitStatusCommand("omatoys-click-filter.service")
    clickFilterState.running = true
    focusMouseState.command = ["bash", root.focusMouseToggle, "status"]
    focusMouseState.running = true
    stagedState.command = ["test", "-x", root.stagedInstaller]
    stagedState.running = true
  }

  // A single row in the menu: icon, title, subtitle, and an optional switch.
  // Rows without `checkable` act as plain buttons.
  component ToolRow: BorderSurface {
    id: rowRoot

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checkable: false
    property bool checked: false
    property bool busy: false
    signal activated()

    readonly property int iconWidth: Style.space(24)
    readonly property int switchWidth: Style.space(42)

    width: parent ? parent.width : 0
    height: Style.space(56)
    radius: Style.cornerRadius
    opacity: rowRoot.busy ? 0.6 : 1.0
    color: rowMouse.containsMouse
      ? Style.hoverFillFor(Color.popups.text, Color.accent)
      : Style.normalFillFor(Color.popups.text, Color.accent)
    borderSpec: rowMouse.containsMouse
      ? Border.controlSpec("hover-cursor", Color.popups.text, Color.accent)
      : Border.controlSpec("normal", Color.popups.text, Color.accent)

    Behavior on opacity { NumberAnimation { duration: 120 } }

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(12)

      Text {
        width: rowRoot.iconWidth
        text: rowRoot.icon
        color: Color.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.icon
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
      }

      Column {
        // Row padding plus spacing consumes two gaps either side of the label.
        width: parent.width - rowRoot.iconWidth - Style.space(24) -
          (rowRoot.checkable ? rowRoot.switchWidth + Style.space(12) : 0)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          text: rowRoot.title
          width: parent.width
          elide: Text.ElideRight
          color: Color.popups.text
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
        }

        Text {
          text: rowRoot.subtitle
          width: parent.width
          elide: Text.ElideRight
          color: Qt.lighter(Color.muted, 1.25)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Item {
        width: rowRoot.switchWidth
        height: Style.space(24)
        visible: rowRoot.checkable
        anchors.verticalCenter: parent.verticalCenter

        BorderSurface {
          anchors.fill: parent
          radius: height / 2
          color: rowRoot.checked
            ? Style.selectedFillFor(Color.popups.text, Color.accent)
            : Style.normalFillFor(Color.popups.text, Color.accent)
          borderSpec: Border.controlSpec(
            rowRoot.checked ? "selected" : "normal",
            Color.popups.text,
            Color.accent)

          Rectangle {
            width: Style.space(16)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: rowRoot.checked ? parent.width - width - Style.space(4) : Style.space(4)
            color: rowRoot.checked ? Color.accent : Color.muted
            Behavior on x { NumberAnimation { duration: 120 } }
          }
        }
      }
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: !rowRoot.busy
      cursorShape: Qt.PointingHandCursor
      onClicked: rowRoot.activated()
    }
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

      ToolRow {
        icon: "󰃢"
        title: "Cleaning Mode"
        subtitle: "Lock input while wiping your keyboard"
        onActivated: root.startCleaning()
      }

      ToolRow {
        icon: "󰍹"
        title: "Focus follows mouse"
        checkable: true
        checked: root.focusMouseEnabled
        busy: root.focusMouseBusy
        subtitle: root.focusMouseEnabled
          ? "On - pointer focuses windows"
          : "Off - windows stay focused"
        onActivated: root.toggleFocusMouse()
      }

      ToolRow {
        icon: "󰌌"
        title: "Key filter"
        checkable: true
        checked: root.keyFilterEnabled
        busy: root.keyFilterBusy
        subtitle: !root.keyFilterEnabled
          ? "Off - filter is disabled"
          : root.keyFilterHealthy
            ? "On - filters double presses"
            : "Enabled, but the service is not running"
        onActivated: root.toggleKeyFilter()
      }

      ToolRow {
        icon: "󰍽"
        title: "Click filter"
        checkable: true
        checked: root.clickFilterEnabled
        busy: root.clickFilterBusy
        subtitle: !root.clickFilterEnabled
          ? "Off - filter is disabled"
          : root.clickFilterHealthy
            ? "On - filters rapid extra clicks"
            : "Enabled, but the service is not running"
        onActivated: root.toggleClickFilter()
      }

      Text {
        width: parent.width
        visible: root.statusMessage !== ""
        text: root.statusMessage
        wrapMode: Text.WordWrap
        color: Color.accent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  Process {
    id: keyFilterAction
    stderr: StdioCollector { id: keyFilterActionErr }
    onExited: function(exitCode) {
      root.keyFilterBusy = false
      if (exitCode !== 0) root.reportFailure("Key filter", exitCode, keyFilterActionErr.text)
      root.refreshFilterStates()
    }
  }

  Process {
    id: clickFilterAction
    stderr: StdioCollector { id: clickFilterActionErr }
    onExited: function(exitCode) {
      root.clickFilterBusy = false
      if (exitCode !== 0) root.reportFailure("Click filter", exitCode, clickFilterActionErr.text)
      root.refreshFilterStates()
    }
  }

  Process {
    id: focusMouseAction
    stderr: StdioCollector { id: focusMouseActionErr }
    onExited: function(exitCode) {
      root.focusMouseBusy = false
      if (exitCode !== 0) root.reportFailure("Focus follows mouse", exitCode, focusMouseActionErr.text)
      root.refreshFilterStates()
    }
  }

  Process {
    id: keyFilterState
    stdout: StdioCollector {
      onStreamFinished: {
        const status = root.parseUnitStatus(text)
        root.keyFilterEnabled = status.UnitFileState === "enabled"
        root.keyFilterHealthy = status.ActiveState === "active"
      }
    }
  }

  Process {
    id: clickFilterState
    stdout: StdioCollector {
      onStreamFinished: {
        const status = root.parseUnitStatus(text)
        root.clickFilterEnabled = status.UnitFileState === "enabled"
        root.clickFilterHealthy = status.ActiveState === "active"
      }
    }
  }

  Process {
    id: focusMouseState
    stdout: StdioCollector {
      onStreamFinished: root.focusMouseEnabled = text.trim() === "enabled"
    }
  }

  Process {
    id: stagedState
    onExited: function(exitCode) {
      root.filtersStaged = exitCode === 0
    }
  }

  Component.onCompleted: refreshFilterStates()

  CleaningMode {
    id: cleaningPanel
    active: root.cleaningMode
    escapeCount: root.escapeCount
    hostScreen: button.QsWindow.window ? button.QsWindow.window.screen : null
    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    layerNamespace: root.moduleName.replace(/\./g, "-") + "-cleaning"
    onEscapePressed: {
      root.escapeCount += 1
      if (root.escapeCount >= 5) root.stopCleaning()
    }
  }
}
