import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// Pixel-style quick settings shade. Opened by swiping down from the bar or `qs ipc call shade toggle`.
Scope {
    id: shade
    required property var shell

    readonly property var sh: shell
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    property real brightness: 0.5
    property bool powerMenuOpen: false
    readonly property var defaultPowerMenu: [
        { label: "Lock", icon: "lock", command: ["qs", "ipc", "call", "lock", "lock"] },
        { label: "Sleep", icon: "sleep", command: ["systemctl", "suspend"] },
        { label: "Restart", icon: "restart", command: ["systemctl", "reboot"] },
        { label: "Power off", icon: "power", command: ["systemctl", "poweroff"], danger: true },
        { label: "Log out", icon: "logout", command: ["hyprctl", "dispatch", "exit"] }
    ]
    property bool hasBacklight: false

    // ---------- tile state ----------
    function wifiLvl() {
        const v = sh.wifiSignal
        return v < 0 ? 0 : v > 75 ? 4 : v > 50 ? 3 : v > 25 ? 2 : 1
    }
    function btConnectedName() {
        if (!adapter || !adapter.enabled) return ""
        const d = adapter.devices.values
        for (let i = 0; i < d.length; i++) if (d[i].connected) return d[i].name
        return ""
    }
    function tLabel(id) {
        switch (id) {
        case "wifi": return "Internet"
        case "bluetooth": return "Bluetooth"
        case "dnd": return "Do Not Disturb"
        case "saver": return "Battery Saver"
        case "airplane": return "Airplane mode"
        case "mute": return "Sound"
        case "mic": return "Microphone"
        }
        return id
    }
    function tIcon(id) {
        switch (id) {
        case "wifi": return sh.wifiRadio ? "wifi" : "wifi_off"
        case "bluetooth": return adapter && adapter.enabled ? "bluetooth" : "bluetooth_off"
        case "dnd": return "dnd"
        case "saver": return "saver"
        case "airplane": return "airplane"
        case "mute": return sink && sink.audio && sink.audio.muted ? "volume_off" : "volume_up"
        case "mic": return source && source.audio && source.audio.muted ? "mic_off" : "mic"
        }
        return "notification"
    }
    function tActive(id) {
        switch (id) {
        case "wifi": return sh.wifiRadio
        case "bluetooth": return !!(adapter && adapter.enabled)
        case "dnd": return sh.dnd
        case "saver": return PowerProfiles.profile === PowerProfile.PowerSaver
        case "airplane": return !sh.wifiRadio && !(adapter && adapter.enabled)
        case "mute": return !!(sink && sink.audio && !sink.audio.muted)
        case "mic": return !!(source && source.audio && !source.audio.muted)
        }
        return false
    }
    function tSub(id) {
        switch (id) {
        case "wifi":
            if (!sh.wifiRadio) return "Off"
            if (sh.ethernet) return sh.conn === "full" ? "Ethernet" : "Ethernet, no internet"
            if (sh.wifiSignal < 0) return "Not connected"
            if (sh.conn === "portal") return "Sign-in required"
            if (sh.conn === "limited" || sh.conn === "none") return "No internet"
            return sh.wifiSsid !== "" ? sh.wifiSsid : "Connected"
        case "bluetooth":
            if (!adapter || !adapter.enabled) return "Off"
            return btConnectedName() !== "" ? btConnectedName() : "On"
        case "dnd": return sh.dnd ? "On" : "Off"
        case "saver": return PowerProfiles.profile === PowerProfile.PowerSaver ? "On" : "Off"
        case "airplane": return tActive("airplane") ? "On" : "Off"
        case "mute": return !sink || !sink.audio ? "" : sink.audio.muted ? "Muted" : Math.round(sink.audio.volume * 100) + "%"
        case "mic": return source && source.audio && source.audio.muted ? "Muted" : "On"
        }
        return ""
    }
    function tToggle(id) {
        switch (id) {
        case "wifi":
            sh.wifiRadio = !sh.wifiRadio
            Quickshell.execDetached(["nmcli", "radio", "wifi", sh.wifiRadio ? "on" : "off"])
            break
        case "bluetooth":
            if (adapter) adapter.enabled = !adapter.enabled
            break
        case "dnd": sh.dnd = !sh.dnd; break
        case "saver":
            PowerProfiles.profile = PowerProfiles.profile === PowerProfile.PowerSaver ? PowerProfile.Balanced : PowerProfile.PowerSaver
            break
        case "airplane": {
            const off = sh.wifiRadio || !!(adapter && adapter.enabled)
            sh.wifiRadio = !off
            Quickshell.execDetached(["nmcli", "radio", "wifi", off ? "off" : "on"])
            if (adapter) adapter.enabled = !off
            break
        }
        case "mute": if (sink && sink.audio) sink.audio.muted = !sink.audio.muted; break
        case "mic": if (source && source.audio) source.audio.muted = !source.audio.muted; break
        }
    }

    // ---------- brightness (brightnessctl) ----------
    Process {
        id: brRead
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",")
                if (f.length >= 5) {
                    shade.brightness = parseInt(f[3]) / 100
                    shade.hasBacklight = true
                } else {
                    shade.hasBacklight = false
                }
            }
        }
    }
    function applyBrightness() { brSet.restart() }
    Timer {
        id: brSet
        interval: 80
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "set", Math.max(1, Math.round(shade.brightness * 100)) + "%"])
    }
    Connections {
        target: shade.shell
        function onShadeOpenChanged() { if (shade.shell.shadeOpen) brRead.running = true; else shade.powerMenuOpen = false }
    }

    // ---------- one fullscreen overlay per monitor ----------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: shade.sh.shadeProgress > 0.001 && (isTarget || shade.sh.cv("shade.dimOtherScreens", 0.75) > 0)
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pixel-shade"
            readonly property bool isTarget: shade.sh.shadeScreen === modelData.name
            WlrLayershell.keyboardFocus: (shade.sh.shadeOpen && isTarget) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: scene
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: { if (shade.powerMenuOpen) shade.powerMenuOpen = false; else shade.sh.closeShade() }

                readonly property real p: shade.sh.shadeProgress
                readonly property real topPad: 32
                readonly property real bottomPad: 64
                function yOf(item, mouse) { return scene.mapFromItem(item, mouse.x, mouse.y).y }

                // empty areas: tap closes, swipe up closes
                MouseArea {
                    anchors.fill: parent
                    onPressed: mouse => shade.sh.dragBegin(win.modelData.name, scene.yOf(this, mouse), scene.height)
                    onPositionChanged: mouse => { if (pressed) shade.sh.dragMove(scene.yOf(this, mouse)) }
                    onReleased: shade.sh.dragEnd()
                }

                // other monitors: just dim them while the shade is open elsewhere (tap closes)
                Rectangle {
                    anchors.fill: parent
                    visible: !win.isTarget
                    color: "black"
                    opacity: scene.p * shade.sh.cv("shade.dimOtherScreens", 0.75)
                    MouseArea { anchors.fill: parent; onClicked: shade.sh.closeShade() }
                }

                // ---------- power menu (above the sheet) ----------
                Item {
                    id: pm
                    z: 10
                    anchors.fill: parent
                    opacity: (shade.powerMenuOpen && win.isTarget) ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Rectangle { anchors.fill: parent; color: "black"; opacity: 0.6 }
                    MouseArea { anchors.fill: parent; onClicked: shade.powerMenuOpen = false }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 360
                        height: pmCol.implicitHeight + 40
                        radius: 34
                        color: shade.sh.container
                        border.width: 1
                        border.color: "#26FFFFFF"
                        scale: shade.powerMenuOpen ? 1 : 0.9
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        MouseArea { anchors.fill: parent }

                        ColumnLayout {
                            id: pmCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 8
                            Text {
                                Layout.bottomMargin: 6
                                text: "Power"
                                color: shade.sh.textColor
                                font.family: shade.sh.fontFamily
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }
                            Repeater {
                                model: shade.sh.cv("shade.powerMenu", shade.defaultPowerMenu)
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 58
                                    radius: rm.pressed ? 16 : 29
                                    Behavior on radius { NumberAnimation { duration: 160 } }
                                    color: modelData.danger ? "#B3261E" : (rm.pressed ? shade.sh.tileActive : shade.sh.containerHigh)
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 20
                                        anchors.rightMargin: 20
                                        spacing: 16
                                        Glyph { shell: shade.sh; name: parent.parent.modelData.icon; size: 24; color: shade.sh.textColor }
                                        Text {
                                            Layout.fillWidth: true
                                            text: parent.parent.modelData.label
                                            color: shade.sh.textColor
                                            font.family: shade.sh.fontFamily
                                            font.pixelSize: 16
                                            font.weight: Font.Medium
                                        }
                                    }
                                    MouseArea {
                                        id: rm
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(parent.modelData.command)
                                            shade.powerMenuOpen = false
                                            shade.sh.closeShade()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // the sheet grows from the top edge; bottom corners are round while it moves
                Item {
                    id: sheet
                    visible: win.isTarget
                    width: scene.width
                    height: scene.height * scene.p
                    clip: true

                    Rectangle {
                        id: bg
                        y: -radius
                        width: parent.width
                        height: parent.height + radius
                        radius: shade.sh.cv("shade.radius", 36) * (1 - Math.max(0, Math.min(1, (scene.p - 0.85) / 0.15)))
                        color: Qt.alpha(shade.sh.surface, shade.sh.cv("shade.backgroundOpacity", 1.0))
                    }

                    // keep taps on the sheet from reaching the closing area underneath
                    MouseArea { anchors.fill: parent }

                    ShadeBody {
                        id: bodyView
                        ctl: shade
                        p: scene.p
                        width: scene.width - 2 * shade.sh.cv("shade.sideMargin", 56) > shade.sh.cv("shade.maxWidth", 0) && shade.sh.cv("shade.maxWidth", 0) > 0 ? shade.sh.cv("shade.maxWidth", 0) : scene.width - 2 * shade.sh.cv("shade.sideMargin", 56)
                        height: scene.height - scene.topPad - scene.bottomPad
                        x: (scene.width - width) / 2
                        y: scene.topPad - (1 - scene.p) * 56
                    }

                    // handle at the bottom: drag up or tap to close
                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        y: sheet.height - 56
                        height: 56
                        opacity: scene.p
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 26
                            width: 48; height: 5; radius: 3
                            color: shade.sh.textColor
                            opacity: 0.7
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => shade.sh.dragBegin(win.modelData.name, scene.yOf(this, mouse), scene.height)
                            onPositionChanged: mouse => { if (pressed) shade.sh.dragMove(scene.yOf(this, mouse)) }
                            onReleased: shade.sh.dragEnd()
                        }
                    }
                }
            }
        }
    }
}
