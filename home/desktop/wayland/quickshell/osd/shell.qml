import Quickshell

ShellRoot {
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
