import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Dynamic island (Pixel style): a black pill at the top centre that morphs between activities:
// ringing alarm > notification > volume > charging > timer > music. Tap the pill to expand it.
Scope {
    id: isl
    required property var shell
    readonly property bool enabled: shell.cv("island.enabled", true)

    property var evt: null                 // short-lived activity { kind, ... }
    property bool expanded: false
    readonly property real startedAt: Date.now()
    property string lastUid: ""

    readonly property var player: {
        const v = Mpris.players.values
        for (let i = 0; i < v.length; i++) if (v[i].isPlaying) return v[i]
        return null
    }
    readonly property bool timerOn: shell.timerEnd > 0
    readonly property string mode: shell.ringing ? "ring" : evt ? evt.kind : (timerOn && shell.cv("island.timer", true)) ? "timer"
                                  : (player && shell.cv("island.media", true)) ? "media" : "none"
    readonly property bool canExpand: mode === "media" || mode === "timer" || mode === "ring" || mode === "notif"

    function showEvt(e, ms) { evt = e; expanded = false; evtTimer.interval = ms; evtTimer.restart() }
    Timer { id: evtTimer; onTriggered: { isl.evt = null; isl.expanded = false } }
    onExpandedChanged: if (expanded && evt) { evtTimer.interval = 7000; evtTimer.restart() }
    onModeChanged: if (mode === "ring") expanded = true; else if (mode === "none") expanded = false

    // ---- cava visualizer (needs the `cava` package; without it a built-in equalizer animation is used) ----
    property var levels: []
    Process {
        id: cava
        running: isl.enabled && isl.mode === "media" && isl.shell.cv("island.cava", true)
        command: ["bash", "-c", 'c="${XDG_RUNTIME_DIR:-/tmp}/qs-cava.conf"; printf "[general]\nbars = 24\nframerate = 30\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\n" > "$c"; exec cava -p "$c"']
        stdout: SplitParser {
            onRead: data => {
                const p = data.split(";")
                const a = []
                for (let i = 0; i < p.length; i++) { const v = parseInt(p[i]); if (!isNaN(v)) a.push(v) }
                if (a.length > 0) isl.levels = a
            }
        }
        onRunningChanged: if (!running) isl.levels = []
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() { if (Date.now() - isl.startedAt > 4000 && isl.shell.cv("island.volume", true)) isl.showEvt({ kind: "volume" }, 1800) }
        function onMutedChanged() { if (Date.now() - isl.startedAt > 4000 && isl.shell.cv("island.volume", true)) isl.showEvt({ kind: "volume" }, 1800) }
    }
    Connections {
        target: UPower.displayDevice
        function onStateChanged() {
            if (Date.now() - isl.startedAt > 4000 && UPower.displayDevice.state === UPowerDeviceState.Charging && isl.shell.cv("island.charging", true))
                isl.showEvt({ kind: "charging" }, 4000)
        }
    }
    Connections {
        target: isl.shell
        function onRecordsChanged() {
            const r = isl.shell.records
            if (r.length === 0 || r[0].uid === isl.lastUid) return
            isl.lastUid = r[0].uid
            if (Date.now() - isl.startedAt < 4000 || isl.shell.dnd || !isl.shell.cv("island.notifications", true)) return
            isl.showEvt({ kind: "notif", rec: r[0] }, 5000)
        }
    }

    Variants {
        model: isl.enabled ? Quickshell.screens : []

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: modelData.name === isl.shell.mainScreenName && (isl.mode !== "none" || pill.width > 3)
            anchors.top: true
            margins.top: (isl.shell.cv("island.placement", "bar") === "below" ? isl.shell.barHeight + 6 : Math.max(0, Math.round((isl.shell.barHeight - pill.h0) / 2))) + isl.shell.cv("island.topOffset", 0)
            implicitWidth: 460
            implicitHeight: 220
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region { item: pill }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pixel-island"

            Rectangle {
                id: pill
                readonly property real h0: Math.max(26, Math.round(isl.shell.barHeight * 0.9))
                readonly property bool open: isl.expanded && isl.canExpand
                readonly property real tw: isl.mode === "none" ? 0
                    : open ? (isl.mode === "timer" ? 300 : isl.mode === "ring" ? 340 : 390)
                    : ({ media: 190, timer: 124, ring: 220, charging: 118, volume: 190, notif: 250 })[isl.mode]
                readonly property real th: isl.mode === "none" ? 0
                    : open ? (isl.mode === "timer" ? 104 : isl.mode === "ring" ? 112 : isl.mode === "notif" ? 150 : 146) : h0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: tw
                height: th
                radius: open ? 34 : height / 2
                color: isl.shell.cv("island.color", "#000000")
                border.width: open ? 1 : 0
                border.color: "#26FFFFFF"
                opacity: isl.mode === "none" ? 0 : 1
                clip: true
                // M3E spatial springs for size, effects spring for fade
                Behavior on width { SpringAnimation { spring: 4.5; damping: 0.3; epsilon: 0.4 } }
                Behavior on height { SpringAnimation { spring: 4.5; damping: 0.3; epsilon: 0.4 } }
                Behavior on radius { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 180 } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: isl.canExpand ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (isl.canExpand) isl.expanded = !isl.expanded
                }

                // ================= compact =================
                Item {
                    id: compact
                    anchors.fill: parent
                    opacity: pill.open ? 0 : 1
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    // music
                    RowLayout {
                        visible: isl.mode === "media"
                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 14; spacing: 8
                        Rectangle {
                            Layout.preferredWidth: pill.h0 - 8; Layout.preferredHeight: pill.h0 - 8; radius: 8; color: "#22FFFFFF"; clip: true
                            Image { anchors.fill: parent; source: isl.player ? isl.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(64, 64) }
                        }
                        Text { Layout.fillWidth: true; text: isl.player ? isl.player.trackTitle : ""; elide: Text.ElideRight; color: "white"; font.family: isl.shell.fontFamily; font.pixelSize: 13; font.weight: Font.Medium }
                        Item {
                            Layout.preferredWidth: 28; Layout.preferredHeight: 16; Layout.alignment: Qt.AlignVCenter
                            Row {                                    // real cava levels
                                visible: isl.levels.length > 0
                                anchors.fill: parent; spacing: 2.5
                                Repeater {
                                    model: 6
                                    delegate: Rectangle {
                                        required property int index
                                        width: 3; radius: 1.5; color: "white"; anchors.bottom: parent.bottom
                                        height: 3 + 13 * Math.min(1, (isl.levels[Math.floor(index * isl.levels.length / 6)] || 0) / 100)
                                        Behavior on height { NumberAnimation { duration: 60 } }
                                    }
                                }
                            }
                            Row {                                    // fallback animation
                                visible: isl.levels.length === 0
                                anchors.fill: parent; spacing: 2.5
                                Repeater {
                                    model: 4
                                    delegate: Rectangle {
                                        required property int index
                                        width: 3; radius: 1.5; color: "white"; anchors.bottom: parent.bottom
                                        height: 4
                                        SequentialAnimation on height {
                                            running: isl.mode === "media" && isl.levels.length === 0
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 6 + index * 3 % 9; duration: 260 + index * 70; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 14 - index * 2; duration: 300 + index * 50; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 4; duration: 240; easing.type: Easing.InOutSine }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // timer
                    RowLayout {
                        visible: isl.mode === "timer"
                        anchors.centerIn: parent; spacing: 7
                        Glyph { shell: isl.shell; name: "timer"; size: 16; color: "white" }
                        Text { text: pill.mmss; color: "white"; font.family: isl.shell.fontFamily; font.pixelSize: 14; font.weight: Font.Bold }
                    }
                    // alarm ringing
                    RowLayout {
                        visible: isl.mode === "ring"
                        anchors.centerIn: parent; spacing: 8
                        Glyph {
                            shell: isl.shell; name: "alarm"; size: 17; color: "white"
                            SequentialAnimation on rotation { running: isl.mode === "ring"; loops: Animation.Infinite
                                NumberAnimation { to: 16; duration: 80 } NumberAnimation { to: -16; duration: 160 } NumberAnimation { to: 0; duration: 80 } PauseAnimation { duration: 400 } }
                        }
                        Text { text: isl.shell.ringLabel; color: "white"; font.family: isl.shell.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                    }
                    // charging
                    RowLayout {
                        visible: isl.mode === "charging"
                        anchors.centerIn: parent; spacing: 5
                        Glyph { shell: isl.shell; name: "bolt"; size: 17; color: "#6DD58C" }
                        Text { text: Math.round((UPower.displayDevice ? UPower.displayDevice.percentage : 0) * 100) + "%"; color: "#6DD58C"; font.family: isl.shell.fontFamily; font.pixelSize: 14; font.weight: Font.Bold }
                    }
                    // volume
                    RowLayout {
                        visible: isl.mode === "volume"
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 16; spacing: 8
                        readonly property var au: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
                        Glyph { shell: isl.shell; name: parent.au && parent.au.muted ? "volume_off" : "volume_up"; size: 17; color: "white" }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3; color: "#33FFFFFF"
                            Rectangle {
                                height: parent.height; radius: 3; color: "white"
                                width: parent.width * Math.min(1, parent.parent.au && !parent.parent.au.muted ? parent.parent.au.volume : 0)
                                Behavior on width { SpringAnimation { spring: 8; damping: 0.5; epsilon: 0.5 } }
                            }
                        }
                    }
                    // notification
                    RowLayout {
                        visible: isl.mode === "notif"
                        anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 14; spacing: 8
                        Rectangle {
                            Layout.preferredWidth: pill.h0 - 8; Layout.preferredHeight: pill.h0 - 8; radius: width / 2; color: "#22FFFFFF"; clip: true
                            Image { id: nIcon; anchors.fill: parent; anchors.margins: 3; source: isl.evt && isl.evt.rec ? isl.shell.notifIconSource(isl.evt.rec) : ""; fillMode: Image.PreserveAspectFit; sourceSize: Qt.size(48, 48); visible: status === Image.Ready }
                            Glyph { anchors.centerIn: parent; shell: isl.shell; name: "notification"; size: 14; color: "white"; visible: nIcon.status !== Image.Ready }
                        }
                        Text { Layout.fillWidth: true; text: isl.evt && isl.evt.rec ? isl.evt.rec.summary : ""; elide: Text.ElideRight; color: "white"; font.family: isl.shell.fontFamily; font.pixelSize: 13; font.weight: Font.Medium }
                    }
                }

                readonly property real rem: Math.max(0, (isl.shell.timerEnd - isl.shell.nowMs) / 1000)
                readonly property string mmss: {
                    const t = Math.ceil(rem)
                    const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), s = t % 60
                    return (h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (s < 10 ? "0" : "") + s
                }

                // ================= expanded =================
                Item {
                    id: full
                    anchors.fill: parent
                    opacity: pill.open ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 220 } }

                    // music
                    Row {                                          // wide cava strip
                        visible: isl.mode === "media" && isl.levels.length > 0
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.bottomMargin: 12
                        height: 24; spacing: 3
                        Repeater {
                            model: 24
                            delegate: Rectangle {
                                required property int index
                                width: (pill.width - 32 - 3 * 23) / 24
                                anchors.bottom: parent.bottom
                                radius: width / 2
                                color: isl.shell.tileActive
                                height: 3 + 21 * Math.min(1, (isl.levels[Math.floor(index * isl.levels.length / 24)] || 0) / 100)
                                Behavior on height { NumberAnimation { duration: 60 } }
                            }
                        }
                    }
                    RowLayout {
                        visible: isl.mode === "media"
                        anchors.fill: parent; anchors.margins: 16; anchors.bottomMargin: isl.levels.length > 0 ? 44 : 16; spacing: 14
                        Rectangle {
                            Layout.preferredWidth: 80; Layout.preferredHeight: 80; radius: 20; color: "#22FFFFFF"; clip: true
                            Image { anchors.fill: parent; source: isl.player ? isl.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(176, 176) }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { Layout.fillWidth: true; text: isl.player ? isl.player.trackTitle : ""; elide: Text.ElideRight; color: "white"; font.family: isl.shell.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Text { Layout.fillWidth: true; text: isl.player ? isl.player.trackArtist : ""; elide: Text.ElideRight; color: "white"; opacity: 0.8; font.family: isl.shell.fontFamily; font.pixelSize: 14 }
                            Item { Layout.fillHeight: true }
                            RowLayout {
                                spacing: 10
                                IslandButton { shell: isl.shell; icon: "skip_prev"; fill: "#2A2D34"; onClicked: if (isl.player) isl.player.previous() }
                                IslandButton { shell: isl.shell; icon: isl.player && isl.player.isPlaying ? "pause" : "play"; fill: isl.shell.tileActive; implicitWidth: 64; onClicked: if (isl.player) isl.player.togglePlaying() }
                                IslandButton { shell: isl.shell; icon: "skip_next"; fill: "#2A2D34"; onClicked: if (isl.player) isl.player.next() }
                            }
                        }
                    }
                    // timer
                    ColumnLayout {
                        visible: isl.mode === "timer"
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Glyph { shell: isl.shell; name: "timer"; size: 22; color: "white" }
                            Text { text: pill.mmss; color: "white"; font.family: isl.shell.cv("bar.clockFont", isl.shell.fontFamily); font.pixelSize: 32; font.weight: Font.Bold }
                            Item { Layout.fillWidth: true }
                            IslandButton { shell: isl.shell; icon: "close"; label: "Cancel"; fill: "#B3261E"; implicitHeight: 40; onClicked: isl.shell.cancelTimer() }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3; color: "#33FFFFFF"
                            Rectangle { height: parent.height; radius: 3; color: isl.shell.tileActive
                                width: parent.width * (isl.shell.timerTotal > 0 ? 1 - pill.rem / (isl.shell.timerTotal / 1000) : 0)
                                Behavior on width { NumberAnimation { duration: 900 } } }
                        }
                    }
                    // ringing
                    ColumnLayout {
                        visible: isl.mode === "ring"
                        anchors.fill: parent; anchors.margins: 16; spacing: 10
                        RowLayout {
                            Glyph { shell: isl.shell; name: "alarm"; size: 24; color: "white" }
                            Text { Layout.fillWidth: true; text: isl.shell.ringLabel; elide: Text.ElideRight; color: "white"; font.family: isl.shell.fontFamily; font.pixelSize: 18; font.weight: Font.DemiBold }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            IslandButton { Layout.fillWidth: true; shell: isl.shell; icon: "snooze"; label: "Snooze"; fill: "#2A2D34"; onClicked: isl.shell.snooze(10) }
                            IslandButton { Layout.fillWidth: true; shell: isl.shell; icon: "close"; label: "Stop"; fill: isl.shell.tileActive; onClicked: isl.shell.stopRing() }
                        }
                    }
                    // notification
                    ColumnLayout {
                        visible: isl.mode === "notif"
                        anchors.fill: parent; anchors.margins: 16; spacing: 4
                        Text { text: isl.evt && isl.evt.rec ? isl.evt.rec.appName : ""; color: "white"; opacity: 0.7; font.family: isl.shell.fontFamily; font.pixelSize: 12 }
                        Text { Layout.fillWidth: true; text: isl.evt && isl.evt.rec ? isl.evt.rec.summary : ""; elide: Text.ElideRight; color: "white"; font.family: isl.shell.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { Layout.fillWidth: true; Layout.fillHeight: true; text: isl.evt && isl.evt.rec ? isl.evt.rec.body : ""; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; color: "white"; opacity: 0.9; font.family: isl.shell.fontFamily; font.pixelSize: 13 }
                        RowLayout {
                            spacing: 8
                            IslandButton { shell: isl.shell; icon: "close"; label: "Dismiss"; fill: "#2A2D34"; implicitHeight: 36
                                onClicked: { if (isl.evt && isl.evt.rec) isl.shell.dismissRecord(isl.evt.rec.uid); isl.evt = null; isl.expanded = false } }
                        }
                    }
                }
            }
        }
    }
}
