import QtQuick

QtObject {
    id: root

    required property var context
    readonly property string apiVersion: "1"
    property date now: new Date()

    property Timer clockTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
