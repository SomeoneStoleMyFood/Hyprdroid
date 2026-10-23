import QtQuick

// Thick Material 3 Expressive slider with the icon inside the track
Item {
    id: sl
    required property var shell
    property real value: 0
    property string icon: ""
    signal moved(real v)
    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sl.shell.containerHigh
        clip: true
        Rectangle {
            width: Math.max(parent.height, parent.width * sl.value)
            height: parent.height
            radius: height / 2
            color: sl.shell.tileActive
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    Glyph {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        shell: sl.shell
        name: sl.icon
        size: 22
        color: sl.shell.textColor
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        preventStealing: true
        function setFrom(x) { sl.moved(Math.max(0, Math.min(1, x / width))) }
        onPressed: mouse => setFrom(mouse.x)
        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
    }
}
