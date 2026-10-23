import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// One monitor of the lock screen: blurred screenshot, Pixel-style stacked clock, widgets, avatar, password.
Item {
    id: root
    required property var shell
    required property var ctl
    required property string screenName

    readonly property real s: Math.max(0.6, Math.min(1.4, height / 1080))
    readonly property color glass: Qt.rgba(0.08, 0.09, 0.11, 0.55)
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property string userName: shell.cv("lock.name", "") !== "" ? shell.cv("lock.name", "")
        : (Quickshell.env("USER") || "user").charAt(0).toUpperCase() + (Quickshell.env("USER") || "user").slice(1)
    readonly property string clockFont: shell.cv("bar.clockFont", shell.fontFamily)
    readonly property var fallbackPower: [
        { icon: "sleep", command: ["systemctl", "suspend"] },
        { icon: "restart", command: ["systemctl", "reboot"] },
        { icon: "power", command: ["systemctl", "poweroff"], danger: true }
    ]
    property real intro: 0
    NumberAnimation on intro { from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
    function stage(delay) { return Math.max(0, Math.min(1, intro * 1.5 - delay)) }

    // ---------- background: blurred screenshot ----------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#101820" }
            GradientStop { position: 1; color: "#1B2735" }
        }
    }
    Image {
        id: shot
        anchors.fill: parent
        source: root.ctl.shotUrl(root.screenName)
        cache: false
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: root.intro
        }
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: 0.3 * root.intro }

    // ---------- clock (a bit above the middle) ----------
    ColumnLayout {
        id: clockBlock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.09
        spacing: 0
        opacity: root.stage(0)
        scale: 0.94 + 0.06 * root.stage(0)
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(root.shell.nowDate, "dddd, d MMMM") + (root.shell.weatherTemp !== "" ? "   " + root.shell.weatherTemp : "")
            color: root.shell.textColor
            font.family: root.shell.fontFamily
            font.pixelSize: Math.round(22 * root.s)
            font.weight: Font.Medium
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(root.shell.nowDate, root.shell.use24h ? "HH" : "h")
            color: root.shell.textColor
            font.family: root.clockFont
            font.pixelSize: Math.round(root.height * 0.17)
            font.weight: Font.Bold
            lineHeight: 0.86
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Math.round(root.height * 0.035)
            text: Qt.formatDateTime(root.shell.nowDate, "mm")
            color: root.shell.textColor
            font.family: root.clockFont
            font.pixelSize: Math.round(root.height * 0.17)
            font.weight: Font.Bold
            lineHeight: 0.86
        }
    }

    // ---------- widgets ----------
    ColumnLayout {
        id: widgets
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.58 - height / 2
        spacing: 12 * root.s
        opacity: root.stage(0.25)
        transform: Translate { y: (1 - root.stage(0.25)) * 30 }

        // ringing alarm / timer replaces the widgets
        Rectangle {
            visible: root.shell.ringing
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 460 * root.s
            implicitHeight: 84 * root.s
            radius: 42 * root.s
            color: "#B3261E"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24 * root.s
                anchors.rightMargin: 12 * root.s
                spacing: 12
                Glyph { shell: root.shell; name: "alarm"; size: 30 * root.s; color: root.shell.textColor }
                Text { Layout.fillWidth: true; text: root.shell.ringLabel; color: root.shell.textColor; font.family: root.shell.fontFamily; font.pixelSize: 20 * root.s; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Repeater {
                    model: [{ t: "Snooze", snooze: true }, { t: "Stop", snooze: false }]
                    delegate: Rectangle {
                        required property var modelData
                        implicitHeight: 52 * root.s
                        implicitWidth: lbl.implicitWidth + 36
                        radius: height / 2
                        color: modelData.snooze ? "#5A5F6B" : root.shell.tileActive
                        Text { id: lbl; anchors.centerIn: parent; text: modelData.t; color: root.shell.textColor; font.family: root.shell.fontFamily; font.pixelSize: 16 * root.s; font.weight: Font.Medium }
                        MouseArea { anchors.fill: parent; onClicked: modelData.snooze ? root.shell.snooze(10) : root.shell.stopRing() }
                    }
                }
            }
        }

        // music
        Rectangle {
            visible: root.player !== null && !root.shell.ringing
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 440 * root.s
            implicitHeight: 96 * root.s
            radius: 32 * root.s
            color: root.glass
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14 * root.s
                spacing: 14 * root.s
                Rectangle {
                    implicitWidth: 68 * root.s; implicitHeight: 68 * root.s; radius: 20 * root.s
                    color: "#33FFFFFF"
                    clip: true
                    Image { anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(136, 136) }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { Layout.fillWidth: true; text: root.player ? root.player.trackTitle : ""; elide: Text.ElideRight; color: root.shell.textColor; font.family: root.shell.fontFamily; font.pixelSize: 17 * root.s; font.weight: Font.DemiBold }
                    Text { Layout.fillWidth: true; text: root.player ? root.player.trackArtist : ""; elide: Text.ElideRight; color: root.shell.textColor; font.family: root.shell.fontFamily; font.pixelSize: 14 * root.s }
                }
                Repeater {
                    model: ["skip_prev", "play", "skip_next"]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool main: modelData === "play"
                        implicitWidth: (main ? 52 : 40) * root.s
                        implicitHeight: (main ? 52 : 40) * root.s
                        radius: width / 2
                        color: main ? root.shell.tileActive : "transparent"
                        Glyph {
                            anchors.centerIn: parent
                            shell: root.shell
                            name: parent.main && root.player && root.player.isPlaying ? "pause" : parent.modelData
                            size: 26 * root.s
                            color: root.shell.textColor
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!root.player) return
                                if (parent.modelData === "play") root.player.togglePlaying()
                                else if (parent.modelData === "skip_next") root.player.next()
                                else root.player.previous()
                            }
                        }
                    }
                }
            }
        }

        // chips: next alarm, weather, battery
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10 * root.s
            visible: !root.shell.ringing
            Rectangle {
                readonly property string nx: root.shell.nextAlarmText(root.shell.nowDate)
                visible: nx !== ""
                implicitHeight: 46 * root.s
                implicitWidth: ar.implicitWidth + 36
                radius: height / 2
                color: root.glass
                RowLayout {
                    id: ar
                    anchors.centerIn: parent
                    spacing: 8
                    Glyph { shell: root.shell; name: "alarm"; size: 20 * root.s; color: root.shell.textColor }
                    Text { text: parent.parent.nx; color: root.shell.textColor; font.family: root.shell.fontFamily; font.pixelSize: 16 * root.s; font.weight: Font.Medium }
                }
            }
            Rectangle {
                visible: root.shell.weatherTemp !== ""
                implicitHeight: 46 * root.s
                implicitWidth: we.implicitWidth + 36
                radius: height / 2
                color: root.glass
                RowLayout {
                    id: we
                    anchors.centerIn: parent
                    spacing: 8
                    Glyph { shell: root.shell; name: "cloud"; size: 20 * root.s; color: root.shell.textColor }
                    Text { text: root.shell.weatherTemp + "  " + root.shell.weatherDesc; color: root.shell.textColor; font.family: root.shell.fontFamily; font.pixelSize: 16 * root.s; font.weight: Font.Medium }
                }
            }
            Rectangle {
                readonly property var b: UPower.displayDevice
                visible: !!(b && b.isLaptopBattery)
                implicitHeight: 46 * root.s
                implicitWidth: bt.implicitWidth + 36
                radius: height / 2
                color: root.glass
                Text {
                    id: bt
                    anchors.centerIn: parent
                    text: parent.b ? Math.round(parent.b.percentage * 100) + "%" + (parent.b.state === UPowerDeviceState.Charging ? "  •  Charging" : "") : ""
                    color: root.shell.textColor
                    font.family: root.shell.fontFamily
                    font.pixelSize: 16 * root.s
                    font.weight: Font.Medium
                }
            }
        }
    }

    // ---------- avatar, name, password, power ----------
    ColumnLayout {
        id: bottomCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36 * root.s
        spacing: 12 * root.s
        opacity: root.stage(0.4)
        transform: Translate { y: (1 - root.stage(0.4)) * 50 }

        // avatar
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 92 * root.s
            implicitHeight: 92 * root.s
            Item { id: mask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: width / 2 } }
            Image {
                id: av1
                anchors.fill: parent
                visible: false
                source: "file://" + (root.shell.cv("lock.avatar", "") !== "" ? root.shell.cv("lock.avatar", "") : Quickshell.env("HOME") + "/.face")
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(200, 200)
            }
            Image {
                id: av2
                anchors.fill: parent
                visible: false
                source: av1.status === Image.Ready ? "" : "file:///var/lib/AccountsService/icons/" + Quickshell.env("USER")
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(200, 200)
            }
            MultiEffect {
                anchors.fill: parent
                source: av1.status === Image.Ready ? av1 : av2
                maskEnabled: true
                maskSource: mask
                visible: av1.status === Image.Ready || av2.status === Image.Ready
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: av1.status !== Image.Ready && av2.status !== Image.Ready
                color: root.shell.tileActive
                Text { anchors.centerIn: parent; text: root.userName.charAt(0); color: root.shell.textColor; font.family: root.shell.fontFamily; font.pixelSize: 44 * root.s; font.weight: Font.Bold }
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.userName
            color: root.shell.textColor
            font.family: root.shell.fontFamily
            font.pixelSize: 24 * root.s
            font.weight: Font.DemiBold
        }

        // wrong password message
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: root.ctl.pamState === "error"
            implicitHeight: 32 * root.s
            implicitWidth: er.implicitWidth + 28
            radius: height / 2
            color: "#B3261E"
            Text { id: er; anchors.centerIn: parent; text: root.ctl.errorText; color: root.shell.textColor; font.family: root.shell.fontFamily; font.pixelSize: 14 * root.s; font.weight: Font.Medium }
        }

        // password field
        Rectangle {
            id: field
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 380 * root.s
            implicitHeight: 60 * root.s
            radius: height / 2
            color: root.glass
            border.width: 2
            border.color: input.activeFocus ? "#FFFFFF" : "#40FFFFFF"
            transform: Translate { id: shake }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shake; property: "x"; to: -16; duration: 50 }
                NumberAnimation { target: shake; property: "x"; to: 16; duration: 80 }
                NumberAnimation { target: shake; property: "x"; to: -10; duration: 70 }
                NumberAnimation { target: shake; property: "x"; to: 10; duration: 70 }
                NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
            }
            Connections {
                target: root.ctl
                function onFailCountChanged() { shakeAnim.restart(); input.text = ""; input.forceActiveFocus() }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 26 * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: root.ctl.pamState === "checking" ? "Checking…" : "Password"
                color: root.shell.textColor
                opacity: 0.8
                font.family: root.shell.fontFamily
                font.pixelSize: 19 * root.s
            }
            TextInput {
                id: input
                anchors.left: parent.left
                anchors.right: go.left
                anchors.leftMargin: 26 * root.s
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: root.shell.textColor
                font.family: root.shell.fontFamily
                font.pixelSize: 19 * root.s
                clip: true
                focus: true
                enabled: root.ctl.pamState !== "checking"
                onAccepted: root.ctl.tryUnlock(text)
                Keys.onEscapePressed: text = ""
                Component.onCompleted: forceActiveFocus()
            }
            Rectangle {
                id: go
                anchors.right: parent.right
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 44 * root.s; height: 44 * root.s; radius: width / 2
                color: root.shell.tileActive
                Glyph { anchors.centerIn: parent; shell: root.shell; name: "arrow_forward"; size: 24 * root.s; color: root.shell.textColor }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.ctl.tryUnlock(input.text) }
            }
        }

        // sleep / restart / power off
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8 * root.s
            spacing: 16 * root.s
            Repeater {
                model: root.shell.cv("shade.powerMenu", root.fallbackPower).filter(e => e.icon !== "lock" && e.icon !== "logout")
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: 54 * root.s; implicitHeight: 54 * root.s
                    radius: pm.pressed ? 16 : width / 2
                    Behavior on radius { NumberAnimation { duration: 160 } }
                    color: modelData.danger ? "#B3261E" : root.glass
                    Glyph { anchors.centerIn: parent; shell: root.shell; name: parent.modelData.icon; size: 24 * root.s; color: root.shell.textColor }
                    MouseArea { id: pm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(parent.modelData.command) }
                }
            }
        }
    }

    // keep typing working when the pointer clicks around
    MouseArea { anchors.fill: parent; z: -1; onClicked: input.forceActiveFocus() }
}
