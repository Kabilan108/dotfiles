import QtQuick
import QtQuick.Layouts
import "../../../ui" as Ui

// Failed-job recovery for the recording panel. This is a trimmed, recording-local
// projection of what used to be the standalone meeting plugin's queue view: only
// the failed rows the panel exposes (capped at five, Details/Retry/Discard).
ColumnLayout {
    id: root

    required property var context
    required property var meeting
    property string detailsJobId: ""
    readonly property int rowLimit: 5
    readonly property var failedJobs: _failed(root.meeting ? root.meeting.jobs : []).slice(0, rowLimit)
    readonly property int failedCount: _failed(root.meeting ? root.meeting.jobs : []).length
    readonly property int rowCount: failedJobs.length
    spacing: root.context.theme.metrics.spaceUnit * 2

    function conciseError(value) {
        var firstLine = String(value || "Meeting processing failed").split("\n")[0].trim();
        return firstLine.length > 110 ? firstLine.slice(0, 107) + "..." : firstLine;
    }

    function _failed(jobs) {
        var rows = (Array.isArray(jobs) ? jobs : []).filter(function (job) {
            return job && String(job.phase || "") === "error";
        });
        rows.sort(function (left, right) {
            var timeDifference = Number(right.updatedAt || right.createdAt || 0) - Number(left.updatedAt || left.createdAt || 0);
            if (timeDifference !== 0)
                return timeDifference;
            return String(left.jobId || "").localeCompare(String(right.jobId || ""));
        });
        return rows;
    }

    Ui.ShellSectionLabel {
        Layout.fillWidth: true
        theme: root.context.theme
        text: root.failedCount > root.rowLimit ? "Failed meeting jobs · showing " + root.rowLimit + " of " + root.failedCount : "Failed meeting jobs"
        role: "danger"
    }

    Ui.ShellScrollArea {
        theme: root.context.theme
        Layout.fillWidth: true
        maximumHeight: 260
        contentHeight: failedColumn.implicitHeight

        ColumnLayout {
            id: failedColumn
            width: parent.width
            spacing: root.context.theme.metrics.spaceUnit * 2

            Repeater {
                model: root.failedJobs

                Ui.ShellSurface {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: jobContent.implicitHeight + root.context.theme.metrics.spaceUnit * 4
                    theme: root.context.theme
                    kind: "raised"
                    danger: true

                    ColumnLayout {
                        id: jobContent
                        anchors {
                            fill: parent
                            margins: root.context.theme.metrics.spaceUnit * 2
                        }
                        spacing: root.context.theme.metrics.spaceUnit

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
                            Ui.ShellButton {
                                theme: root.context.theme
                                label: "Discard"
                                iconName: "delete"
                                compact: true
                                ghost: true
                                destructive: true
                                busy: root.meeting && root.meeting.discardingJobId === modelData.jobId
                                enabled: root.meeting && root.meeting.retryConfigured && !root.meeting.actionRunning
                                accessibleName: "Discard " + modelData.title
                                onClicked: root.meeting.discard(modelData.jobId)
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
    }
}
