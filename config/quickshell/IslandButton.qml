import QtQuick

// Round button used inside the dynamic island (shape morphs while pressed)
Rectangle {
    id: b
    required property var shell
    property string icon: ""
    property string label: ""
    property color fill: "#2A2D34"
    property real iconSize: 22
    signal clicked()
    implicitWidth: label !== "" ? lbl.implicitWidth + (icon !== "" ? iconSize + 30 : 36) : 44
    implicitHeight: 44
    radius: ma.pressed ? 14 : height / 2
    color: fill
    scale: ma.pressed ? 0.94 : 1
    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
    Behavior on scale { SpringAnimation { spring: 8; damping: 0.4; epsilon: 0.002 } }
    Row {
        anchors.centerIn: parent
        spacing: 8
        Glyph { visible: b.icon !== ""; shell: b.shell; name: b.icon; size: b.iconSize; color: "white"; anchors.verticalCenter: parent.verticalCenter }
        Text { id: lbl; visible: b.label !== ""; text: b.label; color: "white"; font.family: b.shell.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
