import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Scope {
    id: root

    required property var context
    required property var screen
    required property string outputId
    readonly property var workflows: context.services.get("stillsuit.workflows")
    readonly property var meeting: workflows ? workflows.meeting : null
    property bool opened: false
    property string detailsJobId: ""

    function open(payloadJson) {
        opened = true
        if (meeting)
            meeting.refresh()
    }

    function close() {
        opened = false
        detailsJobId = ""
    }

    function closeSurface() {
        context.actions.surfaceClose("stillsuit.meeting")
    }

    function phaseLabel(job) {
        if (!job)
            return "Unknown"
        if (job.phase === "error")
            return "Failed"
        if (job.phase === "completed")
            return "Completed"
        if (job.phase === "queued" || job.phase === "staging")
            return job.phase === "staging" ? "Staging" : "Queued"
        return job.label || job.phase
    }

    function phaseStatus(job) {
        if (job.phase === "error") return "danger"
        if (job.phase === "completed") return "success"
        if (job.phase === "queued" || job.phase === "staging") return "muted"
        return "info"
    }

    function conciseError(value) {
        var firstLine = String(value || "Meeting processing failed").split("\n")[0].trim()
        return firstLine.length > 110 ? firstLine.slice(0, 107) + "..." : firstLine
    }

    function progressText(job) {
        if (job.total > 0)
            return job.progress + "/" + job.total
        return ""
    }

    MeetingQueueModel {
        id: queue
        jobs: root.meeting ? root.meeting.jobs : []
    }

    PanelWindow {
        screen: root.screen
        visible: root.opened
        anchors { top: true; left: true; right: true; bottom: true }
        exclusiveZone: 0
        focusable: true
        color: "transparent"

        MouseArea { anchors.fill: parent; onClicked: root.closeSurface() }

        Ui.ShellSurface {
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: root.context.theme.metrics.barHeight + 8
            }
            width: 500
            height: meetingContent.implicitHeight + 32
            theme: root.context.theme
            kind: "panel"

            MouseArea {
                anchors.fill: parent
                onClicked: function(mouse) { mouse.accepted = true }
            }

            ColumnLayout {
                id: meetingContent
                anchors { fill: parent; margins: 16 }
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Ui.ShellIcon {
                        theme: root.context.theme
                        name: root.meeting && root.meeting.failed ? "danger"
                            : root.meeting && root.meeting.active ? "refresh" : "success"
                        role: root.meeting && root.meeting.failed ? "danger"
                            : root.meeting && root.meeting.active ? "accent" : "success"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Ui.ShellText {
                            theme: root.context.theme
                            text: "Recent meetings"
                            sizeRole: "heading"
                        }
                        Ui.ShellText {
                            visible: root.meeting && root.meeting.active
                            theme: root.context.theme
                            text: root.meeting ? root.meeting.label : ""
                            sizeRole: "caption"
                            role: "muted"
                        }
                    }
                    Ui.ShellStatus {
                        visible: queue.actionableCount > 0
                        theme: root.context.theme
                        status: "info"
                        label: queue.actionableCount + " actionable"
                    }
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: ""
                        iconName: "close"
                        compact: true
                        ghost: true
                        accessibleName: "Close recent meetings"
                        onClicked: root.closeSurface()
                    }
                }

                Ui.ShellText {
                    Layout.fillWidth: true
                    theme: root.context.theme
                    text: "This is the operational queue. Completed minutes remain in Obsidian."
                    sizeRole: "caption"
                    role: "muted"
                    wrapMode: Text.Wrap
                }

                Ui.ShellStateView {
                    visible: !root.meeting || root.meeting.jobsStateStatus === "corrupt"
                        || root.meeting.jobsStateStatus === "unsupported" || queue.rankedJobs.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 130
                    theme: root.context.theme
                    mode: !root.meeting || root.meeting.jobsStateStatus === "corrupt"
                        || root.meeting.jobsStateStatus === "unsupported" ? "error" : "empty"
                    title: !root.meeting ? "Meeting workflow unavailable"
                        : root.meeting.jobsStateStatus === "corrupt" || root.meeting.jobsStateStatus === "unsupported"
                            ? "Meeting queue could not be read" : "No recent meetings"
                    message: queue.rankedJobs.length === 0
                        ? "Finish a recording as a meeting to add it here." : ""
                }

                Repeater {
                    model: queue.pageJobs
                    Ui.ShellSurface {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: jobContent.implicitHeight + 16
                        theme: root.context.theme
                        kind: "raised"
                        danger: modelData.phase === "error"

                        ColumnLayout {
                            id: jobContent
                            anchors { fill: parent; margins: 8 }
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Ui.ShellText {
                                        Layout.fillWidth: true
                                        theme: root.context.theme
                                        text: modelData.title
                                        sizeRole: "label"
                                        elide: Text.ElideRight
                                    }
                                    Ui.ShellText {
                                        Layout.fillWidth: true
                                        theme: root.context.theme
                                        text: modelData.phase === "error"
                                            ? root.conciseError(modelData.error)
                                            : modelData.label || root.phaseLabel(modelData)
                                        sizeRole: "caption"
                                        role: modelData.phase === "error" ? "danger" : "muted"
                                        elide: Text.ElideRight
                                    }
                                }
                                Ui.ShellStatus {
                                    theme: root.context.theme
                                    status: root.phaseStatus(modelData)
                                    label: root.phaseLabel(modelData)
                                }
                                Ui.ShellText {
                                    visible: root.progressText(modelData) !== ""
                                    theme: root.context.theme
                                    text: root.progressText(modelData)
                                    sizeRole: "caption"
                                    monospace: true
                                    role: "secondary"
                                }
                            }

                            RowLayout {
                                visible: modelData.phase === "error" || modelData.phase === "completed"
                                Layout.fillWidth: true
                                Ui.ShellText {
                                    Layout.fillWidth: true
                                    theme: root.context.theme
                                    text: "Attempt " + modelData.attempt
                                    sizeRole: "caption"
                                    role: "muted"
                                }
                                Ui.ShellButton {
                                    visible: modelData.phase === "error"
                                    theme: root.context.theme
                                    label: root.detailsJobId === modelData.jobId ? "Hide details" : "Details"
                                    iconName: "info"
                                    compact: true
                                    ghost: true
                                    onClicked: root.detailsJobId = root.detailsJobId === modelData.jobId
                                        ? "" : modelData.jobId
                                }
                                Ui.ShellButton {
                                    visible: modelData.phase === "error"
                                    theme: root.context.theme
                                    label: "Retry"
                                    iconName: "refresh"
                                    compact: true
                                    busy: root.meeting && root.meeting.retryingJobId === modelData.jobId
                                    enabled: root.meeting && root.meeting.retryConfigured
                                        && !root.meeting.actionRunning
                                    onClicked: root.meeting.retry(modelData.jobId)
                                }
                                Ui.ShellButton {
                                    visible: modelData.phase === "completed"
                                    theme: root.context.theme
                                    label: "Open in Obsidian"
                                    iconName: "folder"
                                    compact: true
                                    busy: root.meeting && root.meeting.actionRunning
                                    enabled: modelData.notePath.startsWith("/")
                                    onClicked: root.meeting.openResult(modelData.jobId)
                                }
                            }

                            Ui.ShellText {
                                visible: modelData.phase === "error" && root.detailsJobId === modelData.jobId
                                Layout.fillWidth: true
                                theme: root.context.theme
                                text: modelData.error || "No error details were recorded."
                                sizeRole: "caption"
                                role: "secondary"
                                monospace: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 8
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                RowLayout {
                    visible: queue.pageCount > 1
                    Layout.fillWidth: true
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: "Previous"
                        iconName: "chevron-left"
                        compact: true
                        enabled: queue.hasPreviousPage
                        onClicked: queue.previousPage()
                    }
                    Ui.ShellText {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: queue.olderActionableCount > 0
                            ? queue.olderActionableCount + " older actionable · page "
                                + (queue.page + 1) + " of " + queue.pageCount
                            : "Page " + (queue.page + 1) + " of " + queue.pageCount
                        sizeRole: "caption"
                        role: "muted"
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: "Next"
                        iconName: "chevron-right"
                        compact: true
                        enabled: queue.hasNextPage
                        onClicked: queue.nextPage()
                    }
                }
            }
        }
    }
}
