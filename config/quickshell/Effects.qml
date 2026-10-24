import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Falling-things effects (snow, sakura, leaves, rain, confetti, fireflies). Clicks pass through.
//   qs ipc call effects start snow            qs ipc call effects startn sakura 150
//   qs ipc call effects stop | toggle snow | list | status
//   qs ipc call effects set speed 1.5         (count speed wind turbulence size opacity layer screens)
// Defaults come from config.json -> effects (global keys, or per effect: effects.snow.speed ...).
Scope {
    id: fx
    required property var shell
    property string kind: ""
    property bool active: false
    property int count: 80
    property real speed: 1
    property real wind: 0                 // px/s, negative = blows to the left
    property real turbulence: 1           // 0 = straight fall, 1 = natural, 2 = stormy
    property real size: 1
    property real opacity: 1
    property string layerName: "overlay"  // overlay = above every window | top = above windows | bottom = under windows | background
    property string screens: "all"        // all | main | comma separated output names
    property var colors: []               // optional "#rrggbb" list, effects.<kind>.colors
    readonly property var kinds: ["snow", "sakura", "leaves", "rain", "confetti", "fireflies"]
    readonly property var kindDefaults: ({
        snow:      { count: 120, wind: 8 },
        sakura:    { count: 60,  wind: 25 },
        leaves:    { count: 45,  wind: 30 },
        rain:      { count: 220, wind: 40 },
        confetti:  { count: 90,  wind: 0 },
        fireflies: { count: 40,  wind: 0 }
    })

    function kv(k, key, def) {
        const v = shell.cv("effects." + k + "." + key, undefined)
        return v !== undefined ? v : shell.cv("effects." + key, def)
    }
    function start(k, n) {
        if (kinds.indexOf(k) < 0) return
        const d = kindDefaults[k]
        speed = kv(k, "speed", 1)
        wind = kv(k, "wind", d.wind)
        turbulence = kv(k, "turbulence", 1)
        size = kv(k, "size", 1)
        opacity = kv(k, "opacity", 1)
        layerName = kv(k, "layer", "overlay")
        screens = kv(k, "screens", "all")
        colors = kv(k, "colors", [])
        count = n > 0 ? n : kv(k, "count", d.count)
        kind = k
        active = true
    }
    function stop() { active = false }
    function setOpt(key, value) {
        const num = parseFloat(value)
        if (key === "count") count = Math.max(1, Math.round(num))
        else if (key === "speed") speed = Math.max(0.05, num)
        else if (key === "wind") wind = num
        else if (key === "turbulence") turbulence = Math.max(0, num)
        else if (key === "size") size = Math.max(0.1, num)
        else if (key === "opacity") opacity = Math.max(0, Math.min(1, num))
        else if (key === "layer") layerName = value
        else if (key === "screens") screens = value
        else if (key === "colors") colors = value.split(",").map(c => c.trim()).filter(c => c !== "")
    }
    function onScreen(name) {
        if (screens === "all") return true
        if (screens === "main") return name === shell.mainScreenName
        return screens.split(",").map(s => s.trim()).indexOf(name) >= 0
    }
    function layerOf(n) {
        return n === "top" ? WlrLayer.Top : n === "bottom" ? WlrLayer.Bottom : n === "background" ? WlrLayer.Background : WlrLayer.Overlay
    }

    IpcHandler {
        target: "effects"
        function start(kind: string): void { fx.start(kind, 0) }
        function startn(kind: string, count: int): void { fx.start(kind, count) }
        function stop(): void { fx.stop() }
        function toggle(kind: string): void { if (fx.active && fx.kind === kind) fx.stop(); else fx.start(kind, 0) }
        function set(key: string, value: string): void { fx.setOpt(key, value) }
        function list(): string { return fx.kinds.join(" ") }
        function status(): string {
            return JSON.stringify({ active: fx.active, kind: fx.kind, count: fx.count, speed: fx.speed, wind: fx.wind, turbulence: fx.turbulence,
                                    size: fx.size, opacity: fx.opacity, layer: fx.layerName, screens: fx.screens, colors: fx.colors })
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: fx.onScreen(modelData.name) && (fx.active || veil.opacity > 0.01)
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}                    // no input: clicks go through
            WlrLayershell.layer: fx.layerOf(fx.layerName)
            WlrLayershell.namespace: "pixel-effects"

            Item {
                id: veil
                anchors.fill: parent
                opacity: fx.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InOutSine } }

                EffectCanvas {
                    id: canvas
                    anchors.fill: parent
                    eff: fx
                }
                FrameAnimation {
                    running: win.visible
                    onTriggered: { canvas.step(frameTime); canvas.requestPaint() }
                }
            }
        }
    }
}
