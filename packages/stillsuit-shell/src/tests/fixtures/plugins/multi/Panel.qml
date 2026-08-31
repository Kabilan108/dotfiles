import QtQuick

QtObject {
    required property var context
    required property var screen
    required property string outputId
    required property var service

    property bool opened: false
    property var receivedPayloads: []
    readonly property string fixtureKind: "panel"

    function open(payloadJson) {
        var next = receivedPayloads.slice()
        next.push(String(payloadJson))
        receivedPayloads = next
        opened = true
    }

    function close() {
        opened = false
    }
}
