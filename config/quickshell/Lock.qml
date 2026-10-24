import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Lock screen. `qs ipc call lock lock` -> every output is screenshotted (grim), then the session lock starts.
// The password is checked by an existing program: unix_chkpwd (part of PAM/shadow, the same helper su/hyprlock use).
// Override with lock.checkCommand in config.json: any shell command that reads the password from $PW, exit 0 = OK.
Scope {
    id: lk
    property var shell: null

    property bool locked: false
    property bool capturing: false
    property string shotStamp: ""
    property string pamState: ""          // "" | "checking" | "error"
    property string errorText: ""
    property int failCount: 0
    property bool unlocking: false        // plays the exit animation before the lock really goes away
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string user: Quickshell.env("USER") || ""
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
        if (password === "" || pamState === "checking") return
        pamState = "checking"
        errorText = ""
        check.environment = ({ "PW": password, "LOCK_USER": user })
        check.running = true
        checkTimeout.restart()
    }
    Process {
        id: check
        command: ["bash", "-c", lk.shell && lk.shell.cv("lock.checkCommand", "") !== "" ? lk.shell.cv("lock.checkCommand", "") : [
            'u="$LOCK_USER"',
            'for h in /usr/bin/unix_chkpwd /usr/sbin/unix_chkpwd /sbin/unix_chkpwd /usr/lib/unix_chkpwd; do [ -x "$h" ] && break; h=""; done',
            '[ -z "$h" ] && exit 127',
            'printf "%s\\0" "$PW" | "$h" "$u" nullok'
        ].join("\n")]
        onExited: code => {
            checkTimeout.stop()
            check.environment = ({})
            if (code === 0) { lk.pamState = ""; lk.unlocking = true; unlockTimer.restart() }
            else {
                lk.pamState = "error"
                lk.errorText = code === 127 ? "unix_chkpwd not found" : "Wrong password"
                lk.failCount++
            }
        }
    }
    Timer { id: unlockTimer; interval: 760; onTriggered: { lk.locked = false; lk.unlocking = false } }
    Timer { id: checkTimeout; interval: 6000; onTriggered: { check.running = false } }   // never hang on "checking"

    Process { id: shots; onExited: lk.startLock() }
    Timer { id: failsafe; interval: 2500; onTriggered: lk.startLock() }   // lock even if grim is missing or slow
    Process { id: cleanup; command: ["bash", "-c", "rm -f \"$1\"/qs-lock-*.png", "bash", lk.runtime] }
    onLockedChanged: if (!locked) { cleanup.running = true; pamState = "" }

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
        function unlock(): void { if (lk.shell.cv("lock.allowIpcUnlock", false)) { lk.unlocking = true; unlockTimer.restart() } }
    }
}
