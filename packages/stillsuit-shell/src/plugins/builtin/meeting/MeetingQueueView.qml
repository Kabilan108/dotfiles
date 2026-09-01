import QtQuick
import QtQuick.Layouts
import "../../../ui" as Ui

ColumnLayout {
    id: root

    required property var context
    required property var meeting
    property string detailsJobId: ""
    readonly property int rowCount: queue.failedJobs.length
    spacing: 10

    function conciseError(value) {
        var firstLine = String(value || "Meeting processing failed").split("\n")[0].trim()
        return firstLine.length > 110 ? firstLine.slice(0, 107) + "..." : firstLine
    }

    MeetingQueueModel {
        id: queue
        jobs: root.meeting ? root.meeting.jobs : []
    }

    Ui.ShellText {
        Layout.fillWidth: true
        theme: root.context.theme
        text: queue.failedCount > queue.rowLimit
            ? "Failed meeting jobs · showing " + queue.rowLimit + " of " + queue.failedCount
            : "Failed meeting jobs"
        sizeRole: "section"
        role: "danger"
    }

    Repeater {
        model: queue.failedJobs
        Ui.ShellSurface {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: jobContent.implicitHeight + 16
            theme: root.context.theme
            kind: "raised"
            danger: true

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
                            text: root.conciseError(modelData.error)
                            sizeRole: "caption"
                            role: "danger"
                            elide: Text.ElideRight
                        }
                    }
                    Ui.ShellStatus {
                        theme: root.context.theme
                        status: "danger"
                        label: "Failed"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Ui.ShellText {
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Attempt " + modelData.attempt
                        sizeRole: "caption"
                        role: "muted"
                    }
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: root.detailsJobId === modelData.jobId ? "Hide details" : "Details"
                        iconName: "info"
                        compact: true
                        ghost: true
                        onClicked: root.detailsJobId = root.detailsJobId === modelData.jobId ? "" : modelData.jobId
                    }
                    Ui.ShellButton {
                        theme: root.context.theme
                        label: "Retry"
                        iconName: "refresh"
                        compact: true
                        busy: root.meeting && root.meeting.retryingJobId === modelData.jobId
                        enabled: root.meeting && root.meeting.retryConfigured && !root.meeting.actionRunning
                        onClicked: root.meeting.retry(modelData.jobId)
                    }
                }

                Ui.ShellText {
                    visible: root.detailsJobId === modelData.jobId
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

}
