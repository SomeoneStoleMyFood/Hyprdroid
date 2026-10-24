import QtQuick

// Animated cat from icons/cat/<anim>.gif | .webp | .png | .apng (first one that exists). `ready` is false when no file exists.
Item {
    id: a
    property string anim: "idle"
    property bool flip: false
    readonly property bool ready: img.status === Image.Ready
    readonly property var exts: [".gif", ".webp", ".png", ".apng"]
    property int idx: 0
    onAnimChanged: idx = 0
    AnimatedImage {
        id: img
        anchors.fill: parent
        source: a.idx < a.exts.length ? Qt.resolvedUrl("icons/cat/" + a.anim + a.exts[a.idx]) : ""
        fillMode: Image.PreserveAspectFit
        mirror: a.flip
        smooth: true
        playing: true
        onStatusChanged: if (status === Image.Error && a.idx < a.exts.length) a.idx++
    }
}
