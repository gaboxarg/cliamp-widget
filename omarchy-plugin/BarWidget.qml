import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "gabox.cliamp-now-playing"

  readonly property var service: (bar && bar.shell && typeof bar.shell.serviceFor === "function")
    ? bar.shell.serviceFor("gabox.cliamp-now-playing")
    : null
  readonly property bool hidden: service ? service.hidden : false

  implicitWidth: Style.bar.iconSlot
  implicitHeight: barSize

  Item {
    anchors.centerIn: parent
    width: Style.bar.iconCanvas
    height: Style.bar.iconCanvas

    Text {
      anchors.centerIn: parent
      text: "󰝚"
      color: root.bar ? root.bar.barForeground : Color.foreground
      opacity: root.hidden ? 0.4 : 1.0
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering

      Behavior on opacity {
        NumberAnimation { duration: 120 }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: if (root.service) root.service.toggleHidden()

    onEntered: if (root.bar) root.bar.showTooltip(root,
      root.hidden ? "cliamp: mostrar widget" : "cliamp: ocultar widget")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
