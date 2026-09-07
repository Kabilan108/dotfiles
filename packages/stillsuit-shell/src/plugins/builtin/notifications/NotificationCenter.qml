import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: root.theme.metrics.panelWidth
    implicitHeight: panelLayout.implicitHeight + root.theme.metrics.panelPadding * 2
    visible: false
    property bool opened: false

    required property var context
    required property var screen
    required property var service

    property string outputId: String(screen.name || "")
    readonly property var rows: service ? service.centerRows() : []
    readonly property var sections: service ? service.centerSections() : []
    readonly property var sourceSnoozes: service ? service.activeSnoozes() : []
    readonly property var theme: context.theme
    property var collapsedSources: ({})

    function open(payloadJson) {
        opened = true;
        return service ? service.openCenter(outputId) : "error";
    }

    function close() {
        opened = false;
        return service ? service.closeCenter(outputId) : "error";
    }

    function toggle(payloadJson) {
        return service ? service.toggleCenter(outputId) : "error";
    }

    function relativeTime(timestamp) {
        var minutes = Math.floor(Math.max(0, Date.now() - Number(timestamp || 0)) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return String(minutes) + "m";
        var hours = Math.floor(minutes / 60);
        return hours < 24 ? String(hours) + "h" : String(Math.floor(hours / 24)) + "d";
    }

    function untilText(timestamp) {
        var date = new Date(Number(timestamp || 0))
        return date.toLocaleString(Qt.locale(), "ddd HH:mm")
    }

    function sourceCollapsed(key) {
        return Boolean(collapsedSources[key])
    }

    function toggleSourceCollapsed(key) {
        var next = Object.assign({}, collapsedSources)
        next[key] = !sourceCollapsed(key)
        collapsedSources = next
    }

    Ui.ShellSurface {
        id: panel

        anchors.fill: parent

        theme: root.theme
        kind: "panel"

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = true
        }

        ColumnLayout {
            id: panelLayout

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.theme.metrics.panelPadding
            }
            spacing: root.theme.metrics.spaceUnit * 2

            RowLayout {
                Layout.fillWidth: true

                Ui.ShellText {
                    theme: root.theme
                    text: "Notifications"
                    sizeRole: "heading"
                }

                Ui.ShellText {
                    theme: root.theme
                    text: String(root.rows.length) + " recent"
                    sizeRole: "caption"
                    role: "muted"
                    monospace: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Ui.ShellButton {
                    visible: root.rows.length > 0
                    theme: root.theme
                    label: "Clear all"
                    iconName: "delete"
                    compact: true
                    ghost: true
                    destructive: true
                    accessibleName: "Delete all notification history"
                    onClicked: root.service.clearHistory()
                }
            }

            RowLayout {
                id: globalQuietRow
                Layout.fillWidth: true
                spacing: 6

                Ui.ShellIcon {
                    theme: root.theme
                    name: "notifications-off"
                    sizeRole: "small"
                    role: "muted"
                    accessibleName: "Quiet notifications"
                }

                Ui.ShellText {
                    Layout.fillWidth: root.service && root.service.quietActive
                    theme: root.theme
                    text: root.service && root.service.quietActive
                        ? "Quiet until " + root.untilText(root.service.globalSnoozeUntil)
                        : "Quiet"
                    sizeRole: "label"
                    role: root.service && root.service.quietActive ? "muted" : "primary"
                    elide: Text.ElideRight
                }

                Item {
                    visible: !root.service || !root.service.quietActive
                    Layout.fillWidth: true
                }

                Repeater {
                    model: root.service && root.service.quietActive ? [] : [
                        { label: "30m", preset: "30m" },
                        { label: "1h", preset: "1h" },
                        { label: "4h", preset: "4h" },
                        { label: "Tomorrow", preset: "tomorrow" }
                    ]
                    Ui.ShellButton {
                        required property var modelData
                        theme: root.theme
                        label: modelData.label
                        compact: true
                        onClicked: root.service.snooze("*", modelData.preset)
                    }
                }

                Ui.ShellButton {
                    visible: root.service && root.service.quietActive
                    theme: root.theme
                    label: "Wake"
                    iconName: "notifications"
                    compact: true
                    ghost: true
                    foregroundColor: root.theme.semantic.status.warning
                    onClicked: root.service.wake("*")
                }
            }

            Flickable {
                Layout.fillWidth: true
                implicitHeight: Math.min(centerColumn.implicitHeight, 420)
                contentHeight: centerColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                ColumnLayout {
                    id: centerColumn

                    width: parent.width
                    spacing: root.theme.metrics.spaceUnit * 2

                    Repeater {
                        model: root.sections

                        ColumnLayout {
                            id: sourceSection
                            required property var modelData
                            readonly property bool sourceSnoozed: Boolean(root.service
                                && root.service.snoozes[modelData.key]
                                && Number(root.service.snoozes[modelData.key].until || 0) > Date.now())
                            readonly property bool collapsed: root.sourceCollapsed(modelData.key)
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true

                                Ui.ShellButton {
                                    id: groupToggle
                                    theme: root.theme
                                    label: sourceSection.modelData.label + " · "
                                        + String(sourceSection.modelData.rows.length)
                                    iconName: sourceSection.collapsed ? "expand-more" : "expand-less"
                                    compact: true
                                    ghost: true
                                    accessibleName: sourceSection.collapsed
                                        ? "Expand " + sourceSection.modelData.label + " notifications"
                                        : "Collapse " + sourceSection.modelData.label + " notifications"
                                    onClicked: root.toggleSourceCollapsed(sourceSection.modelData.key)
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                Ui.ShellButton {
                                    theme: root.theme
                                    label: sourceSection.sourceSnoozed ? "Wake" : "1h"
                                    iconName: sourceSection.sourceSnoozed
                                        ? "notifications" : "notifications-off"
                                    compact: true
                                    ghost: true
                                    foregroundColor: sourceSection.sourceSnoozed
                                        ? root.theme.semantic.status.warning : "transparent"
                                    accessibleName: sourceSection.sourceSnoozed
                                        ? "Wake " + sourceSection.modelData.label
                                        : "Quiet " + sourceSection.modelData.label + " for one hour"
                                    onClicked: {
                                        if (sourceSection.sourceSnoozed)
                                            root.service.wake(sourceSection.modelData.key)
                                        else
                                            root.service.snooze(sourceSection.modelData.key, "1h")
                                    }
                                }

                                Ui.ShellButton {
                                    theme: root.theme
                                    label: ""
                                    iconName: "delete"
                                    compact: true
                                    ghost: true
                                    destructive: true
                                    accessibleName: "Clear all "
                                        + sourceSection.modelData.label + " notifications"
                                    onClicked: root.service.clearSource(sourceSection.modelData.key)
                                }
                            }

                            Repeater {
                                model: sourceSection.collapsed ? [] : modelData.rows
                                NotificationCard {
                                    required property var modelData
                                    context: root.context
                                    service: root.service
                                    snapshot: modelData
                                    inline: true
                                    timeText: root.relativeTime(modelData.timestamp)
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Ui.ShellEmptyRow {
                        visible: root.rows.length === 0
                        Layout.fillWidth: true
                        theme: root.theme
                        iconName: "notifications"
                        text: "No notifications"
                        iconSizeRole: "medium"
                        textSizeRole: "label"
                    }
                }
            }
        }
    }
}
