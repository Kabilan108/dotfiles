import QtQuick
import QtQuick.Layouts
import "../../../ui" as Ui

ColumnLayout {
    id: root

    required property var context
    required property var meeting
    property string detailsJobId: ""
    readonly property int rowCount: queue.pageJobs.length
    spacing: 10

    function phaseLabel(job) {
        if (!job)
            return "Unknown"
        if (job.phase === "error") return "Failed"
        if (job.phase === "completed") return "Completed"
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
        return job.total > 0 ? job.progress + "/" + job.total : ""
    }

    MeetingQueueModel {
        id: queue
        jobs: root.meeting ? root.meeting.jobs : []
    }

    Ui.ShellText {
        Layout.fillWidth: true
        theme: root.context.theme
        text: queue.actionableCount > 0
            ? "Operational queue · " + queue.actionableCount + " actionable"
            : "Operational queue"
        sizeRole: "caption"
        role: "muted"
    }

    Ui.ShellText {
        Layout.fillWidth: true
        theme: root.context.theme
        text: "Completed minutes remain in Obsidian."
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
                        onClicked: root.detailsJobId = root.detailsJobId === modelData.jobId ? "" : modelData.jobId
                    }
                    Ui.ShellButton {
                        visible: modelData.phase === "error"
                        theme: root.context.theme
                        label: "Retry"
                        iconName: "refresh"
                        compact: true
                        busy: root.meeting && root.meeting.retryingJobId === modelData.jobId
                        enabled: root.meeting && root.meeting.retryConfigured && !root.meeting.actionRunning
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
                ? queue.olderActionableCount + " older actionable · page " + (queue.page + 1) + " of " + queue.pageCount
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
