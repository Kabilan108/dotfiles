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
        stackOffset: volumeOsd.shouldShow ? Math.max(Theme.osdHeight, 58) + Theme.panelGap : 0
    }
    AudioMixer {}
    BluetoothPanel {}
    NotificationCenter {}
    DevGallery {}
}
