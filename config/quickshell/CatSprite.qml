import QtQuick
import QtQuick.Shapes

// A cat drawn with plain QML shapes. Driven by: sleepAmt (0 sitting .. 1 curled up asleep), eyeOpen, happy, mouth, bob, sad.
Item {
    id: c
    property real size: 140
    property color base: "#F0A04B"
    property real sleepAmt: 0
    property real eyeOpen: 1
    property real happy: 0
    property real mouth: 0
    property real bob: 0              // head dips towards the bowl
    property real sad: 0
    property string bowl: ""          // "" | "food" | "water"
    property real squash: 1
    property real blink: 1
    property real loveT: 1
    readonly property color dark: Qt.darker(base, 1.45)
    readonly property color light: Qt.lighter(base, 1.4)
    readonly property real s: Math.max(0, Math.min(1.08, sleepAmt))
    width: size
    height: size

    function lerp(a, b, t) { return a + (b - a) * t }
    function love() { loveAnim.restart() }
    function stretch() { stretchAnim.restart() }

    Behavior on sleepAmt { SpringAnimation { spring: 3; damping: 0.38; epsilon: 0.005 } }
    NumberAnimation { id: loveAnim; target: c; property: "loveT"; from: 0; to: 1; duration: 1700 }
    SequentialAnimation {
        id: stretchAnim
        NumberAnimation { target: c; property: "squash"; to: 1.14; duration: 380; easing.type: Easing.OutCubic }
        PauseAnimation { duration: 280 }
        SpringAnimation { target: c; property: "squash"; to: 1; spring: 5; damping: 0.25; epsilon: 0.002 }
    }
    // blinking
    Timer {
        interval: 2800 + Math.random() * 3500; repeat: true; running: c.sleepAmt < 0.5
        onTriggered: { interval = 2800 + Math.random() * 3500; blinkAnim.restart() }
    }
    SequentialAnimation { id: blinkAnim
        NumberAnimation { target: c; property: "blink"; to: 0.05; duration: 70 }
        NumberAnimation { target: c; property: "blink"; to: 1; duration: 110 } }
    property real swing: 0
    SequentialAnimation on swing { loops: Animation.Infinite
        NumberAnimation { from: -10; to: 24; duration: 1500; easing.type: Easing.InOutSine }
        NumberAnimation { from: 24; to: -10; duration: 1500; easing.type: Easing.InOutSine } }
    property real breathe: 1
    SequentialAnimation on breathe { loops: Animation.Infinite
        NumberAnimation { from: 1; to: 1.025; duration: 2200; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.025; to: 1; duration: 2200; easing.type: Easing.InOutSine } }

    Item {
        id: stage
        width: 160; height: 160
        scale: c.size / 160
        transformOrigin: Item.TopLeft
        transform: Scale { origin.x: 80; origin.y: 150; yScale: c.squash; xScale: 2 - c.squash }

        // ---- tail ----
        Rectangle {
            id: tail
            width: 16; height: 72; radius: 8
            color: c.base
            x: c.lerp(116, 124, c.s); y: c.lerp(88, 120, c.s)
            transformOrigin: Item.Top
            rotation: c.lerp(c.swing, 92, c.s)
            z: c.s > 0.5 ? 6 : 0
        }
        // ---- body ----
        Rectangle {
            id: body
            x: c.lerp(34, 12, c.s); y: c.lerp(66, 98, c.s)
            width: c.lerp(92, 136, c.s); height: c.lerp(84, 58, c.s)
            radius: Math.min(width, height) / 2
            color: c.base
            transformOrigin: Item.Bottom
            scale: c.breathe
            z: 1
            Rectangle { x: 24; y: 26; width: 44; height: 52; radius: 22; color: c.light; opacity: 1 - c.s }
            Rectangle { x: 18; y: 8; width: 3; height: 16; radius: 1.5; color: c.dark; opacity: 0.55 }
            Rectangle { x: 70; y: 8; width: 3; height: 16; radius: 1.5; color: c.dark; opacity: 0.55 }
            Rectangle { x: 28; y: 5; width: 3; height: 18; radius: 1.5; color: c.dark; opacity: 0.55 * c.s }
            Rectangle { x: 60; y: 5; width: 3; height: 18; radius: 1.5; color: c.dark; opacity: 0.55 * c.s }
        }
        // front paws (sitting)
        Rectangle { x: 48; y: 136; width: 28; height: 20; radius: 10; color: c.light; opacity: 1 - c.s; z: 2 }
        Rectangle { x: 84; y: 136; width: 28; height: 20; radius: 10; color: c.light; opacity: 1 - c.s; z: 2 }
        // paws tucked under the chin (sleeping)
        Rectangle { x: 26; y: 140; width: 28; height: 18; radius: 9; color: c.light; opacity: c.s; z: 5 }
        Rectangle { x: 56; y: 144; width: 28; height: 16; radius: 8; color: c.light; opacity: c.s; z: 5 }

        // ---- head ----
        Item {
            id: head
            width: 68; height: 58
            x: c.lerp(46, 20, c.s) + c.bob * 8
            y: c.lerp(18, 92, c.s) + c.bob * 16
            rotation: c.lerp(c.sad * 3, -10, c.s)
            z: 4
            // ears
            Item {
                x: 0; y: 0; width: 68; height: 30
                rotation: -c.sad * 14 - c.s * 6
                transformOrigin: Item.BottomLeft
                Shape { ShapePath { fillColor: c.base; strokeColor: "transparent"; PathPolyline { path: [Qt.point(4, 18), Qt.point(7, -16), Qt.point(32, 4)] } } }
                Shape { ShapePath { fillColor: "#F4A6B5"; strokeColor: "transparent"; PathPolyline { path: [Qt.point(10, 12), Qt.point(12, -5), Qt.point(24, 5)] } } }
            }
            Item {
                x: 0; y: 0; width: 68; height: 30
                rotation: c.sad * 14 + c.s * 6
                transformOrigin: Item.BottomRight
                Shape { ShapePath { fillColor: c.base; strokeColor: "transparent"; PathPolyline { path: [Qt.point(64, 18), Qt.point(61, -16), Qt.point(36, 4)] } } }
                Shape { ShapePath { fillColor: "#F4A6B5"; strokeColor: "transparent"; PathPolyline { path: [Qt.point(58, 12), Qt.point(56, -5), Qt.point(44, 5)] } } }
            }
            Rectangle { id: skull; anchors.fill: parent; radius: 30; color: c.base }
            // forehead stripes
            Rectangle { x: 26; y: 2; width: 3; height: 11; radius: 1.5; color: c.dark; opacity: 0.6 }
            Rectangle { x: 33; y: 0; width: 3; height: 13; radius: 1.5; color: c.dark; opacity: 0.6 }
            Rectangle { x: 40; y: 2; width: 3; height: 11; radius: 1.5; color: c.dark; opacity: 0.6 }
            // cheeks
            Rectangle { x: 4; y: 38; width: 14; height: 8; radius: 4; color: "#FF9AAE"; opacity: c.happy * 0.65 }
            Rectangle { x: 50; y: 38; width: 14; height: 8; radius: 4; color: "#FF9AAE"; opacity: c.happy * 0.65 }
            // eyes
            Repeater {
                model: [15, 43]
                delegate: Item {
                    required property int modelData
                    readonly property real open: Math.max(0, 1 - c.s * 1.6) * c.eyeOpen * c.blink * (1 - c.happy)
                    Rectangle {
                        visible: c.happy < 0.5
                        x: parent.modelData; y: 32 - h / 2
                        readonly property real h: 3 + 13 * parent.open
                        width: 11; height: h; radius: 5.5
                        color: "#2B2118"
                        Rectangle { visible: parent.height > 9; x: 6; y: 2; width: 4; height: 4; radius: 2; color: "white" }
                    }
                    Text { visible: c.happy >= 0.5; x: parent.modelData - 1.5; y: 18; text: "^"; color: "#2B2118"; font.pixelSize: 20; font.bold: true }
                }
            }
            // nose, mouth, whiskers
            Rectangle { x: 29.5; y: 40; width: 9; height: 6; radius: 3; color: "#E98FA3" }
            Rectangle { x: 29; y: 47; width: 10; height: 2 + c.mouth * 11; radius: 5; color: "#7B2D3C" }
            Repeater {
                model: [{ x: -10, r: 8, y: 42 }, { x: -10, r: -6, y: 48 }, { x: 56, r: -8, y: 42 }, { x: 56, r: 6, y: 48 }]
                delegate: Rectangle { required property var modelData; x: modelData.x; y: modelData.y; width: 22; height: 1.6; radius: 1; color: "#F3E9DC"; rotation: modelData.r }
            }
        }

        // ---- bowl ----
        Item {
            x: 104; y: 132; width: 56; height: 28
            scale: c.bowl !== "" ? 1 : 0
            transformOrigin: Item.Bottom
            z: 7
            Behavior on scale { SpringAnimation { spring: 6; damping: 0.35; epsilon: 0.002 } }
            Rectangle { anchors.bottom: parent.bottom; width: 56; height: 22; radius: 11; color: c.bowl === "food" ? "#C9794A" : "#6F8FC9" }
            Rectangle { x: 6; y: 2; width: 44; height: 12; radius: 6; color: c.bowl === "food" ? "#7B4A2B" : "#A9DAFF" }
            Repeater {
                model: c.bowl === "food" ? 5 : 0
                delegate: Rectangle { required property int index; x: 10 + index * 8; y: index % 2 ? 0 : -3; width: 8; height: 8; radius: 4; color: "#9A6238" }
            }
        }

        // ---- hearts ----
        Repeater {
            model: 5
            delegate: Item {
                id: hrt
                required property int index
                readonly property real p: Math.max(0, Math.min(1, c.loveT * 1.35 - index * 0.14))
                x: 62 + (index - 2) * 20 + Math.sin(p * 6 + index) * 8
                y: 10 - 80 * p
                opacity: c.loveT >= 1 ? 0 : Math.sin(p * Math.PI)
                scale: 0.6 + 0.7 * p
                z: 9
                ShapeDot { kind: "heart"; size: 18; color: index % 2 ? "#FF7DA0" : "#FFB3C6" }
            }
        }
        // ---- zzz ----
        Repeater {
            model: 3
            delegate: Text {
                id: zz
                required property int index
                x: 104 + index * 14; y: 48 - index * 16
                text: "z"; color: "white"; font.bold: true; font.pixelSize: 18 + index * 7
                opacity: c.s > 0.7 ? zp : 0
                property real zp: 0
                SequentialAnimation on zp { loops: Animation.Infinite; running: c.s > 0.7
                    PauseAnimation { duration: zz.index * 450 }
                    NumberAnimation { from: 0; to: 0.9; duration: 700 }
                    NumberAnimation { from: 0.9; to: 0; duration: 900 }
                    PauseAnimation { duration: (2 - zz.index) * 450 } }
                transform: Translate { y: -zz.zp * 10 }
                z: 9
            }
        }
    }
}
