// Minimal stand-in for a Quickshell.Services.Notifications object so the real
// NotificationService can track fixture toasts without owning the D-Bus name.
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
