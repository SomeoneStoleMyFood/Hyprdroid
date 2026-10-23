import QtQuick
import QtQuick.Layouts

// Countdown timer with presets. Survives restarts; rings like an alarm.
Rectangle {
    id: w
    required property var shell
    Layout.alignment: Qt.AlignTop
    radius: 28
    color: shell.container
    implicitHeight: col.implicitHeight + 32

    readonly property bool running: shell.timerEnd > 0
    readonly property real remainMs: running ? Math.max(0, shell.timerEnd - shell.nowMs) : 0
    function fmt(ms) {
        const t = Math.ceil(ms / 1000)
        const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), s = t % 60
        return (h > 0 ? h + ":" + shell.pad2(m) : shell.pad2(m)) + ":" + shell.pad2(s)
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            spacing: 10
            Glyph { shell: w.shell; name: "timer"; size: 22; color: w.shell.textColor }
            Text { text: "Timer"; color: w.shell.textColor; font.family: w.shell.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: w.running ? w.fmt(w.remainMs) : "00:00"
            color: w.shell.textColor
            opacity: w.running ? 1 : 0.7
            font.family: w.shell.cv("bar.clockFont", w.shell.fontFamily)
            font.pixelSize: 54
            font.weight: Font.Bold
        }
        // progress
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 8
            radius: 4
            color: w.shell.containerHigh
            Rectangle {
                width: w.running && w.shell.timerTotal > 0 ? parent.width * (w.remainMs / w.shell.timerTotal) : 0
                height: parent.height
                radius: 4
                color: w.shell.tileActive
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: w.running ? [] : [60, 300, 600, 1800]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: pm.pressed ? 12 : 21
                    Behavior on radius { NumberAnimation { duration: 160 } }
                    color: pm.pressed ? w.shell.tileActive : w.shell.containerHigh
                    Text { anchors.centerIn: parent; text: modelData / 60 + " min"; color: w.shell.textColor; font.family: w.shell.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                    MouseArea { id: pm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.shell.startTimer(modelData) }
                }
            }
            Rectangle {
                visible: w.running
                Layout.fillWidth: true
                implicitHeight: 42
                radius: cm.pressed ? 12 : 21
                color: "#B3261E"
                Text { anchors.centerIn: parent; text: "Cancel"; color: w.shell.textColor; font.family: w.shell.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
                MouseArea { id: cm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.shell.cancelTimer() }
            }
        }
    }
}
