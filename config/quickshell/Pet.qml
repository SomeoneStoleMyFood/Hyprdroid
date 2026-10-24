import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Desktop cat. Off by default (config.json -> pet.enabled, or `qs ipc call pet enable`).
// Right click the cat for the menu: pet / feed / give water. It sleeps while the computer is off and wakes up when the shell starts.
Scope {
    id: pet
    required property var shell
    property int override: -1                     // -1 = follow config, 0 = off, 1 = on
    readonly property bool enabled: override >= 0 ? override === 1 : shell.cv("pet.enabled", false)
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell-pixel"
    readonly property string catName: shell.cv("pet.name", "Mochi")

    // needs, 0..100 (100 = full / happy)
    property real satiety: 80
    property real hydration: 80
    property real affection: 70
    property bool waking: false
    property bool walking: false
    readonly property real fx: shell.cv("pet.x", 0.85)        // horizontal position (fraction of the screen); the cat lives at the bottom edge
    property bool sleeping: true
    property string action: ""                   // "" | eat | drink | pat
    property string bubbleIcon: ""
    property string bubbleText: ""
    property bool menuOpen: false
    property bool loaded: false
    property real lastActivity: Date.now()

    function clamp(v) { return Math.max(0, Math.min(100, v)) }
    readonly property real worst: Math.min(satiety, hydration, affection)
    readonly property string moodText: sleeping ? "Sleeping… zzz" : action === "eat" ? "Eating!" : action === "drink" ? "Drinking!" : action === "pat" ? "Purring" :
        satiety < 25 ? "Hungry" : hydration < 25 ? "Thirsty" : affection < 25 ? "Lonely" : worst > 70 ? "Happy" : "Fine"
    readonly property real sadness: sleeping ? 0 : worst < 25 ? 1 : worst < 45 ? 0.5 : 0

    // ---------- persistence ----------
    function save() { if (loaded) file.setText(JSON.stringify({ satiety: satiety, hydration: hydration, affection: affection, lastSeen: Date.now() }, null, 1)) }
    Timer { id: saveTimer; interval: 15000; running: pet.enabled; repeat: true; onTriggered: pet.save() }
    Timer { id: saveSoon; interval: 600; onTriggered: pet.save() }
    FileView {
        id: file
        path: pet.stateDir + "/pet.json"
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text())
                const hrs = Math.min(24, Math.max(0, (Date.now() - (j.lastSeen || Date.now())) / 3600000))
                const off = 0.25                              // the cat needs less while you are away (it sleeps)
                pet.satiety = pet.clamp((j.satiety !== undefined ? j.satiety : 80) - pet.rate("hunger") * hrs * off)
                pet.hydration = pet.clamp((j.hydration !== undefined ? j.hydration : 80) - pet.rate("thirst") * hrs * off)
                pet.affection = pet.clamp((j.affection !== undefined ? j.affection : 70) - pet.rate("mood") * hrs * off)
            } catch (e) { console.warn("pet.json:", e) }
            pet.loaded = true
            wakeTimer.restart()
        }
        onLoadFailed: { pet.loaded = true; wakeTimer.restart() }
    }
    onEnabledChanged: if (enabled) { sleeping = true; wakeTimer.restart() }

    // ---------- life ----------
    function rate(k) { return shell.cv("pet.decayPerHour." + k, k === "hunger" ? 8 : k === "thirst" ? 12 : 6) }
    Timer {
        interval: 20000; running: pet.enabled && pet.loaded; repeat: true
        onTriggered: {
            const f = pet.sleeping ? 0.4 : 1
            const tick = 20 / 3600
            pet.satiety = pet.clamp(pet.satiety - pet.rate("hunger") * tick * f)
            pet.hydration = pet.clamp(pet.hydration - pet.rate("thirst") * tick * f)
            pet.affection = pet.clamp(pet.affection - pet.rate("mood") * tick * f * (pet.satiety < 25 || pet.hydration < 25 ? 2 : 1))
            if (!pet.sleeping && pet.action === "" && !pet.menuOpen && Date.now() - pet.lastActivity > pet.shell.cv("pet.idleMinutes", 15) * 60000) pet.sleepNow()
            saveSoon.restart()
        }
    }
    Timer {                                        // asks for what it needs
        interval: 90000; running: pet.enabled && pet.loaded; repeat: true
        onTriggered: {
            if (pet.sleeping || pet.action !== "") return
            if (pet.satiety < 30) pet.say("restaurant", "Meow! Food?")
            else if (pet.hydration < 30) pet.say("water_drop", "Mew… water?")
            else if (pet.affection < 30) pet.say("favorite", "Pet me…")
        }
    }
    Timer { id: wakeTimer; interval: 1400; onTriggered: pet.wake() }
    Timer { id: bubbleTimer; interval: 3800; onTriggered: { pet.bubbleIcon = ""; pet.bubbleText = "" } }
    Timer { id: actionTimer; onTriggered: { pet.action = "" } }

    function say(icon, text) { bubbleIcon = icon; bubbleText = text; bubbleTimer.restart() }
    function touch() { lastActivity = Date.now() }
    function wake() {
        touch()
        if (!sleeping) return
        sleeping = false
        waking = true
        wakingTimer.restart()
        say("", "mrrp!")
    }
    Timer { id: wakingTimer; interval: shell.cv("pet.wakeMs", 1900); onTriggered: pet.waking = false }
    // from time to time the cat walks (in place - it never leaves its spot)
    Timer {
        interval: 25000 + Math.random() * 20000; running: pet.enabled && !pet.sleeping; repeat: true
        onTriggered: { interval = 25000 + Math.random() * 20000; if (pet.action === "" && !pet.waking && !pet.menuOpen) { pet.walking = true; walkTimer.restart() } }
    }
    Timer { id: walkTimer; interval: 5000; onTriggered: pet.walking = false }
    readonly property string spriteAnim: sleeping ? "sleep" : waking ? "wake" : action === "eat" ? "eat" : action === "drink" ? "drink" : action === "pat" ? "pat"
                                       : sadness > 0.9 ? "sad" : walking ? "walk" : "idle"
    function sleepNow() { action = ""; walking = false; waking = false; sleeping = true; menuOpen = false; saveSoon.restart() }
    function doAction(kind, ms) {
        touch()
        if (sleeping) { wake() ; actionDelay.kind = kind; actionDelay.interval = 1000; actionDelay.ms = ms; actionDelay.restart(); return }
        run(kind, ms)
    }
    Timer { id: actionDelay; property string kind: ""; property int ms: 0; onTriggered: pet.run(kind, ms) }
    function run(kind, ms) {
        action = kind
        actionTimer.interval = ms
        actionTimer.restart()
        saveSoon.restart()
    }
    function feed() {
        if (satiety > 96) { touch(); wake(); say("restaurant", "Not hungry"); return }
        satiety = clamp(satiety + 38); affection = clamp(affection + 3); doAction("eat", 3400)
    }
    function water() {
        if (hydration > 96) { touch(); wake(); say("water_drop", "Not thirsty"); return }
        hydration = clamp(hydration + 42); affection = clamp(affection + 2); doAction("drink", 3000)
    }
    function pat() { affection = clamp(affection + 16); doAction("pat", 2800) }

    IpcHandler {
        target: "pet"
        function enable(): void { pet.override = 1 }
        function disable(): void { pet.override = 0 }
        function toggle(): void { pet.override = pet.enabled ? 0 : 1 }
        function feed(): void { pet.feed() }
        function water(): void { pet.water() }
        function pat(): void { pet.pat() }
        function sleep(): void { pet.sleepNow(); pet.save() }        // call before you power off
        function wake(): void { pet.wake() }
        function status(): string { return JSON.stringify({ name: pet.catName, mood: pet.moodText, satiety: Math.round(pet.satiety), hydration: Math.round(pet.hydration), affection: Math.round(pet.affection), sleeping: pet.sleeping }) }
        function reset(): void { pet.satiety = 80; pet.hydration = 80; pet.affection = 70; pet.save() }
    }

    function layerOf(n) {
        return n === "overlay" ? WlrLayer.Overlay : n === "bottom" ? WlrLayer.Bottom : n === "background" ? WlrLayer.Background : WlrLayer.Top
    }

    Variants {
        model: pet.enabled ? Quickshell.screens : []

        Scope {
            id: sc
            required property var modelData
            readonly property string target: pet.shell.cv("pet.screen", "main")
            readonly property bool here: target === "main" ? modelData.name === pet.shell.mainScreenName : modelData.name === target

            // click anywhere else closes the menu (exists only while the menu is open)
            PanelWindow {
                screen: sc.modelData
                visible: sc.here && pet.menuOpen
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "pixel-pet-scrim"
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: pet.menuOpen = false }
            }

            PanelWindow {
                id: win
                screen: sc.modelData
                visible: sc.here
                anchors { bottom: true; left: true; right: true }
                implicitHeight: 460
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                // while the menu is open the cat window sits above the click-away layer
                WlrLayershell.layer: pet.menuOpen ? WlrLayer.Overlay : pet.layerOf(pet.shell.cv("pet.layer", "top"))
                WlrLayershell.namespace: "pixel-pet"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                // input only on the cat and on the menu: fixed regions, no switching
                mask: Region { item: catHit; Region { item: menuBox } }

                readonly property real catSize: pet.shell.cv("pet.size", 140)

                // ---------- the cat (bottom edge, walks in place) ----------
                Item {
                    id: catHit
                    width: win.catSize; height: win.catSize
                    x: pet.fx * win.width - width / 2
                    y: win.height - height - pet.shell.cv("pet.bottomMargin", 0)
                    scale: 0
                    transformOrigin: Item.Bottom
                    Component.onCompleted: scale = 1
                    Behavior on scale { SpringAnimation { spring: 4; damping: 0.3; epsilon: 0.002 } }

                    // 1) your own animations from icons/cat/<name>.gif|webp|png
                    CatArt {
                        id: art
                        anchors.fill: parent
                        anim: pet.spriteAnim
                        flip: pet.shell.cv("pet.flip", false)
                    }
                    // 2) built-in drawn cat when there is no file for the current animation
                    CatSprite {
                        id: cat
                        anchors.fill: parent
                        visible: !art.ready
                        size: win.catSize
                        base: pet.shell.cv("pet.color", "#F0A04B")
                        sleepAmt: pet.sleeping ? 1 : 0
                        eyeOpen: pet.sleeping ? 0 : pet.sadness > 0.9 ? 0.75 : 1
                        happy: pet.action === "pat" ? 1 : 0
                        sad: pet.sadness
                        bowl: pet.action === "eat" ? "food" : pet.action === "drink" ? "water" : ""
                        mouth: yawn
                        bob: (pet.action === "eat" || pet.action === "drink") ? eatPhase : 0
                        property real eatPhase: 0
                        property real yawn: 0
                        SequentialAnimation on eatPhase {
                            running: pet.action === "eat" || pet.action === "drink"; loops: Animation.Infinite
                            NumberAnimation { from: 0; to: 1; duration: 330; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1; to: 0; duration: 330; easing.type: Easing.InOutSine }
                        }
                        SequentialAnimation { id: yawnAnim
                            NumberAnimation { target: cat; property: "yawn"; to: 1; duration: 520; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 450 }
                            NumberAnimation { target: cat; property: "yawn"; to: 0; duration: 380 } }
                    }
                    // walking in place (drawn cat only): little hops
                    SequentialAnimation on y {
                        running: pet.walking && !art.ready && !pet.sleeping
                        loops: Animation.Infinite
                        NumberAnimation { to: win.height - catHit.height - pet.shell.cv("pet.bottomMargin", 0) - 5; duration: 170; easing.type: Easing.OutQuad }
                        NumberAnimation { to: win.height - catHit.height - pet.shell.cv("pet.bottomMargin", 0); duration: 170; easing.type: Easing.InQuad }
                    }
                    Connections {
                        target: pet
                        function onSleepingChanged() { if (!pet.sleeping) { cat.stretch(); yawnAnim.restart() } }
                        function onActionChanged() { if (pet.action === "pat") cat.love() }
                    }

                    // speech / need bubble
                    Rectangle {
                        visible: opacity > 0.01
                        opacity: pet.bubbleText !== "" ? 1 : 0
                        scale: pet.bubbleText !== "" ? 1 : 0.6
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.002 } }
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 4
                        height: 36; width: bRow.implicitWidth + 26; radius: 18
                        color: pet.shell.container
                        border.width: 1; border.color: "#26FFFFFF"
                        Row {
                            id: bRow
                            anchors.centerIn: parent; spacing: 6
                            Glyph { visible: pet.bubbleIcon !== ""; shell: pet.shell; name: pet.bubbleIcon; size: 18; color: pet.shell.textColor; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: pet.bubbleText; color: pet.shell.textColor; font.family: pet.shell.fontFamily; font.pixelSize: 14; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => {
                            pet.touch()
                            if (m.button === Qt.RightButton) { pet.wake(); pet.menuOpen = !pet.menuOpen }
                            else if (pet.sleeping) pet.wake()
                        }
                    }
                }

                // ---------- menu (Pixel style), opens next to the cat ----------
                Item {
                    id: menuBox
                    readonly property bool toRight: catHit.x + catHit.width + 258 < win.width
                    width: pet.menuOpen ? 248 : 0
                    height: pet.menuOpen ? menu.height : 0
                    x: toRight ? catHit.x + catHit.width + 10 : catHit.x - 248 - 10
                    y: win.height - height - pet.shell.cv("pet.bottomMargin", 0) - 10

                    Rectangle {
                        id: menu
                        width: 248
                        height: mc.implicitHeight + 28
                        visible: opacity > 0.01
                        opacity: pet.menuOpen ? 1 : 0
                        scale: pet.menuOpen ? 1 : 0.7
                        transformOrigin: menuBox.toRight ? Item.BottomLeft : Item.BottomRight
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Behavior on scale { SpringAnimation { spring: 6; damping: 0.34; epsilon: 0.002 } }
                        anchors.bottom: parent.bottom
                        radius: 30
                        color: pet.shell.container
                        border.width: 1; border.color: "#26FFFFFF"

                        ColumnLayout {
                            id: mc
                            anchors.fill: parent; anchors.margins: 14; spacing: 10
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    spacing: 0
                                    Text { text: pet.catName; color: pet.shell.textColor; font.family: pet.shell.fontFamily; font.pixelSize: 20; font.weight: Font.Bold }
                                    Text { text: pet.moodText; color: pet.shell.textColor; opacity: 0.8; font.family: pet.shell.fontFamily; font.pixelSize: 13 }
                                }
                                Item { Layout.fillWidth: true }
                                ShapeDot { kind: "cookie"; size: 38; color: pet.shell.cv("pet.color", "#F0A04B") }
                            }
                            Repeater {
                                model: [{ icon: "restaurant", v: pet.satiety, c: "#F9D66F" }, { icon: "water_drop", v: pet.hydration, c: "#8AD7F2" }, { icon: "favorite", v: pet.affection, c: "#FF9AAE" }]
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true; spacing: 10
                                    Glyph { shell: pet.shell; name: modelData.icon; size: 18; color: pet.shell.textColor }
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 10; radius: 5; color: pet.shell.containerHigh
                                        Rectangle {
                                            height: parent.height; radius: 5
                                            width: Math.max(10, parent.width * parent.parent.modelData.v / 100)
                                            color: parent.parent.modelData.v < 25 ? "#F2B8B5" : parent.parent.modelData.c
                                            Behavior on width { SpringAnimation { spring: 5; damping: 0.4; epsilon: 0.5 } }
                                        }
                                    }
                                }
                            }
                            Repeater {
                                model: [{ icon: "favorite", label: "Pet", act: "pat" }, { icon: "restaurant", label: "Feed", act: "feed" }, { icon: "water_drop", label: "Give water", act: "water" }]
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 48
                                    radius: am.pressed ? 14 : 24
                                    color: am.containsMouse ? pet.shell.containerHigh : pet.shell.surface
                                    Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    scale: am.pressed ? 0.96 : 1
                                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.4; epsilon: 0.002 } }
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 18; spacing: 12
                                        Glyph { shell: pet.shell; name: modelData.icon; size: 22; color: pet.shell.textColor; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: modelData.label; color: pet.shell.textColor; font.family: pet.shell.fontFamily; font.pixelSize: 16; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        id: am
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { pet.menuOpen = false; if (modelData.act === "pat") pet.pat(); else if (modelData.act === "feed") pet.feed(); else pet.water() }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
