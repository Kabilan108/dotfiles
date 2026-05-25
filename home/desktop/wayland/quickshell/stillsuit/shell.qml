import Quickshell
import Quickshell.Io

ShellRoot {
    IpcHandler {
        target: "shell"

        function ping(): string {
            return "ok"
        }
    }

    VolumeOsd {
        id: volumeOsd
    }
    BrightnessOsd {
        stackOffset: volumeOsd.shouldShow ? 54 : 0
    }
    AudioMixer {}
    BluetoothPanel {}
    NotificationCenter {}
}
