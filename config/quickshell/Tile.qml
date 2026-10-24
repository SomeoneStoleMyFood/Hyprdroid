import QtQuick
import QtQuick.Layouts

// Quick-settings tile (Material 3 Expressive: big pill, shape morphs when active)
Rectangle {
    id: t
    required property var shell
    property string label: ""
    property string sub: ""
    property string icon: ""
    property bool active: false
    property int level: 4
    property real reveal: 1
    signal clicked()

    implicitHeight: 68
    radius: active ? 26 : 34
    color: active ? shell.tileActive : shell.containerHigh
    opacity: reveal
    property real bump: 1
    onActiveChanged: bumpAnim.restart()
    SequentialAnimation {
        id: bumpAnim
        NumberAnimation { target: t; property: "bump"; to: 0.92; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: t; property: "bump"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
    }
    scale: (ma.pressed ? 0.96 : 1) * (0.82 + 0.18 * reveal) * bump
    Behavior on radius { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on scale { NumberAnimation { duration: 120 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 14
        spacing: 12

        Rectangle {
            implicitWidth: 44; implicitHeight: 44; radius: 22
            color: t.active ? Qt.alpha(t.shell.onTileActive, 0.2) : Qt.alpha(t.shell.onSurface, 0.08)
            Behavior on color { ColorAnimation { duration: 200 } }
            Glyph {
                anchors.centerIn: parent
                shell: t.shell
                name: t.icon
                level: t.level
                size: 22
                color: t.shell.textColor
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: t.label
                elide: Text.ElideRight
                color: t.shell.textColor
                font.family: t.shell.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: t.sub
                elide: Text.ElideRight
                color: t.shell.textColor
                font.family: t.shell.fontFamily
                font.pixelSize: 12
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: t.clicked()
    }
}
