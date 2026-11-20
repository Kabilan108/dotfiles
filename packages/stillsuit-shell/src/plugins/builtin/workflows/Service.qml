import QtQuick
import Quickshell
import "../../../services" as Services

Scope {
    id: root

    required property var context

    readonly property string apiVersion: "1"
    readonly property QtObject recording: recordingService
    readonly property QtObject meeting: meetingService
    readonly property QtObject dictator: dictatorService

    Services.RecordingService {
        id: recordingService
        context: root.context
    }
    Services.MeetingService {
        id: meetingService
        context: root.context
    }
    Services.DictatorService {
        id: dictatorService
        context: root.context
    }
}
