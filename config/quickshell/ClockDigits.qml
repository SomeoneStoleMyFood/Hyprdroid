import QtQuick

// One line of the big lock-screen clock (slides in, pops when the value changes)
Text {
    id: dg
    required property var lock
    property real delay: 0
    property real appear: lock.stage(delay)
    font.family: lock.clockFont
    font.pixelSize: Math.round(lock.height * 0.2)
    font.weight: Font.Bold
    lineHeight: 0.84
    opacity: lock.eo(appear)
    transform: Translate { y: (1 - dg.lock.sp(dg.appear)) * dg.lock.height * 0.09 }
    scale: 0.82 + 0.18 * lock.sp(appear)
    onTextChanged: if (lock.intro >= 1) pop.restart()
    // a new digit pops: squash, then a spatial spring back with a little overshoot
    SequentialAnimation {
        id: pop
        ScriptAction { script: { dg.scale = 0.88; dg.opacity = 0.5 } }
        ParallelAnimation {
            SpringAnimation { target: dg; property: "scale"; to: 1; spring: 5; damping: 0.26; epsilon: 0.002 }
            NumberAnimation { target: dg; property: "opacity"; to: 1; duration: 200 }
        }
    }
}
