import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// CPU / memory / temperature
Rectangle {
    id: w
    required property var shell
    Layout.alignment: Qt.AlignTop
    radius: 28
    color: shell.container
    implicitHeight: col.implicitHeight + 32

    property int cpu: 0
    property int mem: 0
    property int temp: 0

    Process {
        id: proc
        command: ["bash", "-c", [
            "read -r _ u1 n1 s1 i1 w1 q1 sq1 _ < /proc/stat; sleep 0.4; read -r _ u2 n2 s2 i2 w2 q2 sq2 _ < /proc/stat",
            "t1=$((u1+n1+s1+i1+w1+q1+sq1)); t2=$((u2+n2+s2+i2+w2+q2+sq2)); dt=$((t2-t1)); [ $dt -le 0 ] && dt=1",
            "cpu=$(( 100*(dt-(i2-i1)) / dt ))",
            "mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%d\", (t-a)*100/t}' /proc/meminfo)",
            "temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null); echo \"$cpu $mem $(( ${temp:-0} / 1000 ))\""
        ].join("\n")]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ")
                if (p.length < 3) return
                w.cpu = parseInt(p[0]); w.mem = parseInt(p[1]); w.temp = parseInt(p[2])
            }
        }
    }
    Timer { interval: 2500; running: w.visible && w.shell.shadeOpen; repeat: true; triggeredOnStart: true; onTriggered: proc.running = true }

    component Bar: RowLayout {
        id: b
        property string label: ""
        property int value: 0
        property string unit: "%"
        spacing: 12
        Text { Layout.preferredWidth: 52; text: b.label; color: w.shell.textColor; font.family: w.shell.fontFamily; font.pixelSize: 14; font.weight: Font.Medium }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 12; radius: 6
            color: w.shell.containerHigh
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, b.value)) / 100
                height: parent.height; radius: 6
                color: b.value > 85 ? "#E5534B" : w.shell.tileActive
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
        Text { Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight; text: b.value + b.unit; color: w.shell.textColor; font.family: w.shell.fontFamily; font.pixelSize: 14 }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            spacing: 10
            Glyph { shell: w.shell; name: "speed"; size: 22; color: w.shell.textColor }
            Text { text: "System"; color: w.shell.textColor; font.family: w.shell.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold }
        }
        Bar { Layout.fillWidth: true; label: "CPU"; value: w.cpu }
        Bar { Layout.fillWidth: true; label: "RAM"; value: w.mem }
        Bar { Layout.fillWidth: true; visible: w.temp > 0; label: "Temp"; value: w.temp; unit: "°C" }
    }
}
