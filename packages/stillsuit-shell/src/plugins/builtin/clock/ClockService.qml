import QtQuick
import Quickshell

QtObject {
    id: root

    required property var context
    readonly property string apiVersion: "1"
    property date now: systemClock.date

    property SystemClock systemClock: SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }
}
