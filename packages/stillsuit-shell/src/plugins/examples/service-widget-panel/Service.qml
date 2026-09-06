import QtQuick

// One instance shell-wide. Owns state, timers, and any process or socket;
// per-output views only read it and call its methods. Other plugins reach it
// through context.services.get("stillsuit.example-counter") after declaring
// it in their manifest `dependencies`.
QtObject {
    id: root

    required property var context
    readonly property string apiVersion: "1"
    property int count: 0
    property int ticks: 0

    property Timer ticker: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.ticks += 1
    }

    function increment() { count += 1 }
    function reset() { count = 0 }
}
