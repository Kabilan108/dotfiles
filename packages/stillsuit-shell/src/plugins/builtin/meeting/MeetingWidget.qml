import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property string outputId
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var meeting: workflows ? workflows.meeting : null
    readonly property bool failed: meeting && (meeting.failed || meeting.jobs.some(function(job) { return job.phase === "error" }))
    readonly property bool processing: meeting && meeting.active

    visible: meeting && meeting.visible
    theme: context.theme
    iconName: failed ? "danger" : processing ? "refresh" : "success"
    label: processing ? meeting.label : failed ? "Meeting failed" : "Meetings"
    active: processing || failed
    busy: processing
    accessibleName: processing ? "Meeting processing, " + meeting.label
        : failed ? "Meeting failed, open recent meetings" : "Open recent meetings"

    function openMeetings() {
        return context.actions.surfaceOpen("stillsuit.recording", "{\"view\":\"meetings\"}")
    }

    // The fixed payload selects the operational queue in RecordingPanel.
    // Do not toggle: a recording panel already open must switch views.
    onClicked: root.openMeetings()
}
