import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// One notification inside the shade. Swipe sideways or press x to dismiss, click to open.
Item {
    id: nc
    required property var shell
    required property var n
    readonly property string iconSrc: shell.notifIconSource(n)
    readonly property var btnActions: nc.shell.actionsFor(n).filter(x => x.identifier !== "default")
    readonly property string when: {
        const d = nc.shell.nowDate
        const t = nc.n.time
        if (!t) return ""
        const m = Math.floor((d.getTime() - t) / 60000)
        return m < 1 ? "now" : m < 60 ? m + "m" : Math.floor(m / 60) + "h"
    }

    property real appear: 0
    Component.onCompleted: appear = 1
    Behavior on appear { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    property bool clearing: false          // set by "Clear all": every card flies out in turn
    property int order: 0
    property real collapse: 0              // 0..1, the slot shrinks after the card has left
    implicitHeight: card.height * (1 - collapse)
    height: card.height * (1 - collapse)
    clip: collapse > 0
    opacity: appear
    function leave(delay, doDismiss) {
        if (leaveAnim.running) return
        leaveAnim.delay = delay
        leaveAnim.doDismiss = doDismiss
        leaveAnim.start()
    }
    onClearingChanged: if (clearing) leave(order * 45, false)
    SequentialAnimation {
        id: leaveAnim
        property int delay: 0
        property bool doDismiss: true
        PauseAnimation { duration: leaveAnim.delay }
        NumberAnimation { target: card; property: "x"; to: card.width + 80; duration: 280; easing.type: Easing.InCubic }
        NumberAnimation { target: nc; property: "collapse"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        ScriptAction { script: if (leaveAnim.doDismiss) nc.shell.dismissRecord(nc.n.uid) }
    }
    scale: 0.96 + 0.04 * appear

    Rectangle {
        id: card
        width: parent.width
        height: content.implicitHeight + 24
        radius: 24
        color: nc.shell.container
        opacity: 1 - Math.min(0.6, Math.abs(x) / width)
        Behavior on x { enabled: !area.drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea {
            id: area
            anchors.fill: parent
            drag.target: card
            drag.axis: Drag.XAxis
            onClicked: {
                const a = nc.shell.actionsFor(nc.n)
                for (let i = 0; i < a.length; i++) if (a[i].identifier === "default") { a[i].invoke(); break }
                nc.shell.closeShade()
            }
            onReleased: {
                if (Math.abs(card.x) > card.width * 0.35) nc.leave(0, true)
                else card.x = 0
            }
        }

        RowLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 40; implicitHeight: 40; radius: 20
                color: nc.shell.primaryContainer
                clip: true
                Image {
                    id: appImg
                    anchors.fill: parent
                    anchors.margins: 7
                    source: nc.iconSrc
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: appImg.status !== Image.Ready
                    text: (nc.n.appName || "?").charAt(0).toUpperCase()
                    color: nc.shell.textColor
                    font.family: nc.shell.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: nc.n.appName + (nc.when !== "" ? "  •  " + nc.when : "")
                    color: nc.shell.textColor
                    font.family: nc.shell.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: nc.n.summary
                    color: nc.shell.textColor
                    font.family: nc.shell.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: nc.n.body
                    textFormat: Text.StyledText
                    color: nc.shell.textColor
                    font.family: nc.shell.fontFamily
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                RowLayout {
                    visible: nc.btnActions.length > 0
                    Layout.topMargin: 6
                    spacing: 8
                    Repeater {
                        model: nc.btnActions
                        delegate: Rectangle {
                            required property var modelData
                            implicitHeight: 30
                            implicitWidth: lbl.implicitWidth + 24
                            radius: 15
                            color: bm.pressed ? nc.shell.primaryContainer : nc.shell.containerHigh
                            Text {
                                id: lbl
                                anchors.centerIn: parent
                                text: parent.modelData.text
                                color: nc.shell.textColor
                                font.family: nc.shell.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            MouseArea {
                                id: bm
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: parent.modelData.invoke()
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 28; implicitHeight: 28; radius: 14
                color: xm.pressed ? nc.shell.containerHigh : "transparent"
                Glyph {
                    anchors.centerIn: parent
                    shell: nc.shell
                    name: "close"
                    size: 16
                    color: nc.shell.textColor
                }
                MouseArea {
                    id: xm
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nc.leave(0, true)
                }
            }
        }
    }
}
