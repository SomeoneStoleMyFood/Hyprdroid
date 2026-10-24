import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Desktop stickers: pictures that sit on the wallpaper (below all windows).
//   qs ipc call stickers add /path/img.png | addsize /path 300 | addscreen /path 300 DP-1     qs ipc call stickers pick
//   qs ipc call stickers remove <id>     qs ipc call stickers clear     qs ipc call stickers list
// Mouse (on the bare desktop): drag = move, wheel = resize, Shift+wheel = rotate, right click = delete.
Scope {
    id: st
    required property var shell
    property var items: []            // {id, path, screen, x, y (0..1 of the screen), size (px), rot (deg)}
    property bool loaded: false
    property int selectedId: -1       // sticker currently opened in the editor
    property var known: []            // files from the watched folder that were already turned into stickers
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell-pixel"

    function nextId() {
        let m = 0
        for (let i = 0; i < items.length; i++) m = Math.max(m, items[i].id)
        return m + 1
    }
    function addAt(path, fx, fy, screen) {
        const id = add(path, 0, screen)
        patch(id, { x: fx, y: fy })
        return id
    }
    function add(path, size, screen) {
        path = path.replace(/^~/, Quickshell.env("HOME")).replace(/^file:\/\//, "")
        const sc = screen && screen !== "" ? screen : shell.mainScreenName
        const k = items.length
        const n = { id: nextId(), path: path, screen: sc, x: 0.3 + 0.05 * (k % 6), y: 0.3 + 0.05 * (k % 6), size: size > 0 ? size : 220, rot: 0 }
        items = items.concat([n])
        save()
        return n.id
    }
    function byId(id) {
        for (let i = 0; i < items.length; i++) if (items[i].id === id) return items[i]
        return null
    }
    function idsFor(screen) {
        const out = []
        for (let i = 0; i < items.length; i++) if (items[i].screen === screen) out.push(items[i].id)
        return out
    }
    function remove(id) { items = items.filter(i => i.id === id ? false : true); save() }
    function patch(id, p) {
        items = items.map(i => i.id === id ? Object.assign({}, i, p) : i)
        saveTimer.restart()
    }
    function save() { saveTimer.restart() }
    Timer { id: saveTimer; interval: 400; onTriggered: if (st.loaded) file.setText(JSON.stringify({ items: st.items, known: st.known }, null, 1)) }

    FileView {
        id: file
        path: st.stateDir + "/stickers.json"
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try { const j = JSON.parse(text()); st.items = j.items || []; st.known = j.known || [] } catch (e) { console.warn("stickers.json:", e) }
            st.loaded = true
        }
        onLoadFailed: st.loaded = true
    }

    Process {
        id: picker
        command: ["bash", "-c", 'f=$(zenity --file-selection --title="Sticker" --file-filter="Images | *.png *.jpg *.jpeg *.webp *.gif *.svg" 2>/dev/null || kdialog --getopenfilename ~ "image/*" 2>/dev/null || yad --file 2>/dev/null); [ -n "$f" ] && qs ipc call stickers add "$f"']
    }

    // Drop (copy) pictures into this folder and they appear on the desktop as stickers
    readonly property string folder: (shell.cv("stickers.folder", "~/Pictures/Stickers")).replace(/^~/, Quickshell.env("HOME"))
    Process {
        id: scan
        command: ["bash", "-c", 'mkdir -p "$1"; find "$1" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.svg" -o -iname "*.bmp" \\)', "bash", st.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = text.split("\n").filter(l => l !== "")
                let changed = false
                for (let i = 0; i < files.length; i++) {
                    if (st.known.indexOf(files[i]) >= 0) continue
                    st.known = st.known.concat([files[i]])
                    st.add(files[i], 0, "")
                    changed = true
                }
                if (changed) st.save()
            }
        }
    }
    Timer { interval: 2000; running: st.loaded; repeat: true; triggeredOnStart: true; onTriggered: scan.running = true }

    IpcHandler {
        target: "stickers"
        function add(path: string): int { return st.add(path, 0, "") }
        function addsize(path: string, size: int): int { return st.add(path, size, "") }
        function addscreen(path: string, size: int, screen: string): int { return st.add(path, size, screen) }
        function pick(): void { picker.running = true }
        function remove(id: int): void { st.remove(id) }
        function clear(): void { st.items = []; st.save() }
        function list(): string { return JSON.stringify(st.items) }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "pixel-stickers"
            visible: true

            // drag a picture from a file manager onto the bare desktop -> it becomes a sticker there
            DropArea {
                anchors.fill: parent
                onEntered: drag => console.log("stickers: drag entered", drag.formats)
                onDropped: drop => {
                    console.log("stickers: dropped", drop.formats)
                    let urls = drop.hasUrls ? drop.urls : []
                    if (urls.length === 0 && drop.hasText) urls = drop.text.split("\n").map(l => l.trim()).filter(l => l.indexOf("file://") === 0)
                    for (let i = 0; i < urls.length; i++) {
                        const u = urls[i].toString()
                        if (!/\.(png|jpe?g|webp|gif|svg|bmp)$/i.test(u)) continue
                        st.addAt(decodeURIComponent(u.replace(/^file:\/\//, "")),
                                 Math.max(0, Math.min(1, (drop.x + i * 30) / win.width)),
                                 Math.max(0, Math.min(1, (drop.y + i * 30) / win.height)),
                                 win.modelData.name)
                    }
                    drop.acceptProposedAction()
                }
            }

            MouseArea { anchors.fill: parent; onClicked: st.selectedId = -1 }

            Repeater {
                model: ScriptModel { values: st.idsFor(win.modelData.name) }   // delegates survive moves/rotation

                delegate: Item {
                    id: sticker
                    required property var modelData            // the sticker id
                    readonly property var d: st.byId(modelData) || ({ id: modelData, path: "", x: 0.5, y: 0.5, size: 100, rot: 0 })
                    width: d.size
                    height: d.size
                    x: d.x * win.width - width / 2
                    y: d.y * win.height - height / 2
                    rotation: d.rot
                    Behavior on rotation { enabled: !sticker.editing; NumberAnimation { duration: 120 } }
                    scale: 0
                    opacity: 0
                    Component.onCompleted: { scale = 1; opacity = 1 }
                    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    Behavior on width { enabled: !sticker.editing; NumberAnimation { duration: 90 } }
                    Behavior on height { enabled: !sticker.editing; NumberAnimation { duration: 90 } }

                    readonly property bool editing: st.selectedId === modelData
                    readonly property point center: Qt.point(d.x * win.width, d.y * win.height)
                    function winPos(item, mx, my) { return item.mapToItem(win.contentItem, mx, my) }

                    Image {
                        anchors.fill: parent
                        source: "file://" + sticker.d.path
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        mipmap: true
                        smooth: true
                        sourceSize: Qt.size(1024, 1024)
                    }

                    // move (left drag), open / close the editor (right click)
                    MouseArea {
                        id: body
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property point p0
                        property point c0
                        onPressed: m => {
                            if (m.button === Qt.RightButton) { st.selectedId = sticker.editing ? -1 : sticker.modelData; return }
                            p0 = sticker.winPos(body, m.x, m.y)
                            c0 = sticker.center
                        }
                        onPositionChanged: m => {
                            if (!(pressed && (m.buttons & Qt.LeftButton))) return
                            const p = sticker.winPos(body, m.x, m.y)
                            st.patch(sticker.modelData, {
                                x: Math.max(0, Math.min(1, (c0.x + p.x - p0.x) / win.width)),
                                y: Math.max(0, Math.min(1, (c0.y + p.y - p0.y) / win.height))
                            })
                        }
                    }

                    // ---------- editor (right click on a sticker) ----------
                    Rectangle {                                   // frame
                        visible: sticker.editing
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: 10
                        color: "transparent"
                        border.width: 2
                        border.color: "white"
                        opacity: sticker.editing ? 1 : 0
                    }
                    Rectangle {                                   // resize: drag the corner
                        visible: sticker.editing
                        x: sticker.width - 6; y: sticker.height - 6
                        width: 30; height: 30; radius: 15
                        color: st.shell.tileActive
                        border.width: 2; border.color: "white"
                        scale: rz.pressed ? 1.25 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                        Glyph { anchors.centerIn: parent; shell: st.shell; name: "arrow_forward"; size: 16; color: "white"; rotation: 45 }
                        MouseArea {
                            id: rz
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.SizeFDiagCursor
                            preventStealing: true
                            onPositionChanged: m => {
                                if (!pressed) return
                                const p = sticker.winPos(rz, m.x, m.y)
                                const dist = Math.hypot(p.x - sticker.center.x, p.y - sticker.center.y)
                                st.patch(sticker.modelData, { size: Math.max(40, Math.min(1600, dist * Math.SQRT2)) })
                            }
                        }
                    }
                    Rectangle {                                   // rotate: drag the round handle above
                        visible: sticker.editing
                        x: sticker.width / 2 - 15; y: -58
                        width: 30; height: 30; radius: 15
                        color: st.shell.tileActive
                        border.width: 2; border.color: "white"
                        scale: rt.pressed ? 1.25 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                        Glyph { anchors.centerIn: parent; shell: st.shell; name: "restart"; size: 16; color: "white" }
                        MouseArea {
                            id: rt
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.CrossCursor
                            preventStealing: true
                            onPositionChanged: m => {
                                if (!pressed) return
                                const p = sticker.winPos(rt, m.x, m.y)
                                let deg = Math.atan2(p.y - sticker.center.y, p.x - sticker.center.x) * 180 / Math.PI + 90
                                if (deg > 180) deg -= 360
                                st.patch(sticker.modelData, { rot: Math.round(deg) })
                            }
                        }
                        Rectangle { z: -1; x: 14; y: 30; width: 2; height: 28; color: "white" }   // stem to the sticker
                    }
                    Rectangle {                                   // toolbar: delete / done
                        visible: sticker.editing
                        x: sticker.width / 2 - width / 2; y: sticker.height + 22
                        width: 128; height: 48; radius: 24
                        color: st.shell.container
                        border.width: 1; border.color: "#40FFFFFF"
                        Row {
                            anchors.centerIn: parent
                            spacing: 12
                            Rectangle {
                                width: 40; height: 40; radius: dm.pressed ? 12 : 20; color: "#B3261E"
                                Behavior on radius { NumberAnimation { duration: 140 } }
                                Glyph { anchors.centerIn: parent; shell: st.shell; name: "delete"; size: 22; color: "white" }
                                MouseArea { id: dm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { st.selectedId = -1; st.remove(sticker.modelData) } }
                            }
                            Rectangle {
                                width: 40; height: 40; radius: om.pressed ? 12 : 20; color: st.shell.tileActive
                                Behavior on radius { NumberAnimation { duration: 140 } }
                                Glyph { anchors.centerIn: parent; shell: st.shell; name: "check"; size: 22; color: "white" }
                                MouseArea { id: om; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: st.selectedId = -1 }
                            }
                        }
                    }
                }
            }
        }
    }
}
