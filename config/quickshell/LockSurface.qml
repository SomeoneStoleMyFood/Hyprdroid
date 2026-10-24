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
    // ---- Material 3 Expressive motion ----
    // intro: spatial springs (slight overshoot) for position/scale, emphasized-decelerate for opacity
    // outro: field morphs into a check circle, then everything leaves with emphasized-accelerate
    property real outro: 0
    Connections {
        target: root.ctl
        function onUnlockingChanged() { if (root.ctl.unlocking) outroAnim.start() }
    }
    SequentialAnimation {
        id: outroAnim
        PauseAnimation { duration: 260 }
        NumberAnimation { target: root; property: "outro"; from: 0; to: 1; duration: 340
            easing.type: Easing.BezierSpline; easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1] }
    }
    function eo(t) { return 1 - Math.pow(1 - t, 3) }
    function sp(t) { return t <= 0 ? 0 : t >= 1 ? 1 : 1 - Math.exp(-6.5 * t) * Math.cos(12 * t) }
    property real intro: 0
    NumberAnimation on intro { from: 0; to: 1; duration: 1300 }
    function stage(delay) { return Math.max(0, Math.min(1, intro * 1.6 - delay)) }

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
        NumberAnimation on scale { from: 1.0; to: 1.07; duration: 30000; easing.type: Easing.OutSine }
        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: root.eo(root.intro) * (1 - root.outro)
        }
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: 0.3 * root.intro * (1 - root.outro) }

    // ---------- clock: big stacked digits, lower on the screen like on Pixel ----------
    ColumnLayout {
        id: clockBlock
        opacity: 1 - root.outro
        transform: Translate { y: -root.outro * root.height * 0.1 }
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.2
        spacing: 0
        // slow "breathing" so the screen never feels static
        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 1.015; duration: 4200; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.015; to: 1; duration: 4200; easing.type: Easing.InOutSine }
        }
        ClockDigits {
            lock: root
            Layout.alignment: Qt.AlignHCenter
            delay: 0
            text: Qt.formatDateTime(root.shell.nowDate, root.shell.use24h ? "HH" : "h")
            color: root.shell.textColor
        }
        ClockDigits {
            lock: root
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Math.round(root.height * 0.045)
            delay: 0.12
            text: Qt.formatDateTime(root.shell.nowDate, "mm")
            color: root.shell.cv("lock.tintMinutes", true) ? root.shell.primary : root.shell.textColor
        }
        // date + weather
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6 * root.s
            spacing: 10 * root.s
            opacity: root.eo(root.stage(0.3))
            transform: Translate { y: (1 - root.sp(root.stage(0.3))) * 24 }
            Text {
                text: Qt.formatDateTime(root.shell.nowDate, "ddd, d MMM")
                color: root.shell.textColor
                font.family: root.shell.fontFamily
                font.pixelSize: Math.round(24 * root.s)
                font.weight: Font.Medium
            }
            Rectangle { visible: root.shell.weatherTemp !== ""; width: 4; height: 4; radius: 2; color: root.shell.textColor; opacity: 0.7 }
            Glyph { visible: root.shell.weatherTemp !== ""; shell: root.shell; name: "cloud"; size: 24 * root.s; color: root.shell.textColor }
            Text {
                visible: root.shell.weatherTemp !== ""
                text: root.shell.weatherTemp
                color: root.shell.textColor
                font.family: root.shell.fontFamily
                font.pixelSize: Math.round(24 * root.s)
                font.weight: Font.Medium
            }
        }
        // icons of apps with notifications
        Row {
            id: notifRow
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14 * root.s
            spacing: 10 * root.s
            Repeater {
                model: {
                    const seen = {}, out = []
                    const all = root.shell.records
                    for (let i = 0; i < all.length && out.length < 6; i++) {
                        const k = all[i].appName
                        if (!seen[k]) { seen[k] = true; out.push(all[i]) }
                    }
                    return out
                }
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 40 * root.s; height: 40 * root.s; radius: width / 2
                    color: root.glass
                    clip: true
                    property real appear: root.sp(root.stage(0.45 + index * 0.06))
                    opacity: Math.min(1, appear)
                    scale: 0.4 + 0.6 * appear
                    Image {
                        anchors.centerIn: parent
                        width: 24 * root.s; height: 24 * root.s
                        source: root.shell.notifIconSource(parent.modelData)
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                    }
                    Glyph { anchors.centerIn: parent; shell: root.shell; name: "notification"; size: 20 * root.s; color: root.shell.textColor; visible: false }
                }
            }
        }
    }

    // ---------- widgets ----------
    ColumnLayout {
        id: widgets
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.58 - height / 2
        spacing: 12 * root.s
        opacity: root.eo(root.stage(0.25)) * (1 - root.outro)
        transform: Translate { y: (1 - root.sp(root.stage(0.25))) * 30 - root.outro * 40 }

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

    }

    // ---------- music (bottom left) ----------
        Rectangle {
            visible: root.player !== null && root.shell.cv("lock.showMedia", true)
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 36 * root.s
            opacity: root.eo(root.stage(0.5)) * (1 - root.outro)
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

    // ---------- avatar, name, password, power ----------
    ColumnLayout {
        id: bottomCol
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36 * root.s
        spacing: 12 * root.s
        opacity: root.eo(root.stage(0.4)) * (1 - root.outro)
        transform: Translate { y: (1 - root.sp(root.stage(0.4))) * 50 + root.outro * 80 }

        // hint
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 28 * root.s; implicitHeight: 22 * root.s
            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                shell: root.shell; name: "expand_more"; size: 26 * root.s; color: root.shell.textColor
                rotation: 180
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    NumberAnimation { from: 2; to: -6; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: -6; to: 2; duration: 900; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.4; to: 1; duration: 900 }
                    NumberAnimation { from: 1; to: 0.4; duration: 900 }
                }
            }
        }
        // avatar
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 92 * root.s
            implicitHeight: 92 * root.s
            ShapeDot { id: mask; kind: root.shell.cv("lock.avatarShape", "cookie"); color: "black"; size: 92 * root.s; visible: false; layer.enabled: true }
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
            Item {
                anchors.fill: parent
                visible: av1.status !== Image.Ready && av2.status !== Image.Ready
                ShapeDot { anchors.fill: parent; kind: root.shell.cv("lock.avatarShape", "cookie"); color: root.shell.tileActive; size: 92 * root.s }
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
            scale: visible ? 1 : 0.6
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            implicitHeight: 32 * root.s
            implicitWidth: er.implicitWidth + 56
            radius: height / 2
            color: "#B3261E"
            Glyph { id: eri; anchors.verticalCenter: parent.verticalCenter; x: 10; shell: root.shell; name: "error"; size: 18; color: root.shell.textColor }
            Text { id: er; anchors.centerIn: parent; anchors.horizontalCenterOffset: 12; text: root.ctl.errorText; color: root.shell.textColor; font.family: root.shell.fontFamily; font.pixelSize: 14 * root.s; font.weight: Font.Medium }
        }

        // password field
        Rectangle {
            id: field
            Layout.alignment: Qt.AlignHCenter
            property real fade: root.ctl.unlocking ? 0 : 1
            Behavior on fade { NumberAnimation { duration: 140 } }
            clip: true
            implicitWidth: (root.ctl.unlocking ? 60 : 380) * root.s
            Behavior on implicitWidth { SpringAnimation { spring: 5; damping: 0.32; epsilon: 0.4 } }
            implicitHeight: 60 * root.s
            radius: height / 2
            color: root.ctl.unlocking ? "#2E7D4F" : root.glass
            Behavior on color { ColorAnimation { duration: 200 } }
            border.width: 2
            border.color: root.ctl.unlocking ? "#6DD58C" : input.activeFocus ? "#FFFFFF" : "#40FFFFFF"
            Behavior on border.color { ColorAnimation { duration: 200 } }
            transform: Translate { id: shake }
            SpringAnimation { id: shakeSpring; target: shake; property: "x"; to: 0; spring: 7; damping: 0.1; epsilon: 0.5 }
            Connections {
                target: root.ctl
                function onFailCountChanged() { shake.x = 30; shakeSpring.restart(); input.text = ""; input.forceActiveFocus() }
            }

            Glyph { anchors.left: parent.left; anchors.leftMargin: 22 * root.s; anchors.verticalCenter: parent.verticalCenter; shell: root.shell; name: "lock"; size: 22 * root.s; color: root.shell.textColor; opacity: field.fade }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 56 * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: root.ctl.pamState === "checking" ? "Checking…" : "Password"
                color: root.shell.textColor
                opacity: 0.8 * field.fade
                font.family: root.shell.fontFamily
                font.pixelSize: 19 * root.s
            }
            TextInput {
                id: input
                anchors.left: parent.left
                anchors.right: go.left
                anchors.leftMargin: 56 * root.s
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                opacity: field.fade
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: "transparent"                     // the typed characters are drawn as M3E shapes below
                selectionColor: "transparent"
                cursorDelegate: Item {}
                font.family: root.shell.fontFamily
                font.pixelSize: 19 * root.s
                clip: true
                focus: true
                enabled: root.ctl.pamState !== "checking"
                onAccepted: root.ctl.tryUnlock(text)
                Keys.onEscapePressed: text = ""
                Component.onCompleted: forceActiveFocus()
            }
            // typed characters -> Material 3 Expressive shapes
            Row {
                id: dots
                readonly property int n: Math.min(input.text.length, 14)
                readonly property real dot: Math.max(12 * root.s, Math.min(24 * root.s, (field.width - 56 * root.s - 70 * root.s) / Math.max(1, n) - 7))
                anchors.left: parent.left
                anchors.leftMargin: 56 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                opacity: field.fade
                Repeater {
                    model: dots.n
                    delegate: ShapeDot {
                        id: dot
                        required property int index
                        readonly property var order: ["cookie", "clover", "flower", "burst", "softsquare", "heart", "diamond", "pentagon", "pill", "oval"]
                        readonly property var tints: [root.shell.primary, "#F2B8B5", "#B8E6C1", "#F9D66F", "#C6B8FF", "#8AD7F2"]
                        kind: order[(index * 3 + 1) % order.length]
                        color: tints[(index * 5 + 2) % tints.length]
                        size: dots.dot
                        property real pop: 0
                        Component.onCompleted: pop = 1
                        Behavior on pop { SpringAnimation { spring: 6; damping: 0.28; epsilon: 0.002 } }
                        scale: pop
                        rotation: (1 - pop) * -90
                        SequentialAnimation on rotation {            // gentle idle wobble
                            loops: Animation.Infinite
                            running: dot.pop >= 1
                            NumberAnimation { from: -6; to: 6; duration: 1400 + dot.index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 6; to: -6; duration: 1400 + dot.index * 90; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
            Rectangle {
                id: go
                anchors.right: parent.right
                anchors.rightMargin: 8 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 44 * root.s; height: 44 * root.s; radius: width / 2
                color: root.shell.tileActive
                Glyph {
                    anchors.centerIn: parent; shell: root.shell
                    name: root.ctl.unlocking ? "check" : "arrow_forward"; size: 24 * root.s; color: root.shell.textColor
                    NumberAnimation on rotation { running: root.ctl.pamState === "checking"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.ctl.tryUnlock(input.text) }
            }
        }

    }

    // ---------- power buttons (bottom right) ----------
                RowLayout {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 36 * root.s
            opacity: root.eo(root.stage(0.5)) * (1 - root.outro)
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

    // keep typing working when the pointer clicks around
    MouseArea { anchors.fill: parent; z: -1; onClicked: input.forceActiveFocus() }
}
