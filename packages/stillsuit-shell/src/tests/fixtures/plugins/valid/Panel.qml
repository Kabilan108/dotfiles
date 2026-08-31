import QtQuick

QtObject {
    required property var context
    property string outputId: ""
    property var output: null
    property bool opened: false
    property var receivedPayloads: []

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
