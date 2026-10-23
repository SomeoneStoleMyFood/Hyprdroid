import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// Android-style heads-up notifications. Used from shell.qml:  Toasts { id: toasts; shell: root }
Scope {
    id: toasts
    required property var shell
    property var items: []          // notifications currently popped up, newest first

    readonly property string targetName: {
        const t = shell.cv("toasts.screen", "main")
        if (t === "main") return shell.mainScreenName
        if (t === "focused") return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : shell.mainScreenName
        return t
    }

    function push(n) {
        if (!shell.cv("toasts.enabled", true)) return
        const critical = n.urgency === NotificationUrgency.Critical
        if (shell.dnd && !(critical && shell.cv("toasts.criticalIgnoresDnd", true)) && !shell.cv("toasts.showInDnd", false)) return
        if (items.indexOf(n) >= 0) return
        const max = shell.cv("toasts.maxVisible", 3)
        items = [n].concat(items).slice(0, max)
    }
    // dismissToo: also remove it from the notification list (swipe away), otherwise only hide the popup
    function remove(n, dismissToo) {
        items = items.filter(x => x !== n)
        if (dismissToo) n.dismiss()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            property bool linger: false
            visible: modelData.name === toasts.targetName && (toasts.items.length > 0 || linger)

            anchors.top: true
            margins.top: toasts.shell.barHeight + toasts.shell.cv("toasts.topMarginPx", 8)
            implicitWidth: toasts.shell.cv("toasts.width", 400) + 24
            implicitHeight: Math.max(1, list.contentHeight + 24)
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pixel-toasts"

            Connections {
                target: toasts
                function onItemsChanged() { win.linger = true; lingerTimer.restart() }
            }
            Timer { id: lingerTimer; interval: 450; onTriggered: win.linger = false }

            ListView {
                id: list
                x: 12; y: 12
                width: parent.width - 24
                height: contentHeight
                interactive: false
                spacing: 8
                model: ScriptModel { values: toasts.items }

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                        NumberAnimation { property: "y"; from: -90; duration: 300; easing.type: Easing.OutCubic }
                    }
                }
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                        NumberAnimation { property: "scale"; to: 0.92; duration: 180 }
                    }
                }
                displaced: Transition { NumberAnimation { property: "y"; duration: 240; easing.type: Easing.OutCubic } }

                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool critical: n.urgency === NotificationUrgency.Critical
                    readonly property var btnActions: {
                        const out = []
                        const a = n.actions
                        if (a) for (let i = 0; i < a.length; i++) if (a[i].identifier !== "default") out.push(a[i])
                        return out
                    }
                    readonly property string iconSrc: toasts.shell.notifIconSource(n)
                    width: ListView.view.width
                    height: card.height

                    Rectangle {
                        id: card
                        width: parent.width
                        height: col.implicitHeight + 28
                        radius: toasts.shell.cv("toasts.radius", 26)
                        color: toasts.shell.container
                        border.width: 1
                        border.color: "#1FFFFFFF"
                        opacity: 1 - Math.min(0.6, Math.abs(x) / width)
                        Behavior on x { enabled: !drag.active; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        MouseArea {
                            id: drag
                            anchors.fill: parent
                            hoverEnabled: true
                            drag.target: card
                            drag.axis: Drag.XAxis
                            onClicked: {
                                const a = row.n.actions
                                if (a) for (let i = 0; i < a.length; i++) if (a[i].identifier === "default") { a[i].invoke(); break }
                                toasts.remove(row.n, false)
                            }
                            onReleased: {
                                if (Math.abs(card.x) > card.width * 0.35) toasts.remove(row.n, true)
                                else card.x = 0
                            }
                            // popup closes by itself unless hovered, dragged, or critical
                            Timer {
                                interval: row.n.expireTimeout > 0 ? row.n.expireTimeout * 1000 : toasts.shell.cv("toasts.timeoutMs", 6000)
                                running: !row.critical && !drag.containsMouse && !drag.drag.active
                                onTriggered: toasts.remove(row.n, false)
                            }
                        }

                        ColumnLayout {
                            id: col
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 8

                            // header: app icon, app name, time
                            RowLayout {
                                spacing: 8
                                Rectangle {
                                    implicitWidth: 22; implicitHeight: 22; radius: 11
                                    color: toasts.shell.primaryContainer
                                    clip: true
                                    Image {
                                        id: appImg
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        source: row.iconSrc
                                        sourceSize: Qt.size(44, 44)
                                        fillMode: Image.PreserveAspectFit
                                        visible: status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: appImg.status !== Image.Ready
                                        text: (row.n.appName || "?").charAt(0).toUpperCase()
                                        color: toasts.shell.textColor
                                        font.family: toasts.shell.fontFamily
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                                Text {
                                    text: row.n.appName
                                    color: toasts.shell.textColor
                                    font.family: toasts.shell.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                                Text {
                                    text: "•  now"
                                    color: toasts.shell.textColor
                                    font.family: toasts.shell.fontFamily
                                    font.pixelSize: 12
                                }
                                Item { Layout.fillWidth: true }
                            }

                            // content: title + body, optional image on the right
                            RowLayout {
                                spacing: 12
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: row.n.summary
                                        color: toasts.shell.textColor
                                        font.family: toasts.shell.fontFamily
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: row.n.body
                                        textFormat: Text.StyledText
                                        color: toasts.shell.textColor
                                        font.family: toasts.shell.fontFamily
                                        font.pixelSize: 13
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }
                                }
                                Rectangle {
                                    visible: bigImg.status === Image.Ready
                                    implicitWidth: 56; implicitHeight: 56; radius: 14
                                    color: toasts.shell.containerHigh
                                    clip: true
                                    Image {
                                        id: bigImg
                                        anchors.fill: parent
                                        source: row.n.image
                                        sourceSize: Qt.size(112, 112)
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }
                            }

                            // action buttons
                            RowLayout {
                                visible: row.btnActions.length > 0
                                spacing: 8
                                Repeater {
                                    model: row.btnActions
                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitHeight: 32
                                        implicitWidth: label.implicitWidth + 28
                                        radius: 16
                                        color: btnMouse.pressed ? toasts.shell.primaryContainer : toasts.shell.containerHigh
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Text {
                                            id: label
                                            anchors.centerIn: parent
                                            text: parent.modelData.text
                                            color: toasts.shell.textColor
                                            font.family: toasts.shell.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                        }
                                        MouseArea {
                                            id: btnMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                parent.modelData.invoke()
                                                toasts.remove(row.n, false)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
