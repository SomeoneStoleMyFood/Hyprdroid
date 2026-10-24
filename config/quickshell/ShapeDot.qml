import QtQuick
import QtQuick.Shapes

// Material 3 Expressive style shapes (cookie, clover, flower, burst, pill, soft square, diamond, pentagon, heart, circle, oval)
Item {
    id: sd
    property string kind: "cookie"
    property color color: "white"
    property real size: 24
    width: size
    height: size

    readonly property var kinds: ["cookie", "clover", "flower", "burst", "pill", "softsquare", "diamond", "pentagon", "heart", "oval", "circle"]

    // polar radius (0..1) for angle t
    function radius(k, t) {
        const sup = (p, aw, ah, a) => Math.pow(Math.pow(Math.abs(Math.cos(a) / aw), p) + Math.pow(Math.abs(Math.sin(a) / ah), p), -1 / p)
        switch (k) {
        case "cookie":     return (1 + 0.065 * Math.cos(9 * t)) / 1.065
        case "clover":     return (1 + 0.25 * Math.cos(4 * t)) / 1.25
        case "flower":     return (1 + 0.16 * Math.cos(6 * t)) / 1.16
        case "burst":      return 1 - 0.17 * Math.pow(Math.abs(Math.sin(6 * t)), 0.6)
        case "pill":       return Math.min(1, sup(4, 1, 0.62, t))
        case "softsquare": return Math.min(1, sup(4, 0.9, 0.9, t)) / 1.0
        case "diamond":    return Math.min(1, sup(3, 0.95, 0.95, t - Math.PI / 4))
        case "oval":       return sup(2, 1, 0.72, t)
        case "pentagon": {
            const seg = 2 * Math.PI / 5
            const a = ((t + Math.PI / 2) % seg + seg) % seg - seg / 2
            return 0.62 * (Math.cos(Math.PI / 5) / Math.cos(a)) + 0.38 * Math.cos(Math.PI / 5)
        }
        default:           return 1
        }
    }
    function build(k, n) {
        const out = []
        const c = n / 2
        if (k === "heart") {
            for (let i = 0; i < 120; i++) {
                const t = i / 120 * 2 * Math.PI
                const x = 16 * Math.pow(Math.sin(t), 3)
                const y = -(13 * Math.cos(t) - 5 * Math.cos(2 * t) - 2 * Math.cos(3 * t) - Math.cos(4 * t))
                out.push(Qt.point(c + x / 34 * n * 0.96, c + (y + 2.5) / 34 * n * 0.96))
            }
            return out
        }
        const R = c * 0.97
        for (let i = 0; i < 140; i++) {
            const t = i / 140 * 2 * Math.PI
            const r = radius(k, t) * R
            out.push(Qt.point(c + Math.cos(t) * r, c + Math.sin(t) * r))
        }
        return out
    }
    readonly property var pts: build(kind, size)

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        ShapePath {
            fillColor: sd.color
            strokeColor: "transparent"
            strokeWidth: 0
            PathPolyline { path: sd.pts }
        }
    }
}
