//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import QtMultimedia

// Pixel / Pixel Experience style status bar for Hyprland.
//  - hides when a window is fullscreen on that monitor; hover the top edge to reveal it
//  - icons: ./icons/<name>.svg when present, otherwise drawn by QML itself
ShellRoot {
    id: root

    // ---------- config (config.json next to this file, hot-reloaded) ----------
    property var cfg: ({})
    property bool launched: false
    function cv(path, def) {
        let o = cfg
        const parts = path.split(".")
        for (let i = 0; i < parts.length; i++) {
            if (o === undefined || o === null || typeof o !== "object") return def
            o = o[parts[i]]
        }
        return (o === undefined || o === null) ? def : o
    }
    FileView {
        id: cfgFile
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.cfg = JSON.parse(text()) } catch (e) { console.warn("config.json:", e) }
            if (!root.launched) {
                root.launched = true
                if (root.playOnLaunch) root.startStartup()
            }
        }
        onLoadFailed: error => {
            console.warn("config.json not loaded, using defaults:", error)
            if (!root.launched) root.launched = true
        }
    }

    // ---------- style ----------
    readonly property color fg: cv("colors.fg", "#FFFFFF")
    readonly property color fgDim: cv("colors.fgDim", "#B3FFFFFF")
    readonly property color track: cv("colors.track", "#59FFFFFF")
    readonly property color warn: cv("colors.warn", "#F2B8B5")
    readonly property color saver: cv("colors.saver", "#F9D66F")
    readonly property color privacyGreen: cv("colors.privacyGreen", "#6DD58C")
    readonly property color privacyInk: cv("colors.privacyInk", "#00391A")
    readonly property color surface: cv("colors.surface", "#1D1F24")
    readonly property color container: cv("colors.container", "#2A2D34")
    readonly property color containerHigh: cv("colors.containerHigh", "#3B3F48")
    readonly property color onSurface: cv("colors.onSurface", "#FFFFFF")
    readonly property color onSurfaceVar: cv("colors.onSurfaceVar", "#FFFFFF")
    readonly property color primary: cv("colors.primary", "#8AB4FF")
    readonly property color onPrimary: cv("colors.onPrimary", "#062E6F")
    readonly property color primaryContainer: cv("colors.primaryContainer", "#2E4A73")
    readonly property color textColor: cv("colors.text", "#FFFFFF")      // every label in the shade / toasts
    readonly property color tileActive: cv("colors.tileActive", "#2F6FE4")
    readonly property color onTileActive: cv("colors.onTileActive", "#FFFFFF")
    readonly property color onPrimaryContainer: cv("colors.onPrimaryContainer", "#FFFFFF")
    readonly property string fontFamily: cv("bar.font", "Google Sans Flex")
    readonly property bool use24h: cv("bar.use24h", true)
    readonly property bool monoNotifIcons: cv("bar.monoNotifIcons", false)
    // bar thickness = percent of the main screen's height, clamped to [minHeight, maxHeight]
    readonly property real refScreenHeight: {
        const sc = Quickshell.screens
        for (let i = 0; i < sc.length; i++) if (sc[i].name === mainScreenName) return sc[i].height
        return sc.length > 0 ? sc[0].height : 1080
    }
    readonly property int barHeight: Math.max(cv("bar.minHeight", 22),
        Math.min(cv("bar.maxHeight", 56), Math.round(refScreenHeight * cv("bar.heightPercent", 2.4) / 100)))
    readonly property real ui: barHeight / 26      // scale factor for everything inside the bar
    readonly property int iconSize: Math.round(barHeight * cv("bar.iconScale", 0.55))
    readonly property int notifIconSize: iconSize
    readonly property int maxNotifIcons: cv("bar.maxNotifIcons", 5)
    readonly property int hoverStrip: cv("bar.hoverStrip", 3)

    // ---------- state ----------
    property bool dnd: false
    property var alarms: []                 // {id, time:"HH:mm", label, enabled, daily, lastFired, temp}
    property real timerEnd: 0               // epoch ms, 0 = no timer
    property real timerTotal: 0
    property real nowMs: Date.now()         // ticks every second
    property bool ringing: false
    property string ringLabel: ""
    property var records: []                // notifications kept until you close them (newest first)
    property var live: ({})                 // record uid -> live Notification (this session only)
    property bool stateLoaded: false
    property string weatherTemp: ""
    property string weatherDesc: ""
    readonly property int alarmCount: alarms.filter(a => a.enabled).length
    property int wifiSignal: -1
    property bool ethernet: false
    property bool vpn: false
    property bool wifiRadio: true
    property int cellSignal: -1
    property bool hotspot: false
    property string wifiSsid: ""
    property string conn: "full"          // NetworkManager connectivity: full / limited / portal / none
    property bool micActive: false
    property bool camActive: false
    property var fsMonitors: []

    // ---------- startup animation: qs ipc call startup play ----------
    readonly property url startupVideo: Qt.resolvedUrl(cv("startup.video", "start.mp4"))   // next to shell.qml
    readonly property string mainMonitorName: cv("startup.mainMonitor", "")   // "" = the system main monitor (at 0,0)
    readonly property real videoVolume: cv("startup.volume", 1.0)
    readonly property bool playOnLaunch: cv("startup.playOnLaunch", false)
    property bool startupActive: false
    property real blackLevel: 0                    // jumps to 1 instantly, fades out at the end
    property var videoSink: null
    readonly property string mainScreenName: {
        if (mainMonitorName !== "") return mainMonitorName
        const s = Quickshell.screens
        for (let i = 0; i < s.length; i++)
            if (s[i].x === 0 && s[i].y === 0) return s[i].name
        return s.length > 0 ? s[0].name : ""
    }
    NumberAnimation { id: fadeOut; target: root; property: "blackLevel"; to: 0; duration: 350 }

    // ---------- vector icon data (24x24 grid) ----------
    readonly property var iconPaths: ({
        "notification": "M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z",
        "media": "M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z",
        "dnd": "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 11H7v-2h10v2z",
        "alarm": "M22 5.72l-4.6-3.86-1.29 1.53 4.6 3.86L22 5.72zM7.88 3.39L6.6 1.86 2 5.71l1.29 1.53 4.59-3.85zM12.5 8H11v6l4.75 2.85.75-1.23-4-2.37V8zM12 4c-4.97 0-9 4.03-9 9s4.02 9 9 9c4.97 0 9-4.03 9-9s-4.03-9-9-9zm0 16c-3.87 0-7-3.13-7-7s3.13-7 7-7 7 3.13 7 7-3.13 7-7 7z",
        "mic": "M12 14c1.66 0 2.99-1.34 2.99-3L15 5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.3-3c0 3-2.54 5.1-5.3 5.1S6.7 14 6.7 11H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c3.28-.48 6-3.3 6-6.72h-1.7z",
        "mic_off": "M19 11h-1.7c0 .74-.16 1.43-.43 2.05l1.23 1.23c.56-.98.9-2.09.9-3.28zm-4.02.17c0-.06.02-.11.02-.17V5c0-1.66-1.34-3-3-3S9 3.34 9 5v.18l5.98 5.99zM4.27 3L3 4.27l6.01 6.01V11c0 1.66 1.33 3 2.99 3 .22 0 .44-.03.65-.08l1.66 1.66c-.71.33-1.5.52-2.31.52-2.76 0-5.3-2.1-5.3-5.1H5c0 3.41 2.72 6.23 6 6.72V21h2v-3.28c.91-.13 1.77-.45 2.54-.9L19.73 21 21 19.73 4.27 3z",
        "camera": "M17 10.5V7c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.55 0 1-.45 1-1v-3.5l4 4v-11l-4 4z",
        "volume_off": "M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z",
        "hotspot": "M12 11c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm6 2c0-3.31-2.69-6-6-6s-6 2.69-6 6c0 2.22 1.21 4.15 3 5.19l1-1.74c-1.19-.7-2-1.97-2-3.45 0-2.21 1.79-4 4-4s4 1.79 4 4c0 1.48-.81 2.75-2 3.45l1 1.74c1.79-1.04 3-2.97 3-5.19zM12 3C6.48 3 2 7.48 2 13c0 3.7 2.01 6.92 4.99 8.65l1-1.73C5.61 18.53 4 15.96 4 13c0-4.42 3.58-8 8-8s8 3.58 8 8c0 2.96-1.61 5.53-4 6.92l1 1.73c2.99-1.73 5-4.95 5-8.65 0-5.52-4.48-10-10-10z",
        "bluetooth": "M17.71 7.71L12 2h-1v7.59L6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 11 14.41V22h1l5.71-5.71-4.3-4.29 4.3-4.29zM13 5.83l1.88 1.88L13 9.59V5.83zm1.88 10.46L13 18.17v-3.76l1.88 1.88z",
        "bluetooth_connected": "M7 12l-2-2-2 2 2 2 2-2zm10.71-4.29L12 2h-1v7.59L6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 11 14.41V22h1l5.71-5.71-4.3-4.29 4.3-4.29zM13 5.83l1.88 1.88L13 9.59V5.83zm1.88 10.46L13 18.17v-3.76l1.88 1.88zM19 10l-2 2 2 2 2-2-2-2z",
        "vpn": "M12.65 10C11.83 7.67 9.61 6 7 6c-3.31 0-6 2.69-6 6s2.69 6 6 6c2.61 0 4.83-1.67 5.65-4H17v4h4v-4h2v-4H12.65zM7 14c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z",
        "airplane": "M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z",
        "ethernet": "M13 22h8v-7h-3v-4h-5V9h3V2H8v7h3v2H6v4H3v7h8v-7H8v-2h8v2h-3z",
        "bluetooth_off": "M13 5.83l1.88 1.88-1.6 1.6 1.41 1.41 3.02-3.02L12 2h-1v5.03l2 2v-3.2zM5.41 4L4 5.41 10.59 12 5 17.59 6.41 19 11 14.41V22h1l4.29-4.29 2.3 2.29L20 18.59 5.41 4zM13 18.17v-3.76l1.88 1.88L13 18.17z",
        "wifi_off": "M2.8 4.2L4.2 2.8 21.2 19.8 19.8 21.2z"
    })
    readonly property var wifiPaths: [
        "M12 20L9.352 16.486A4.4 4.4 0 0 1 14.648 16.486Z",
        "M6.343 12.493A9.4 9.4 0 0 1 17.657 12.493L15.49 15.368A5.8 5.8 0 0 0 8.51 15.368Z",
        "M3.334 8.5A14.4 14.4 0 0 1 20.666 8.5L18.499 11.375A10.8 10.8 0 0 0 5.501 11.375Z",
        "M0.324 4.507A19.4 19.4 0 0 1 23.676 4.507L21.508 7.382A15.8 15.8 0 0 0 2.492 7.382Z"
    ]
    readonly property string cellPath: "M3 20L21 3V20Z"
    readonly property string lockPath: "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z"

    // ---------- notification icon lookup ----------
    function iconFrom(s) {
        if (!s) return ""
        if (s.startsWith("/") || s.startsWith("file://") || s.startsWith("image://")) return s
        return Quickshell.iconPath(s, true)
    }
    function notifIconSource(n) {
        let r = iconFrom(n.appIcon)
        if (r) return r
        if (n.desktopEntry) {
            const de = DesktopEntries.byId(n.desktopEntry) || DesktopEntries.heuristicLookup(n.desktopEntry)
            if (de) { r = iconFrom(de.icon); if (r) return r }
        }
        const de2 = DesktopEntries.heuristicLookup(n.appName)
        if (de2) { r = iconFrom(de2.icon); if (r) return r }
        return iconFrom(n.appName.toLowerCase())
    }

    // ---------- services ----------
    SystemClock { id: clock; precision: SystemClock.Minutes }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    readonly property var nowDate: clock.date

    NotificationServer {
        id: nserver
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: notification => {
            notification.tracked = true
            root.addRecord(notification)
            toasts.push(notification)
        }
    }

    Toasts { id: toasts; shell: root }

    // ---------- notification records (saved to state.json, survive reboots) ----------
    readonly property var notifList: records
    function addRecord(n) {
        const uid = Date.now().toString(36) + "-" + n.id
        const r = { uid: uid, nid: n.id, appName: n.appName, appIcon: n.appIcon, desktopEntry: n.desktopEntry,
                    summary: n.summary, body: n.body, image: n.image, urgency: n.urgency, time: Date.now() }
        live[uid] = n
        records = [r].concat(records)
        n.closed.connect(() => root.removeRecord(uid))
        return r
    }
    function removeRecord(uid) {
        records = records.filter(r => r.uid !== uid)
        delete live[uid]
    }
    function dismissRecord(uid) {
        const n = live[uid]
        removeRecord(uid)
        if (n) n.dismiss()
    }
    function actionsFor(rec) {
        const out = []
        const n = live[rec.uid]
        const a = n ? n.actions : null
        if (a) for (let i = 0; i < a.length; i++) out.push(a[i])
        return out
    }
    function clearNotifications() {
        const arr = []
        const all = nserver.trackedNotifications.values
        for (let i = 0; i < all.length; i++) arr.push(all[i])
        records = []
        live = ({})
        for (const n of arr) n.dismiss()
    }
    // after a shell reload the server still tracks notifications: tie them back to their records
    function relinkLive() {
        const all = nserver.trackedNotifications.values
        for (let i = 0; i < all.length; i++) {
            const n = all[i]
            const rec = records.find(r => r.nid === n.id && !live[r.uid])
            if (rec) { live[rec.uid] = n; n.closed.connect(() => root.removeRecord(rec.uid)) }
            else if (!records.some(r => live[r.uid] === n)) addRecord(n)
        }
    }

    // ---------- persistent state: ~/.local/state/quickshell-pixel/state.json ----------
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell-pixel"
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", stateDir])
    FileView {
        id: stateFile
        path: root.stateDir + "/state.json"
        atomicWrites: true
        onLoaded: {
            try {
                const st = JSON.parse(text())
                root.dnd = !!st.dnd
                root.alarms = st.alarms || []
                root.timerTotal = st.timerTotal || 0
                root.timerEnd = (st.timerEnd || 0) > Date.now() ? st.timerEnd : 0
                const old = (st.records || []).filter(r => !root.records.some(x => x.uid === r.uid))
                root.records = root.records.concat(old)
                root.relinkLive()
            } catch (e) { console.warn("state.json:", e) }
            root.stateLoaded = true
        }
        onLoadFailed: root.stateLoaded = true
    }
    function saveState() { if (stateLoaded) saveTimer.restart() }
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: {
            const recs = root.records.slice(0, 200).map(r => Object.assign({}, r, {
                image: (r.image || "").startsWith("image://") ? "" : r.image,
                appIcon: (r.appIcon || "").startsWith("image://") ? "" : r.appIcon }))
            stateFile.setText(JSON.stringify({ version: 1, dnd: root.dnd, alarms: root.alarms,
                timerEnd: root.timerEnd, timerTotal: root.timerTotal, records: recs }))
        }
    }
    onDndChanged: saveState()
    onRecordsChanged: saveState()

    // ---------- alarms and timer ----------
    function pad2(n) { return (n < 10 ? "0" : "") + n }
    function addAlarm(time, label, daily, temp) {
        const a = alarms.slice()
        a.push({ id: Date.now().toString(36) + Math.floor(Math.random() * 1000), time: time, label: label || "",
                 enabled: true, daily: !!daily, lastFired: "", temp: !!temp })
        alarms = a
        saveState()
    }
    function updateAlarm(id, patch) { alarms = alarms.map(a => a.id === id ? Object.assign({}, a, patch) : a); saveState() }
    function removeAlarm(id) { alarms = alarms.filter(a => a.id !== id); saveState() }
    function nextAlarmText(tick) {
        const now = new Date()
        let best = ""
        let bestDt = 1e18
        for (const a of alarms) {
            if (!a.enabled) continue
            const p = a.time.split(":")
            const t = new Date(now)
            t.setHours(parseInt(p[0]), parseInt(p[1]), 0, 0)
            if (t <= now) t.setDate(t.getDate() + 1)
            if (t - now < bestDt) { bestDt = t - now; best = a.time }
        }
        return best
    }
    function startRing(label) {
        ringLabel = label
        ringing = true
        alarmProc.running = false
        alarmProc.running = true
    }
    function stopRing() { ringing = false; alarmProc.running = false }
    function snooze(min) {
        stopRing()
        const d = new Date(Date.now() + min * 60000)
        addAlarm(pad2(d.getHours()) + ":" + pad2(d.getMinutes()), "Snooze", false, true)
    }
    function startTimer(sec) { timerTotal = sec * 1000; timerEnd = Date.now() + timerTotal; saveState() }
    function cancelTimer() { timerEnd = 0; saveState() }

    Process {
        id: alarmProc
        command: ["sh", "-c", "for i in $(seq 90); do paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga || break; sleep 0.5; done"]
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            root.nowMs = Date.now()
            if (root.timerEnd > 0 && root.nowMs >= root.timerEnd) { root.timerEnd = 0; root.saveState(); root.startRing("Timer") }
            if (root.alarms.length === 0) return
            const d = new Date()
            const hm = Qt.formatDateTime(d, "HH:mm")
            const key = Qt.formatDateTime(d, "yyyyMMdd") + hm
            for (const a of root.alarms) {
                if (a.enabled && a.time === hm && a.lastFired !== key) {
                    root.startRing(a.label !== "" ? a.label : "Alarm")
                    root.alarms = root.alarms.filter(x => !(x.id === a.id && a.temp))
                        .map(x => x.id === a.id ? Object.assign({}, x, { lastFired: key, enabled: a.daily }) : x)
                    root.saveState()
                    break
                }
            }
        }
    }

    // ---------- weather (wttr.in), shown in the shade and on the lock screen ----------
    Process {
        id: weatherProc
        command: ["bash", "-c", "curl -s -m 8 \"wttr.in/${1// /+}?format=%t%7C%C&${2:-m}\"", "bash",
                  root.cv("weather.city", ""), root.cv("weather.units", "m")]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("|")
                if (p.length === 2 && p[0].length < 12) { root.weatherTemp = p[0].replace("+", ""); root.weatherDesc = p[1] }
            }
        }
    }
    Timer { interval: 1200000; running: true; repeat: true; triggeredOnStart: true; onTriggered: weatherProc.running = true }
    function refreshWeather() { weatherProc.running = true }

    // ---------- quick settings shade ----------
    property real shadeProgress: 0          // 0 closed .. 1 open, follows the finger while dragging
    property bool shadeOpen: false
    property bool shadeExpanded: false      // stage 2: all tiles, volume, media
    property bool shadeDragging: false
    property string shadeScreen: ""
    property real dragStartY: 0
    property real dragStartP: 0
    property real dragDist: 1
    property real dragTravel: 0
    property bool dragWasOpen: false
    Behavior on shadeProgress {
        enabled: !root.shadeDragging
        NumberAnimation {
            duration: root.shadeOpen ? root.cv("shade.animationMs", 450) : root.cv("shade.closeAnimationMs", 280)
            easing.type: Easing.BezierSpline
            // Material "emphasized decelerate" when opening, "emphasized accelerate" when closing
            easing.bezierCurve: root.shadeOpen ? [0.05, 0.7, 0.1, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1]
        }
    }
    function shadeTargetScreen() {
        const t = cv("shade.screen", "focused")
        if (t === "main") return mainScreenName
        if (t === "focused") return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : mainScreenName
        return t
    }
    function openShade(name) {
        if (!cv("shade.enabled", true)) return
        if (shadeOpen) { shadeExpanded = true; return }            // pulling down again expands
        shadeScreen = name && name !== "" ? name : shadeTargetScreen()
        shadeExpanded = cv("shade.startExpanded", false)
        shadeOpen = true
        shadeProgress = 1
    }
    function closeShade() { shadeOpen = false; shadeProgress = 0 }
    function toggleShade() { if (shadeOpen) closeShade(); else openShade("") }
    function dragBegin(screenName, y, screenH) {
        if (!cv("shade.enabled", true)) return
        if (!shadeOpen) shadeScreen = screenName
        dragStartY = y
        dragStartP = shadeProgress
        dragDist = Math.max(1, screenH * cv("shade.swipeDistanceFraction", 0.45))
        dragWasOpen = shadeOpen
        dragTravel = 0
        shadeDragging = true
    }
    function dragMove(y) {
        if (!shadeDragging) return
        dragTravel = Math.max(dragTravel, Math.abs(y - dragStartY))
        shadeProgress = Math.max(0, Math.min(1, dragStartP + (y - dragStartY) / dragDist))
    }
    function dragEnd() {
        if (!shadeDragging) return
        shadeDragging = false
        if (dragWasOpen && dragTravel < 6) { closeShade(); return }     // a tap closes
        const f = cv("shade.openFraction", 0.3)
        const open = dragWasOpen ? shadeProgress > 1 - f : shadeProgress > f
        if (open && !dragWasOpen) shadeExpanded = cv("shade.startExpanded", false)
        shadeOpen = open
        shadeProgress = open ? 1 : 0
    }

    // qs ipc call shade open|close|toggle
    IpcHandler {
        target: "shade"
        function open(): void { root.openShade("") }
        function close(): void { root.closeShade() }
        function toggle(): void { root.toggleShade() }
        function expand(): void { if (!root.shadeOpen) root.openShade(""); root.shadeExpanded = true }
        function collapse(): void { root.shadeExpanded = false }
    }

    Shade { id: shade; shell: root }
    Ringer { id: ringer; shell: root }
    Lock { id: lock; shell: root }

    // qs ipc call bar <function>
    IpcHandler {
        target: "bar"
        function toggleDnd(): void { root.dnd = !root.dnd }
        function clearNotifications(): void { root.clearNotifications() }
        function setAlarm(time: string): void {
            const m = /^(\d{1,2}):(\d{2})$/.exec(time)
            if (m) root.addAlarm(root.pad2(parseInt(m[1])) + ":" + m[2], "", false, false)
        }
        function clearAlarm(): void { root.alarms = []; root.saveState() }
        function stopAlarm(): void { root.stopRing() }
    }

    function startStartup() {
        if (startupActive) return
        fadeOut.stop()
        blackLevel = 1                 // instant, no fade-in
        startupActive = true
        startupPlayer.stop()
        startupPlayer.play()           // the file is already loaded, so it starts right away
        if (!brightProc.running) brightProc.running = true
    }
    function stopStartup() {
        if (!startupActive) return
        startupActive = false
        startupPlayer.stop()
        fadeOut.restart()
    }

    // preloaded player; its output is the video box on the main monitor
    MediaPlayer {
        id: startupPlayer
        source: root.startupVideo
        videoOutput: root.videoSink
        audioOutput: AudioOutput { volume: root.videoVolume }
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia && root.startupActive) endTimer.restart()
        onErrorOccurred: (error, errorString) => {
            console.warn("start.mp4:", errorString)
            root.stopStartup()
        }
    }
    Timer { id: endTimer; interval: 400; onTriggered: root.stopStartup() }

    IpcHandler {
        target: "startup"
        function play(): void { root.startStartup() }
        function stop(): void { root.stopStartup() }
    }

    // brightness 100% on every backlight and on DDC/CI monitors
    Process {
        id: brightProc
        command: ["bash", "-c", [
            "for d in $(brightnessctl -l -m -c backlight 2>/dev/null | cut -d, -f1); do brightnessctl -q -d \"$d\" set 100%; done",
            "if command -v ddcutil >/dev/null 2>&1; then",
            "  for n in $(ddcutil detect --brief 2>/dev/null | awk '/^Display [0-9]+/ {print $2}'); do",
            "    ddcutil --display \"$n\" setvcp 10 100 --noverify >/dev/null 2>&1 &",
            "  done",
            "  wait",
            "fi"
        ].join("\n")]
    }

    // fullscreen detection: names of monitors whose active workspace has a fullscreen window
    Process {
        id: fsProc
        property bool pending: false
        command: ["bash", "-c", [
            "ws=$(hyprctl -j workspaces 2>/dev/null)",
            "[ -z \"$ws\" ] && exit 0",
            "hyprctl -j monitors 2>/dev/null | jq -r --argjson ws \"$ws\" '.[] | .name as $n | .activeWorkspace.id as $id | select(any($ws[]; .id == $id and .hasfullscreen == true)) | $n'"
        ].join("\n")]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fsMonitors = text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                if (fsProc.pending) { fsProc.pending = false; fsProc.running = true }
            }
        }
    }
    Timer {
        id: fsDebounce
        interval: 80
        onTriggered: { if (fsProc.running) fsProc.pending = true; else fsProc.running = true }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: fsDebounce.restart() }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (n === "fullscreen" || n === "workspace" || n === "workspacev2" || n === "focusedmon"
                || n === "activewindow" || n === "openwindow" || n === "closewindow"
                || n === "movewindow" || n === "moveworkspace")
                fsDebounce.restart()
        }
    }

    // network: "<wifi signal|-1> <eth> <vpn> <wifi radio> <cell signal|-1> <hotspot>"
    Process {
        id: netProc
        command: ["bash", "-c", [
            "sig=$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | grep '^yes' | head -n1 | cut -d: -f2)",
            "eth=$(nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c '^ethernet:connected')",
            "vpn=$(nmcli -t -f TYPE con show --active 2>/dev/null | grep -cE '^(vpn|wireguard)$')",
            "radio=$(nmcli radio wifi 2>/dev/null)",
            "cell=$(mmcli -m any -K 2>/dev/null | awk -F': ' '/signal-quality.value/ {gsub(/ /,\"\",$2); print $2; exit}')",
            "ap=$(iw dev 2>/dev/null | grep -c 'type AP')",
            "conn=$(nmcli -t -f CONNECTIVITY general 2>/dev/null)",
            "echo \"${sig:--1} $eth $vpn ${radio:-enabled} ${cell:--1} $ap ${conn:-unknown}\""
        ].join("\n")]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ")
                if (p.length < 7) return
                root.wifiSignal = parseInt(p[0])
                root.ethernet = parseInt(p[1]) > 0
                root.vpn = parseInt(p[2]) > 0
                root.wifiRadio = p[3] === "enabled"
                root.cellSignal = parseInt(p[4])
                root.hotspot = parseInt(p[5]) > 0
                root.conn = p[6]
            }
        }
    }
    Process {
        id: ssidProc
        command: ["bash", "-c", "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes' | head -n1 | cut -d: -f2-"]
        stdout: StdioCollector { onStreamFinished: root.wifiSsid = text.trim() }
    }
    Timer {
        interval: root.cv("network.pollSeconds", 6) * 1000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: { netProc.running = true; ssidProc.running = true }
    }

    // privacy: "<mic capture streams, monitors ignored> <camera in use>"
    Process {
        id: privProc
        command: ["bash", "-c", [
            "mons=$(pactl -f json list sources 2>/dev/null | jq -c '[.[]|select(.monitor_of_sink!=null)|.index]' 2>/dev/null)",
            "mons=${mons:-[]}",
            "mic=$(pactl -f json list source-outputs 2>/dev/null | jq --argjson m \"$mons\" '[.[]|select((.source as $s|$m|index($s))==null)]|length' 2>/dev/null)",
            "cam=0",
            "for d in /dev/video*; do [ -e \"$d\" ] && fuser \"$d\" >/dev/null 2>&1 && cam=1; done",
            "echo \"${mic:-0} $cam\""
        ].join("\n")]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ")
                if (p.length < 2) return
                root.micActive = parseInt(p[0]) > 0
                root.camActive = parseInt(p[1]) > 0
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: privProc.running = true }

    // ---------- components ----------
    // icons/<file>.svg if it exists, otherwise vector shapes drawn by QML
    component Icon: Item {
        id: ic
        property string name: ""
        property int level: 4            // wifi / cell: 0..4
        property int size: root.iconSize
        property color color: root.fg
        property string badge: ""        // "" | "alert" (no internet) | "lock" (sign-in required)
        readonly property string fileName: badge !== "" ? name + (badge === "lock" ? "_login" : "_nointernet")
                                         : name === "wifi" ? "wifi_" + level
                                         : name === "cell" ? "cell_" + level : name
        implicitWidth: size
        implicitHeight: size

        Image {
            id: img
            anchors.fill: parent
            source: Qt.resolvedUrl("icons/" + ic.fileName + ".svg")
            sourceSize: Qt.size(ic.size * 2, ic.size * 2)
            visible: status === Image.Ready
        }

        Item {
            id: vec
            visible: img.status !== Image.Ready
            width: 24; height: 24
            scale: ic.size / 24
            transformOrigin: Item.TopLeft
            layer.enabled: true
            layer.samples: 4
            layer.textureSize: Qt.size(48, 48)

            Shape {
                width: 24; height: 24
                visible: ic.name !== "wifi" && ic.name !== "cell"
                ShapePath {
                    fillColor: ic.color
                    strokeColor: "transparent"
                    fillRule: ShapePath.WindingFill
                    PathSvg { path: root.iconPaths[ic.name] || "" }
                }
            }
            Repeater {
                model: (ic.name === "wifi" || ic.name === "wifi_off") ? 4 : 0
                delegate: Shape {
                    required property int index
                    width: 24; height: 24
                    opacity: (ic.name === "wifi" && index < ic.level) ? 1 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    ShapePath {
                        fillColor: ic.color
                        strokeColor: "transparent"
                        PathSvg { path: root.wifiPaths[index] }
                    }
                }
            }
            Shape {
                visible: ic.name === "cell"
                width: 24; height: 24
                opacity: 0.3
                ShapePath {
                    fillColor: ic.color
                    strokeColor: "transparent"
                    PathSvg { path: root.cellPath }
                }
            }
            // status badge in the lower-right corner
            Rectangle {
                visible: ic.badge !== ""
                x: 12; y: 12; width: 12; height: 12; radius: 6
                color: root.warn
                Rectangle { visible: ic.badge === "alert"; x: 5.1; y: 2.4; width: 1.8; height: 4.6; radius: 0.9; color: "#1C1B1F" }
                Rectangle { visible: ic.badge === "alert"; x: 5.1; y: 8.0; width: 1.8; height: 1.8; radius: 0.9; color: "#1C1B1F" }
                Item {
                    visible: ic.badge === "lock"
                    x: 2.5; y: 2.3; scale: 0.29; transformOrigin: Item.TopLeft
                    Shape {
                        width: 24; height: 24
                        ShapePath { fillColor: "#1C1B1F"; strokeColor: "transparent"; PathSvg { path: root.lockPath } }
                    }
                }
            }
            Item {
                visible: ic.name === "cell"
                width: 3 + 18 * ic.level / 4
                height: 24
                clip: true
                Behavior on width { NumberAnimation { duration: 250 } }
                Shape {
                    width: 24; height: 24
                    ShapePath {
                        fillColor: ic.color
                        strokeColor: "transparent"
                        PathSvg { path: root.cellPath }
                    }
                }
            }
        }
    }

    // wrapper that animates an item in/out of a row (width collapse + fade + pop)
    component Slot: Item {
        id: slot
        property bool active: true
        property int gap: 7
        default property alias content: holder.data
        implicitWidth: active ? holder.childrenRect.width + gap : 0
        implicitHeight: holder.childrenRect.height
        opacity: active ? 1 : 0
        scale: active ? 1 : 0.5
        visible: implicitWidth > 0.5 || opacity > 0.01
        Behavior on implicitWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        Item { id: holder }
    }

    // fully QML-drawn Pixel battery: a plain pill
    component BatteryPill: Item {
        id: bp
        property real level: 1
        property bool charging: false
        property bool powerSaver: false
        implicitWidth: Math.round(22 * root.ui)
        implicitHeight: Math.round(11 * root.ui)
        readonly property color tint: (level <= 0.15 && !charging) ? root.warn
                                    : powerSaver ? root.saver : root.fg

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.track
            clip: true
            Rectangle {
                width: Math.max(parent.height, parent.width * bp.level)
                height: parent.height
                radius: height / 2
                color: bp.tint
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }
            }
        }
        Canvas {
            id: bolt
            anchors.centerIn: parent
            width: 6 * root.ui; height: 8.25 * root.ui
            opacity: bp.charging ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            onVisibleChanged: requestPaint()
            onPaint: {
                const c = getContext("2d")
                c.reset()
                c.scale(0.75 * root.ui, 0.75 * root.ui)
                c.fillStyle = "#1C1B1F"
                c.beginPath()
                c.moveTo(5, 0); c.lineTo(0, 6); c.lineTo(3.4, 6)
                c.lineTo(2.6, 11); c.lineTo(8, 4.6); c.lineTo(4.6, 4.6)
                c.closePath()
                c.fill()
            }
        }
    }

    // ---------- startup: black screen on every monitor, video on the main one ----------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: blackout
            required property var modelData
            screen: modelData
            readonly property bool isMain: modelData.name === root.mainScreenName

            visible: root.startupActive || root.blackLevel > 0
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "startup-blackout"
            // takes pointer input only while the animation is running
            mask: Region { item: root.startupActive ? blackRect : null }

            Rectangle {
                id: blackRect
                anchors.fill: parent
                color: "black"
                opacity: root.blackLevel

                // click anywhere to skip
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.BlankCursor
                    onClicked: root.stopStartup()
                }

                // fullscreen video: as large as possible, never cropped; black bars if the aspect differs
                VideoOutput {
                    id: vo
                    anchors.fill: parent
                    visible: blackout.isMain
                    fillMode: VideoOutput.PreserveAspectFit
                }
                Binding { target: root; property: "videoSink"; value: vo; when: blackout.isMain }
            }
        }
    }

    // ---------- the bar (one per monitor) ----------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            // fullscreen handling
            readonly property bool hideForFs: root.cv("bar.hideOnFullscreen", true) && root.fsMonitors.indexOf(modelData.name) >= 0
            property bool revealed: false
            readonly property bool shown: !root.startupActive && (!hideForFs || revealed)

            anchors { top: true; left: true; right: true }
            implicitHeight: root.barHeight
            exclusiveZone: hideForFs ? 0 : root.barHeight
            color: "transparent"
            // fullscreen windows cover the Top layer, so go to Overlay while hidden-for-fullscreen
            WlrLayershell.layer: hideForFs ? WlrLayer.Overlay : WlrLayer.Top
            WlrLayershell.namespace: "pixel-statusbar"
            // only the visible part (or the thin hover strip) takes pointer input
            mask: Region { item: hit }

            onHideForFsChanged: if (!hideForFs) revealed = false

            readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property var source: Pipewire.defaultAudioSource
            readonly property var bat: UPower.displayDevice
            readonly property var btAdapter: Bluetooth.defaultAdapter

            readonly property bool playing: !!(player && player.isPlaying)
            readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
            readonly property bool micMuted: source && source.audio ? source.audio.muted : false
            readonly property bool btOn: btAdapter ? btAdapter.enabled : false
            readonly property bool allRadiosOff: root.cv("icons.airplaneWhenAllOff", true) && !root.wifiRadio && !btOn
            readonly property string netBadge: (root.wifiSignal < 0 && !root.ethernet) ? ""
                : root.conn === "portal" ? "lock"
                : (root.conn === "limited" || root.conn === "none") ? "alert" : ""
            readonly property bool btConnected: btOn && btAdapter.devices.values.some(d => d.connected)
            readonly property bool powerSaver: PowerProfiles.profile === PowerProfile.PowerSaver
            readonly property int wifiLevel: root.wifiSignal < 0 ? 0
                : root.wifiSignal > 75 ? 4 : root.wifiSignal > 50 ? 3 : root.wifiSignal > 25 ? 2 : 1
            readonly property int cellLevel: root.cellSignal > 80 ? 4 : root.cellSignal > 60 ? 3
                : root.cellSignal > 40 ? 2 : root.cellSignal > 20 ? 1 : 0

            // one icon per app, newest first
            readonly property var notifApps: {
                const seen = {}
                const out = []
                const all = root.records
                for (let i = 0; i < all.length; i++) {
                    const k = all[i].appName
                    if (!seen[k]) { seen[k] = true; out.push(all[i]) }
                }
                return out
            }

            Timer { id: hideTimer; interval: 450; onTriggered: bar.revealed = false }

            // hover / input area (also defines the input mask)
            Item {
                id: hit
                width: parent.width
                height: bar.shown ? root.barHeight : root.hoverStrip
                MouseArea {
                    id: swipe
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    property real pressY: 0
                    onEntered: { hideTimer.stop(); if (bar.hideForFs) bar.revealed = true }
                    onExited: if (bar.hideForFs) hideTimer.restart()
                    onPressed: mouse => { pressY = mouse.y }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        if (!root.shadeDragging) {
                            if (mouse.y - pressY > root.cv("shade.swipeThresholdPx", 16))
                                root.dragBegin(bar.modelData.name, mouse.y, bar.modelData.height)
                        } else {
                            root.dragMove(mouse.y)
                        }
                    }
                    onReleased: root.dragEnd()
                }
            }

            // everything visible, slides in/out
            Item {
                id: content
                width: parent.width
                height: root.barHeight
                y: bar.shown ? 0 : -root.barHeight
                opacity: bar.shown ? 1 : 0
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220 } }

                // soft dark scrim like the Android status bar
                Rectangle {
                    anchors.fill: parent
                    visible: root.cv("bar.scrim", true)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, root.cv("bar.scrimOpacity", 0.45)) }
                        GradientStop { position: 1.0; color: "#00000000" }
                    }
                }

                // ===== LEFT: clock + notification icons =====
                RowLayout {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        id: clockText
                        text: Qt.formatDateTime(clock.date, root.use24h ? "HH:mm" : "h:mm")
                        color: root.fg
                        font.family: root.cv("bar.clockFont", root.fontFamily)
                        font.pixelSize: Math.round(14 * root.ui)
                        font.weight: root.cv("bar.clockBold", true) ? Font.Bold : Font.Medium
                        font.letterSpacing: 0.4
                        transform: Translate { id: clockShift }
                        onTextChanged: clockAnim.restart()
                        ParallelAnimation {
                            id: clockAnim
                            NumberAnimation { target: clockShift; property: "y"; from: 6; to: 0; duration: 320; easing.type: Easing.OutCubic }
                            NumberAnimation { target: clockText; property: "opacity"; from: 0.2; to: 1; duration: 320 }
                        }
                    }

                    RowLayout {
                        spacing: 6

                        Repeater {
                            model: ScriptModel { values: bar.notifApps.slice(0, root.maxNotifIcons) }
                            delegate: Item {
                                id: nItem
                                required property var modelData
                                readonly property string src: root.notifIconSource(modelData)
                                property real appear: 0
                                implicitWidth: root.notifIconSize * Math.min(appear, 1)
                                implicitHeight: root.notifIconSize
                                scale: appear
                                opacity: Math.min(appear, 1)
                                Component.onCompleted: appear = 1
                                Behavior on appear { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

                                Image {
                                    id: appImg
                                    width: root.notifIconSize
                                    height: root.notifIconSize
                                    source: nItem.src
                                    sourceSize: Qt.size(root.notifIconSize * 2, root.notifIconSize * 2)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: !root.monoNotifIcons && status === Image.Ready
                                    layer.enabled: root.monoNotifIcons
                                }
                                MultiEffect {
                                    width: root.notifIconSize
                                    height: root.notifIconSize
                                    source: appImg
                                    visible: root.monoNotifIcons && appImg.status === Image.Ready
                                    brightness: 1.0
                                    saturation: -1.0
                                }
                                Icon {
                                    visible: appImg.status !== Image.Ready
                                    name: "notification"
                                    size: root.notifIconSize
                                }
                            }
                        }

                        Slot {
                            active: bar.notifApps.length > root.maxNotifIcons
                            gap: 0
                            Text {
                                text: "+" + (bar.notifApps.length - root.maxNotifIcons)
                                color: root.fg
                                font.family: root.fontFamily
                                font.pixelSize: Math.round(11 * root.ui)
                                font.weight: Font.Medium
                            }
                        }
                        Slot {
                            active: bar.playing
                            gap: 0
                            Icon {
                                name: "media"
                                size: Math.round(13 * root.ui)
                                color: root.fgDim
                                SequentialAnimation on opacity {
                                    running: bar.playing
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.4; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }

                // ===== RIGHT: status icons, battery, privacy chip =====
                RowLayout {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Slot { active: root.alarmCount > 0;    Icon { name: "alarm" } }
                    Slot { active: root.dnd;               Icon { name: "dnd" } }
                    Slot { active: bar.micMuted;           Icon { name: "mic_off" } }
                    Slot { active: bar.muted;              Icon { name: "volume_off" } }
                    Slot { active: root.hotspot;           Icon { name: "hotspot" } }
                    Slot {
                        active: !bar.allRadiosOff && (bar.btOn || (!!bar.btAdapter && root.cv("icons.showBluetoothOff", true)))
                        Icon { name: bar.btConnected ? "bluetooth_connected" : (bar.btOn ? "bluetooth" : "bluetooth_off"); color: bar.btOn ? root.fg : root.fgDim }
                    }
                    Slot { active: root.vpn;               Icon { name: "vpn" } }
                    Slot { active: bar.allRadiosOff;       Icon { name: "airplane" } }
                    Slot { active: root.ethernet;          Icon { name: "ethernet"; badge: bar.netBadge } }
                    Slot {
                        active: !bar.allRadiosOff && !root.ethernet && (root.wifiRadio
                                ? (root.wifiSignal >= 0 || root.cv("icons.showWifiDisconnected", true))
                                : root.cv("icons.showWifiOff", true))
                        Icon {
                            name: root.wifiRadio ? "wifi" : "wifi_off"
                            level: bar.netBadge !== "" ? 4 : bar.wifiLevel      // no bars with a badge: just the wifi icon + !
                            badge: root.wifiRadio ? bar.netBadge : ""
                            color: (root.wifiRadio && bar.wifiLevel > 0) ? root.fg : root.fgDim
                        }
                    }
                    Slot {
                        active: root.wifiRadio && root.cellSignal >= 0
                        Icon { name: "cell"; level: bar.cellLevel }
                    }
                    Slot {
                        active: !!(bar.bat && bar.bat.isLaptopBattery)
                        BatteryPill {
                            level: bar.bat ? bar.bat.percentage : 1
                            charging: !!(bar.bat && bar.bat.state === UPowerDeviceState.Charging)
                            powerSaver: bar.powerSaver
                        }
                    }
                    // mic / camera privacy indicator
                    Slot {
                        active: root.micActive || root.camActive
                        gap: 0
                        Rectangle {
                            implicitHeight: Math.round(16 * root.ui)
                            implicitWidth: chipRow.implicitWidth + 12
                            radius: height / 2
                            color: root.privacyGreen
                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 4
                                Icon { visible: root.micActive; name: "mic";    size: Math.round(11 * root.ui); color: root.privacyInk }
                                Icon { visible: root.camActive; name: "camera"; size: Math.round(11 * root.ui); color: root.privacyInk }
                            }
                        }
                    }
                }
            }
        }
    }
}
