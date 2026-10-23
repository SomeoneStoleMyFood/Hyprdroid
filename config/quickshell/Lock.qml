import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

// Lock screen. `qs ipc call lock lock` -> every output is screenshotted (grim), then the session lock starts
// and each screen shows its blurred screenshot with the clock, widgets, avatar and password field.
Scope {
    id: lk
    required property var shell

    property bool locked: false
    property bool capturing: false
    property string shotStamp: ""
    property string pamState: ""          // "" | "checking" | "error"
    property string errorText: ""
    property int failCount: 0
    property string pending: ""
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    function shotUrl(name) { return "file://" + runtime + "/qs-lock-" + shotStamp + "-" + name + ".png" }

    function engage() {
        if (locked || capturing) return
        capturing = true
        shotStamp = Date.now().toString()
        pamState = ""
        errorText = ""
        shots.command = ["bash", "-c",
            's=$1; r=$2; shift 2; rm -f "$r"/qs-lock-*.png; for o in "$@"; do grim -o "$o" "$r/qs-lock-$s-$o.png" & done; wait',
            "bash", shotStamp, runtime].concat(Quickshell.screens.map(sc => sc.name))
        shots.running = true
        failsafe.restart()
    }
    function startLock() {
        failsafe.stop()
        if (!capturing) return
        capturing = false
        locked = true
    }
    function tryUnlock(password) {
        if (pam.active || password === "") return
        pending = password
        pamState = "checking"
        pam.start()
    }

    Process { id: shots; onExited: lk.startLock() }
    Timer { id: failsafe; interval: 2500; onTriggered: lk.startLock() }   // lock even if grim is missing or slow
    Process { id: cleanup; command: ["bash", "-c", "rm -f \"$1\"/qs-lock-*.png", "bash", lk.runtime] }
    onLockedChanged: if (!locked) { cleanup.running = true; pending = ""; pamState = "" }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("pam")
        config: "password.conf"
        onPamMessage: { if (responseRequired) respond(lk.pending) }
        onCompleted: result => {
            lk.pending = ""
            if (result === PamResult.Success) {
                lk.locked = false
            } else {
                lk.pamState = "error"
                lk.errorText = "Wrong password"
                lk.failCount++
            }
        }
        onError: {
            lk.pending = ""
            lk.pamState = "error"
            lk.errorText = "Authentication error"
        }
    }

    WlSessionLock {
        id: session
        locked: lk.locked

        WlSessionLockSurface {
            id: surf
            color: "black"
            LockSurface {
                anchors.fill: parent
                shell: lk.shell
                ctl: lk
                screenName: surf.screen.name
            }
        }
    }

    // qs ipc call lock lock      (bind it to a key; hypridle: lock_cmd = qs ipc call lock lock)
    IpcHandler {
        target: "lock"
        function lock(): void { lk.engage() }
        function isLocked(): bool { return lk.locked }
        // for testing only; enable in config.json: lock.allowIpcUnlock
        function unlock(): void { if (lk.shell.cv("lock.allowIpcUnlock", false)) lk.locked = false }
    }
}
