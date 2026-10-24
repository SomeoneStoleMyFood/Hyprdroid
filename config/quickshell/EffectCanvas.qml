import QtQuick

// Particle simulation + drawing for one screen. Depth (z: 0 far .. 1 near) drives size, speed, softness and brightness.
Canvas {
    id: cv
    required property var eff
    property var ps: []
    property real t: 0
    renderTarget: Canvas.FramebufferObject
    renderStrategy: Canvas.Cooperative

    function rnd(a, b) { return a + Math.random() * (b - a) }
    function pal(kind) {
        const def = {
            snow: ["#FFFFFF"],
            sakura: ["#FFB7CE", "#FFC8D8", "#FFD9E4", "#F7A1BD"],
            leaves: ["#D9822B", "#C0392B", "#E0A526", "#8B9A2B", "#A5522A", "#B8651B"],
            rain: ["#BFD3EA"],
            confetti: ["#EA4335", "#FBBC05", "#34A853", "#4285F4", "#FF6DAF", "#8E6CEF"],
            fireflies: ["#F6E27A", "#C8F28A"]
        }
        return eff.colors && eff.colors.length > 0 ? eff.colors : def[kind]
    }
    function spawn(initial) {
        const k = eff.kind
        const z = Math.random()
        const sz = eff.size
        const sp = eff.speed
        const p = { z: z, x: rnd(-50, width + 50), y: initial ? rnd(-50, height) : rnd(-80, -10), rot: rnd(0, 6.283), flip: rnd(0, 6.283),
                    phase: rnd(0, 6.283), freq: rnd(0.6, 1.8), amp: rnd(10, 40), col: 0, a: 1, s: 8, vy: 60, vr: rnd(-1.5, 1.5), vf: rnd(1.5, 4), vx: 0 }
        const cols = pal(k)
        p.col = cols[Math.floor(Math.random() * cols.length)]
        if (k === "snow") { p.s = (1.3 + 4.2 * z * z) * sz; p.vy = (28 + 85 * z) * sp; p.a = 0.35 + 0.6 * z; p.amp = rnd(8, 28) }
        else if (k === "sakura") { p.s = rnd(7, 11) * (0.7 + 0.6 * z) * sz; p.vy = (32 + 38 * z) * sp; p.a = 0.75 + 0.25 * z; p.amp = rnd(25, 70) }
        else if (k === "leaves") { p.s = rnd(9, 15) * (0.7 + 0.6 * z) * sz; p.vy = (50 + 55 * z) * sp; p.a = 0.85 + 0.15 * z; p.amp = rnd(30, 90); p.vr = rnd(-1.2, 1.2) }
        else if (k === "rain") { p.s = (14 + 26 * z) * sz; p.vy = (650 + 700 * z) * sp; p.a = 0.18 + 0.4 * z; p.amp = 0 }
        else if (k === "confetti") { p.s = rnd(4, 7) * (0.8 + 0.5 * z) * sz; p.vy = (90 + 110 * z) * sp; p.a = 0.95; p.amp = rnd(20, 55); p.vr = rnd(-4, 4) }
        else if (k === "fireflies") { p.s = rnd(1.6, 3) * sz; p.vy = 0; p.a = 1; p.y = rnd(0, height); p.vx = rnd(-12, 12) * sp; p.vf = rnd(0.5, 1.6); p.amp = rnd(8, 20) }
        return p
    }
    property real builtW: 0
    property real builtH: 0
    function rebuild() {
        if (width <= 0 || height <= 0) return          // not laid out yet: onWidthChanged/onHeightChanged will call us again
        builtW = width; builtH = height
        const out = []
        for (let i = 0; i < eff.count; i++) out.push(spawn(true))
        ps = out
    }
    Connections {
        target: cv.eff
        function onKindChanged() { cv.rebuild() }
        function onCountChanged() { cv.rebuild() }
        function onSpeedChanged() { cv.rebuild() }
        function onSizeChanged() { cv.rebuild() }
        function onColorsChanged() { cv.rebuild() }
        function onActiveChanged() { if (cv.eff.active) cv.rebuild() }
    }
    onWidthChanged: if (width > 0 && (ps.length === 0 || Math.abs(width - builtW) > 1)) rebuild()
    onHeightChanged: if (height > 0 && (ps.length === 0 || Math.abs(height - builtH) > 1)) rebuild()

    function step(dt) {
        if (width <= 0 || ps.length === 0) return
        dt = Math.min(dt, 0.05)
        t += dt
        const k = eff.kind
        const turb = eff.turbulence
        // slowly changing gusts shared by every particle
        const gust = eff.wind + turb * (Math.sin(t * 0.37) * 22 + Math.sin(t * 1.1 + 2) * 10)
        for (let i = 0; i < ps.length; i++) {
            const p = ps[i]
            if (k === "fireflies") {
                p.phase += dt * 0.6
                p.x += (p.vx + Math.sin(t * p.vf + p.phase) * p.amp) * dt
                p.y += Math.cos(t * p.vf * 0.7 + p.phase * 1.3) * p.amp * 0.7 * dt
                if (p.x < -20) p.x = width + 20
                if (p.x > width + 20) p.x = -20
                if (p.y < -20) p.y = height + 20
                if (p.y > height + 20) p.y = -20
                continue
            }
            const depthWind = 0.35 + 0.65 * p.z
            const sway = k === "rain" ? 0 : Math.sin(t * p.freq + p.phase) * p.amp * turb
            p.x += (gust * depthWind * (k === "rain" ? 3 : 1) + sway) * dt
            p.y += p.vy * dt * (k === "sakura" || k === "leaves" || k === "confetti" ? (0.8 + 0.35 * Math.sin(t * p.freq * 1.7 + p.phase)) : 1)
            p.rot += p.vr * dt
            p.flip += p.vf * dt
            if (p.y > height + 40 || p.x > width + 120 || p.x < -120) {
                const n = spawn(false)
                if (p.x > width + 120 || p.x < -120) { n.x = gust >= 0 ? rnd(-100, width * 0.4) : rnd(width * 0.6, width + 100); n.y = rnd(-40, height) }
                ps[i] = n
            }
        }
    }

    function rgba(hex, a) {
        const c = Qt.color(hex)
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a.toFixed(3) + ")"
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        const k = eff.kind
        const op = eff.opacity
        for (let i = 0; i < ps.length; i++) {
            const p = ps[i]
            const a = p.a * op
            if (k === "snow") {
                const soft = 1.25 + (1 - p.z) * 0.9                 // far flakes are blurrier
                const r = p.s * soft
                const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r)
                g.addColorStop(0, rgba(p.col, a))
                g.addColorStop(0.45, rgba(p.col, a * 0.75))
                g.addColorStop(1, rgba(p.col, 0))
                ctx.fillStyle = g
                ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, 6.2832); ctx.fill()
            } else if (k === "rain") {
                const slant = (eff.wind * 3 + 0) / Math.max(1, p.vy)
                ctx.strokeStyle = rgba(p.col, a)
                ctx.lineWidth = 0.7 + p.z * 0.9
                ctx.lineCap = "round"
                ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - slant * p.s, p.y - p.s); ctx.stroke()
            } else if (k === "fireflies") {
                const b = 0.5 + 0.5 * Math.sin(t * p.vf * 2.2 + p.phase * 3)
                const al = Math.pow(b, 2.2) * op
                const r = p.s * 7
                const g = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, r)
                g.addColorStop(0, rgba(p.col, al))
                g.addColorStop(0.25, rgba(p.col, al * 0.45))
                g.addColorStop(1, rgba(p.col, 0))
                ctx.fillStyle = g
                ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, 6.2832); ctx.fill()
                ctx.fillStyle = rgba("#FFFFFF", al)
                ctx.beginPath(); ctx.arc(p.x, p.y, p.s * 0.7, 0, 6.2832); ctx.fill()
            } else {
                // petals / leaves / confetti tumble in 3D: squash one axis with cos(flip)
                const fl = Math.cos(p.flip)
                const sy = 0.18 + 0.82 * Math.abs(fl)
                const shade = 0.72 + 0.28 * fl
                ctx.save()
                ctx.translate(p.x, p.y)
                ctx.rotate(p.rot)
                ctx.scale(k === "confetti" ? 1 : 0.7, sy)
                const s = p.s
                if (k === "sakura") {
                    const g = ctx.createLinearGradient(0, s, 0, -s)
                    g.addColorStop(0, rgba("#F08FB0", a * shade))
                    g.addColorStop(0.6, rgba(p.col, a * shade))
                    g.addColorStop(1, rgba("#FFFFFF", a * shade * 0.9))
                    ctx.fillStyle = g
                    ctx.beginPath()
                    ctx.moveTo(0, -s * 0.75)
                    ctx.bezierCurveTo(s * 0.25, -s * 1.1, s * 0.95, -s * 0.6, s * 0.7, s * 0.1)
                    ctx.bezierCurveTo(s * 0.5, s * 0.7, s * 0.1, s * 0.95, 0, s)
                    ctx.bezierCurveTo(-s * 0.1, s * 0.95, -s * 0.5, s * 0.7, -s * 0.7, s * 0.1)
                    ctx.bezierCurveTo(-s * 0.95, -s * 0.6, -s * 0.25, -s * 1.1, 0, -s * 0.75)
                    ctx.fill()
                } else if (k === "leaves") {
                    ctx.fillStyle = rgba(p.col, a * shade)
                    ctx.beginPath()
                    ctx.moveTo(0, -s)
                    ctx.bezierCurveTo(s * 0.95, -s * 0.5, s * 0.95, s * 0.5, 0, s)
                    ctx.bezierCurveTo(-s * 0.95, s * 0.5, -s * 0.95, -s * 0.5, 0, -s)
                    ctx.fill()
                    ctx.strokeStyle = "rgba(60,30,10," + (0.45 * a * shade).toFixed(3) + ")"
                    ctx.lineWidth = 1
                    ctx.beginPath(); ctx.moveTo(0, -s); ctx.lineTo(0, s * 1.2); ctx.stroke()
                } else {
                    ctx.fillStyle = rgba(p.col, a * shade)
                    ctx.fillRect(-p.s, -p.s * 0.5, p.s * 2, p.s)
                }
                ctx.restore()
            }
        }
    }
}
