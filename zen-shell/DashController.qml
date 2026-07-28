import Quickshell
import Quickshell.Io

/*
 * DashController.qml  —  Zen Unified Dashboard (v8)
 *
 * IPC endpoint (root is an IpcHandler, mirroring the existing
 * IpcHandler { target: "zen" } in shell.qml). Invoke:
 *   qs -c zen-shell ipc call dash toggle       # open/close on focused monitor
 *   qs -c zen-shell ipc call dash notifs       # open on the Notifications tab
 *   qs -c zen-shell ipc call dash close
 */
IpcHandler {
    target: "dash"

    function toggle() { DashState.toggle(DashState.focusedScreenName()) }
    function open()   { DashState.open(DashState.focusedScreenName()) }
    function close()  { DashState.close() }
    function notifs() { DashState.tab = "notifs"; DashState.open(DashState.focusedScreenName()) }
    function controls(){ DashState.tab = "controls"; DashState.open(DashState.focusedScreenName()) }
}
