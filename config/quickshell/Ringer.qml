import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Alarm / timer ringing screen: big card with Snooze and Stop, on every monitor.
Scope {
    id: ringer
    required property var shell

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: ringer.shell.ringing || fade.opacity > 0.01
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pixel-ringer"

            Item {
                id: fade
                anchors.fill: parent
                opacity: ringer.shell.ringing ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Rectangle { anchors.fill: parent; color: "black"; opacity: 0.72 }
                MouseArea { anchors.fill: parent }

                Rectangle {
                    anchors.centerIn: parent
                    width: 420
                    height: card.implicitHeight + 64
                    radius: 40
                    color: ringer.shell.container
                    border.width: 1
                    border.color: "#26FFFFFF"
                    scale: ringer.shell.ringing ? 1 : 0.9
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                    ColumnLayout {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 32
                        spacing: 16

                        Glyph {
                            Layout.alignment: Qt.AlignHCenter
                            shell: ringer.shell
                            name: "alarm"
                            size: 56
                            color: ringer.shell.textColor
                            SequentialAnimation on rotation {
                                running: ringer.shell.ringing
                                loops: Animation.Infinite
                                NumberAnimation { to: 14; duration: 90 }
                                NumberAnimation { to: -14; duration: 180 }
                                NumberAnimation { to: 0; duration: 90 }
                                PauseAnimation { duration: 500 }
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDateTime(ringer.shell.nowDate, ringer.shell.use24h ? "HH:mm" : "h:mm")
                            color: ringer.shell.textColor
                            font.family: ringer.shell.cv("bar.clockFont", ringer.shell.fontFamily)
                            font.pixelSize: 84
                            font.weight: Font.Bold
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: ringer.shell.ringLabel
                            color: ringer.shell.textColor
                            font.family: ringer.shell.fontFamily
                            font.pixelSize: 20
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                            spacing: 12
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 60
                                radius: sm.pressed ? 18 : 30
                                Behavior on radius { NumberAnimation { duration: 160 } }
                                color: ringer.shell.containerHigh
                                Text { anchors.centerIn: parent; text: "Snooze 10 min"; color: ringer.shell.textColor; font.family: ringer.shell.fontFamily; font.pixelSize: 16; font.weight: Font.Medium }
                                MouseArea { id: sm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ringer.shell.snooze(10) }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 60
                                radius: stm.pressed ? 18 : 30
                                Behavior on radius { NumberAnimation { duration: 160 } }
                                color: ringer.shell.tileActive
                                Text { anchors.centerIn: parent; text: "Stop"; color: ringer.shell.textColor; font.family: ringer.shell.fontFamily; font.pixelSize: 16; font.weight: Font.Bold }
                                MouseArea { id: stm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ringer.shell.stopRing() }
                            }
                        }
                    }
                }
            }
        }
    }
}
