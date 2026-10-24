import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

// Fullscreen shade. Wide screens: notifications on the left, quick settings on the right. Narrow: one column.
Item {
    id: body
    required property var ctl
    property bool clearing: false
    function startClear() {
        const n = sh.notifList.length
        if (n === 0) return
        clearing = true
        clearTimer.interval = Math.min(n, 12) * 45 + 560
        clearTimer.restart()
    }
    Timer { id: clearTimer; onTriggered: { body.clearing = false; body.sh.clearNotifications() } }
    readonly property var sh: ctl.sh
    property real p: 1                                   // open progress, drives the staggered reveal
    readonly property bool wide: width > 1000
    readonly property var allTiles: sh.cv("shade.tiles", ["wifi", "bluetooth", "dnd", "saver"])

    function reveal(i) { return Math.max(0, Math.min(1, (p - 0.1 - i * 0.04) / 0.5)) }

    Flickable {
        id: fl
        anchors.fill: parent
        contentWidth: width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        GridLayout {
            id: grid
            width: fl.width
            columns: body.wide ? 2 : 1
            columnSpacing: 56
            rowSpacing: 28

            // ================= notifications (first) =================
            ColumnLayout {
                id: left
                Layout.fillWidth: true
                Layout.preferredWidth: 5
                Layout.alignment: Qt.AlignTop
                spacing: 12

                ColumnLayout {
                    spacing: 0
                    opacity: body.reveal(0)
                    transform: Translate { y: (1 - body.reveal(0)) * -18 }
                    Text {
                        text: Qt.formatDateTime(body.sh.nowDate, body.sh.use24h ? "HH:mm" : "h:mm")
                        color: body.sh.textColor
                        font.family: body.sh.cv("bar.clockFont", body.sh.fontFamily)
                        font.pixelSize: 72
                        font.weight: body.sh.cv("bar.clockBold", true) ? Font.Bold : Font.Light
                        font.letterSpacing: 0.5
                    }
                    Text {
                        text: Qt.formatDateTime(body.sh.nowDate, "dddd, d MMMM")
                        color: body.sh.textColor
                                        font.family: body.sh.fontFamily
                        font.pixelSize: 17
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    opacity: body.reveal(1)
                    transform: Translate { y: (1 - body.reveal(1)) * -18 }
                    Glyph { shell: body.sh; name: "notification"; size: 22; color: body.sh.textColor; Layout.rightMargin: 8 }
                    Text {
                        text: "Notifications"
                        color: body.sh.textColor
                        font.family: body.sh.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        visible: body.sh.notifList.length > 0
                        implicitHeight: 38
                        implicitWidth: clearRow.implicitWidth + 30
                        radius: cm.pressed ? 12 : 19
                        Behavior on radius { NumberAnimation { duration: 160 } }
                        color: body.sh.containerHigh
                        RowLayout {
                            id: clearRow
                            anchors.centerIn: parent
                            spacing: 6
                            Glyph { shell: body.sh; name: "clear_all"; size: 18; color: body.sh.textColor }
                            Text {
                                text: "Clear all"
                                color: body.sh.textColor
                                font.family: body.sh.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: body.startClear()
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: body.sh.notifList.length === 0
                    implicitHeight: 120
                    radius: 28
                    color: body.sh.container
                    opacity: body.reveal(2)
                    scale: visible ? 1 : 0.88
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }
                    Glyph { anchors.horizontalCenter: parent.horizontalCenter; y: 22; shell: body.sh; name: "notification"; size: 30; color: body.sh.textColor; opacity: 0.8 }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 70
                        text: "No notifications"
                        color: body.sh.textColor
                                        font.family: body.sh.fontFamily
                        font.pixelSize: 15
                    }
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 8
                    opacity: body.reveal(2)
                    add: Transition { NumberAnimation { properties: "opacity,scale"; from: 0; duration: 300; easing.type: Easing.OutBack } }
                    move: Transition { NumberAnimation { properties: "y"; duration: 280; easing.type: Easing.OutCubic } }
                    Repeater {
                        model: ScriptModel { values: body.sh.notifList }
                        delegate: NotifCard {
                            required property var modelData
                            required property int index
                            order: index
                            clearing: body.clearing
                            width: parent.width
                            shell: body.sh
                            n: modelData
                        }
                    }
                }
            }

            // ================= quick settings (second) =================
            ColumnLayout {
                id: right
                Layout.fillWidth: true
                Layout.preferredWidth: 6
                Layout.alignment: Qt.AlignTop
                spacing: 14
                readonly property int tileCols: Math.max(2, Math.min(4, Math.floor(width / 250)))

                // battery + power button
                RowLayout {
                    Layout.fillWidth: true
                    opacity: body.reveal(0)
                    transform: Translate { y: (1 - body.reveal(0)) * -18 }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        visible: !!(UPower.displayDevice && UPower.displayDevice.isLaptopBattery)
                        implicitHeight: 44
                        implicitWidth: batText.implicitWidth + 32
                        radius: 22
                        color: body.sh.containerHigh
                        Text {
                            id: batText
                            anchors.centerIn: parent
                            readonly property var b: UPower.displayDevice
                            text: b ? Math.round(b.percentage * 100) + "%" + (b.state === UPowerDeviceState.Charging ? "  •  Charging" : "") : ""
                            color: body.sh.textColor
                            font.family: body.sh.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                    }
                    Repeater {
                        model: [
                            { icon: "settings", key: "shade.settingsCommand" },
                            { icon: "power", key: "shade.powerCommand" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property var cmd0: body.sh.cv("shade.settingsCommand", [])
                            readonly property var cmd: cmd0.length > 0 ? cmd0 : ["xdg-open", Quickshell.shellPath("config.json")]
                            implicitWidth: 44; implicitHeight: 44
                            radius: pm.pressed ? 14 : 22
                            Behavior on radius { NumberAnimation { duration: 160 } }
                            color: modelData.icon === "power" ? "#B3261E" : body.sh.containerHigh
                            Glyph {
                                anchors.centerIn: parent
                                shell: body.sh
                                name: parent.modelData.icon
                                size: 22
                                color: "#FFFFFF"
                            }
                            MouseArea {
                                id: pm
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (parent.modelData.icon === "power") body.ctl.powerMenuOpen = true
                                    else { Quickshell.execDetached(parent.cmd); body.sh.closeShade() }
                                }
                            }
                        }
                    }
                }

                PillSlider {
                    Layout.fillWidth: true
                    visible: body.ctl.hasBacklight
                    opacity: body.reveal(1)
                    transform: Translate { y: (1 - body.reveal(1)) * -18 }
                    shell: body.sh
                    icon: "brightness"
                    value: body.ctl.brightness
                    onMoved: v => { body.ctl.brightness = v; body.ctl.applyBrightness() }
                }
                PillSlider {
                    Layout.fillWidth: true
                    visible: body.sh.cv("shade.showVolume", true) && !!(body.ctl.sink && body.ctl.sink.audio)
                    opacity: body.reveal(2)
                    transform: Translate { y: (1 - body.reveal(2)) * -18 }
                    shell: body.sh
                    icon: body.ctl.sink && body.ctl.sink.audio && body.ctl.sink.audio.muted ? "volume_off" : "volume_up"
                    value: body.ctl.sink && body.ctl.sink.audio ? body.ctl.sink.audio.volume : 0
                    onMoved: v => { if (body.ctl.sink && body.ctl.sink.audio) body.ctl.sink.audio.volume = v }
                }

                // tiles: all of them, as many columns as fit
                GridLayout {
                    Layout.fillWidth: true
                    columns: right.tileCols
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: body.allTiles
                        delegate: Tile {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredWidth: 100
                            shell: body.sh
                            reveal: body.reveal(3 + index)
                            label: body.ctl.tLabel(modelData)
                            sub: body.ctl.tSub(modelData)
                            icon: body.ctl.tIcon(modelData)
                            active: body.ctl.tActive(modelData)
                            level: body.ctl.wifiLvl()
                            onClicked: body.ctl.tToggle(modelData)
                        }
                    }
                    Repeater {
                        model: body.sh.cv("shade.customTiles", [])
                        delegate: Tile {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredWidth: 100
                            shell: body.sh
                            reveal: body.reveal(3 + body.allTiles.length + index)
                            label: modelData.label || ""
                            sub: modelData.sub || ""
                            icon: modelData.icon || "notification"
                            active: false
                            onClicked: {
                                Quickshell.execDetached(modelData.command)
                                if (modelData.closeShade !== false) body.sh.closeShade()
                            }
                        }
                    }
                }

                // media
                Rectangle {
                    Layout.fillWidth: true
                    visible: body.ctl.player !== null
                    implicitHeight: 100
                    radius: 30
                    color: body.sh.primaryContainer
                    opacity: body.reveal(9)
                    transform: Translate { y: (1 - body.reveal(9)) * 18 }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16
                        Rectangle {
                            implicitWidth: 68; implicitHeight: 68; radius: 22
                            color: body.sh.containerHigh
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: body.ctl.player ? body.ctl.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(136, 136)
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: body.ctl.player ? body.ctl.player.trackTitle : ""
                                elide: Text.ElideRight
                                color: body.sh.textColor
                                font.family: body.sh.fontFamily
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.fillWidth: true
                                text: body.ctl.player ? body.ctl.player.trackArtist : ""
                                elide: Text.ElideRight
                                color: body.sh.textColor
                                                        font.family: body.sh.fontFamily
                                font.pixelSize: 14
                            }
                        }
                        Repeater {
                            model: ["skip_prev", "play", "skip_next"]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool main: modelData === "play"
                                implicitWidth: main ? 56 : 44
                                implicitHeight: main ? 56 : 44
                                radius: main ? (mm.pressed ? 18 : 28) : 22
                                Behavior on radius { NumberAnimation { duration: 160 } }
                                color: main ? body.sh.tileActive : "transparent"
                                Glyph {
                                    anchors.centerIn: parent
                                    shell: body.sh
                                    name: parent.main && body.ctl.player && body.ctl.player.isPlaying ? "pause" : parent.modelData
                                    size: 28
                                    color: "#FFFFFF"
                                }
                                MouseArea {
                                    id: mm
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const pl = body.ctl.player
                                        if (!pl) return
                                        if (parent.modelData === "play") pl.togglePlaying()
                                        else if (parent.modelData === "skip_next") pl.next()
                                        else pl.previous()
                                    }
                                }
                            }
                        }
                    }
                }

                // widgets: alarm, timer, system, weather (order and selection: shade.widgets)
                GridLayout {
                    Layout.fillWidth: true
                    columns: right.width > 760 ? 2 : 1
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: body.sh.cv("shade.widgets", ["alarm", "timer", "weather", "system"])
                        delegate: Loader {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignTop
                            Component.onCompleted: {
                                const f = { alarm: "AlarmWidget.qml", timer: "TimerWidget.qml", system: "SystemWidget.qml", weather: "WeatherWidget.qml" }[modelData]
                                if (f) setSource(f, { shell: body.sh })
                            }
                        }
                    }
                }
            }
        }
    }
}
