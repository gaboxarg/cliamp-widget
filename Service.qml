import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string stateHome: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
  readonly property string statusFile: stateHome + "/cliamp-widget/status.json"
  readonly property string positionFile: stateHome + "/cliamp-widget/position.json"
  property var manifest: null
  readonly property string settingsFile: (manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : (Quickshell.env("HOME") + "/.config/omarchy/plugins/gabox.cliamp-now-playing")) + "/settings.json"

  // ---- track state ----
  property string title: ""
  property string artist: ""
  property string state: "stopped"
  property string artPath: ""
  property real position: 0
  property real duration: 0
  property real volume: 0

  readonly property bool playing: state === "playing"
  readonly property bool paused: state === "paused"
  readonly property bool hasTrack: title !== ""
  readonly property bool hasMedia: hasTrack && (playing || paused)

  // ---- visibility / behavior ----
  property bool hidden: false
  property bool peekShowing: false
  property int peekEvery: 0        // seconds; 0 = stay visible while playing
  property int peekDuration: 6     // seconds
  property bool showOnTrackChange: true

  readonly property bool windowVisible: !hidden && hasMedia && (peekEvery <= 0 || peekShowing)

  // ---- position (logical px from top-left) ----
  property int posX: 24
  property int posY: 24

  function parseStatus(raw) {
    try {
      var o = JSON.parse(raw)
      var nt = o.title || ""
      if (nt !== root.title && nt !== "" && root.showOnTrackChange && root.peekEvery > 0) {
        root.peekShowing = true
        peekHideTimer.restart()
      }
      root.artPath = o.art || ""
      root.title = nt
      root.artist = o.artist || ""
      root.state = o.state || "stopped"
      root.position = Number(o.position) || 0
      root.duration = Number(o.duration) || 0
      root.volume = Number(o.volume) || 0
    } catch (e) {}
  }

  function parseSettings(raw) {
    try {
      var o = JSON.parse(raw)
      if (o.peekEverySeconds !== undefined) root.peekEvery = Math.max(0, Number(o.peekEverySeconds) || 0)
      if (o.peekDurationSeconds !== undefined) root.peekDuration = Math.max(1, Number(o.peekDurationSeconds) || 6)
      if (o.showOnTrackChange !== undefined) root.showOnTrackChange = o.showOnTrackChange === true
    } catch (e) {}
  }

  function parsePosition(raw) {
    try {
      var o = JSON.parse(raw)
      root.posX = Math.max(0, Math.round(Number(o.x) || 0))
      root.posY = Math.max(0, Math.round(Number(o.y) || 0))
    } catch (e) {}
  }

  function toggleHidden() {
    root.hidden = !root.hidden
    if (!root.hidden && root.peekEvery > 0) {
      root.peekShowing = true
      peekHideTimer.restart()
    }
  }
  function showWidget() {
    root.hidden = false
    if (root.peekEvery > 0) {
      root.peekShowing = true
      peekHideTimer.restart()
    }
  }
  function hideWidget() { root.hidden = true }

  function savePosition() {
    var cmd = "printf '{\"x\":" + Math.round(root.posX) + ",\"y\":" + Math.round(root.posY) + "}' > '" + root.positionFile + "'"
    savePosProc.command = ["bash", "-c", cmd]
    savePosProc.running = true
  }

  function runCliamp(action) {
    if (actionProc.running) return
    actionProc.command = ["/usr/bin/cliamp", action]
    actionProc.running = true
  }

  function pad2(n) { return n < 10 ? "0" + n : "" + n }
  function fmtTime(secs) {
    if (!isFinite(secs) || secs < 0) return "--:--"
    var s = Math.floor(secs)
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var ss = s % 60
    if (h > 0) return h + ":" + pad2(m) + ":" + pad2(ss)
    return m + ":" + pad2(ss)
  }

  Process {
    id: statusProc
    command: ["cat", root.statusFile]
    stdout: StdioCollector { onStreamFinished: root.parseStatus(String(text || "")) }
  }
  Process {
    id: settingsProc
    command: ["cat", root.settingsFile]
    stdout: StdioCollector { onStreamFinished: root.parseSettings(String(text || "")) }
  }
  Process {
    id: positionProc
    command: ["cat", root.positionFile]
    stdout: StdioCollector { onStreamFinished: root.parsePosition(String(text || "")) }
  }
  Process { id: savePosProc; command: [] }
  Process { id: actionProc; command: [] }

  Timer {
    id: statusTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: { if (!statusProc.running) statusProc.running = true }
  }
  Timer {
    id: settingsTimer
    interval: 10000
    repeat: true
    running: true
    onTriggered: { if (!settingsProc.running) settingsProc.running = true }
  }

  Timer {
    id: peekCycleTimer
    interval: root.peekEvery * 1000
    repeat: true
    running: root.peekEvery > 0
    onTriggered: {
      root.peekShowing = true
      peekHideTimer.restart()
    }
  }
  Timer {
    id: peekHideTimer
    interval: root.peekDuration * 1000
    repeat: false
    onTriggered: root.peekShowing = false
  }

  Component.onCompleted: {
    statusProc.running = true
    settingsProc.running = true
    positionProc.running = true
  }

  IpcHandler {
    target: "cliamp-widget"
    function toggle(): string { root.toggleHidden(); return root.hidden ? "hidden" : "shown" }
    function show(): string { root.showWidget(); return "shown" }
    function hide(): string { root.hideWidget(); return "hidden" }
    function state(): string { return JSON.stringify({ hidden: root.hidden, visible: root.windowVisible, title: root.title, playing: root.playing }) }
    function ping(): string { return "ok" }
  }

  PanelWindow {
    id: panel
    screen: Quickshell.screens[0]
    implicitWidth: Style.space(344)
    implicitHeight: Style.space(88)
    visible: root.windowVisible
    anchors { top: true; left: true }
    margins.left: root.posX
    margins.top: root.posY
    color: "transparent"
    WlrLayershell.namespace: "cliamp-widget"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    BorderSurface {
      id: card
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Util.alpha(Color.background, 0.96)
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(1)))

      MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: Qt.OpenHandCursor
        property real startPointerX: 0
        property real startPointerY: 0
        property real startPosX: 0
        property real startPosY: 0
        property bool dragging: false

        onPressed: function(mouse) {
          startPointerX = (panel.screen ? panel.screen.x : 0) + root.posX + mouse.x
          startPointerY = (panel.screen ? panel.screen.y : 0) + root.posY + mouse.y
          startPosX = root.posX
          startPosY = root.posY
          dragging = false
          cursorShape = Qt.ClosedHandCursor
        }
        onPositionChanged: function(mouse) {
          if (!pressed) return
          var px = (panel.screen ? panel.screen.x : 0) + root.posX + mouse.x
          var py = (panel.screen ? panel.screen.y : 0) + root.posY + mouse.y
          var dx = px - startPointerX
          var dy = py - startPointerY
          if (!dragging && Math.abs(dx) + Math.abs(dy) > 4) dragging = true
          if (!dragging) return
          var sw = panel.screen ? panel.screen.width : 1280
          var sh = panel.screen ? panel.screen.height : 800
          root.posX = Math.max(0, Math.min(Math.round(startPosX + dx), sw - panel.implicitWidth))
          root.posY = Math.max(0, Math.min(Math.round(startPosY + dy), sh - panel.implicitHeight))
        }
        onReleased: function() {
          cursorShape = Qt.OpenHandCursor
          if (dragging) root.savePosition()
        }
      }

      Row {
        anchors.fill: parent
        anchors.margins: Style.space(10)
        spacing: Style.space(10)

        Rectangle {
          width: Style.space(68)
          height: Style.space(68)
          radius: Style.spacing.labelGap
          color: Util.alpha(Color.accent, 0.16)
          clip: true
          anchors.verticalCenter: parent.verticalCenter

          Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            source: root.artPath !== "" ? Util.fileUrl(root.artPath) : ""
            visible: source !== ""
          }

          Text {
            anchors.centerIn: parent
            visible: root.artPath === ""
            text: "󰝚"
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          width: parent.width - Style.space(68) - Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(4)

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.hasTrack ? root.title : "cliamp — sin reproducción"
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 1
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.artist
            color: Util.alpha(Color.popups.text, 0.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            maximumLineCount: 1
            visible: text !== ""
          }

          Row {
            spacing: Style.space(16)

            MouseArea {
              width: prevIcon.width + Style.space(8)
              height: prevIcon.height + Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runCliamp("prev")
              Text {
                id: prevIcon
                anchors.centerIn: parent
                text: "󰒮"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }

            MouseArea {
              width: playIcon.width + Style.space(10)
              height: playIcon.height + Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runCliamp("toggle")
              Text {
                id: playIcon
                anchors.centerIn: parent
                text: root.playing ? "󰏤" : "󰐊"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.title
              }
            }

            MouseArea {
              width: nextIcon.width + Style.space(8)
              height: nextIcon.height + Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runCliamp("next")
              Text {
                id: nextIcon
                anchors.centerIn: parent
                text: "󰒭"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
          }
        }
      }

      Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: card.borderLeft + Style.space(10)
        anchors.rightMargin: card.borderRight + Style.space(10)
        anchors.bottomMargin: Style.space(6)
        spacing: Style.space(6)

        Rectangle {
          width: Math.max(20, parent.width - timeLabel.implicitWidth - parent.spacing)
          height: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter
          radius: Style.space(1)
          color: Util.alpha(Color.popups.text, 0.18)
          visible: root.duration > 0

          Rectangle {
            width: parent.width * (root.duration > 0 ? Math.min(1, Math.max(0, root.position / root.duration)) : 0)
            height: parent.height
            radius: parent.radius
            color: Color.accent
          }
        }

        Text {
          id: timeLabel
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: root.fmtTime(root.position) + " / " + root.fmtTime(root.duration)
          color: Util.alpha(Color.popups.text, 0.62)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
