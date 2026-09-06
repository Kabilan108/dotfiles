// A notification the host raises itself, shaped like a
// Quickshell.Services.Notifications object so NotificationService tracks it
// without a D-Bus round trip. Containment reports and workbench fixtures use it.
import QtQuick

QtObject {
    id: root

    property int id: 0
    property string appName: ""
    property string appIcon: ""
    property string summary: ""
    property string body: ""
    property string image: ""
    property int urgency: 1
    property int expireTimeout: 0
    property var actions: []
    property var hints: ({})
    property bool tracked: false
    property string lastInvoked: ""

    signal closed()

    function dismiss() { closed() }
    function expire() { closed() }
}
