// Ported from home/desktop/wayland/quickshell/stillsuit/{TopBar,NiriState}.qml
// for Lane D4. This view uses HostContext compositor snapshots only and contains
// no Omarchy Quattro code.
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var context
    required property string outputId

    readonly property var workspaces: workspacesForOutput(context.compositor.workspaces || [], outputId)
    readonly property var activeWorkspace: activeWorkspaceForOutput(workspaces)
    readonly property int columns: columnCount(context.compositor.windows || [], activeWorkspace)
    readonly property int focusedColumn: focusedColumnForWorkspace(context.compositor.windows || [], activeWorkspace)
    readonly property bool reducedMotion: context.settings
        && context.settings.values
        && context.settings.values.reducedMotion === true
    readonly property int motionDuration: reducedMotion ? 0 : context.theme.motion.fast
    readonly property string accessibleName: "Workspaces and Niri columns on " + outputId
    readonly property bool inlineLayout: workspaceStrip.parent === contentRow
        && separator.parent === contentRow
        && columnStrip.parent === contentRow

    implicitWidth: contentRow.implicitWidth
    implicitHeight: context.theme.metrics.barHeight

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: 8

        Row {
            id: workspaceStrip

            spacing: 2

            Repeater {
                model: root.workspaces

                Item {
                    required property var modelData
                    readonly property bool active: modelData && modelData.is_active
                    readonly property bool urgent: modelData && modelData.is_urgent
                    readonly property int workspaceNumber: Number(modelData && modelData.idx || 0)

                    width: 16
                    height: 18

                    Rectangle {
                        anchors.fill: parent
                        radius: root.context.theme.metrics.radiusSmall
                        color: root.context.theme.component.bar.workspaceActive
                        opacity: parent.active ? 0.30 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.motionDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.workspaceNumber > 0 ? String(parent.workspaceNumber) : "?"
                        color: parent.active
                            ? root.context.theme.component.bar.workspaceActive
                            : parent.urgent
                                ? root.context.theme.semantic.status.danger
                                : root.context.theme.component.bar.workspaceIdle
                        font.family: root.context.theme.typography.monoFamily
                        font.pixelSize: root.context.theme.typography.captionSize
                        font.weight: parent.active || parent.urgent
                            ? root.context.theme.typography.weightBold
                            : root.context.theme.typography.weightMedium
                        renderType: Text.NativeRendering
                    }

                }
            }
        }

        Rectangle {
            id: separator

            visible: root.workspaces.length > 0
            Layout.preferredWidth: 1
            Layout.preferredHeight: 18
            color: root.context.theme.component.bar.separator
        }

        Row {
            id: columnStrip

            spacing: 4

            Repeater {
                model: root.columns

                Rectangle {
                    required property int index
                    readonly property bool focused: index + 1 === root.focusedColumn

                    width: focused ? 15 : 6
                    height: 10
                    radius: 2
                    color: focused
                        ? root.context.theme.component.bar.workspaceActive
                        : root.context.theme.component.bar.workspaceIdle
                    opacity: focused ? 1 : 0.6

                }
            }
        }
    }

    function workspacesForOutput(rows, requestedOutputId) {
        var result = []
        for (var index = 0; index < rows.length; index++) {
            var workspace = rows[index]
            if (workspace && String(workspace.output || workspace.output_id || "") === String(requestedOutputId))
                result.push(workspace)
        }
        result.sort(function(left, right) {
            var leftIndex = Number(left.idx || 0)
            var rightIndex = Number(right.idx || 0)
            return leftIndex === rightIndex ? Number(left.id || 0) - Number(right.id || 0) : leftIndex - rightIndex
        })
        return result
    }

    function activeWorkspaceForOutput(rows) {
        for (var index = 0; index < rows.length; index++) {
            if (rows[index] && rows[index].is_active)
                return rows[index]
        }
        return rows.length > 0 ? rows[0] : null
    }

    function windowsForWorkspace(rows, workspace) {
        if (!workspace)
            return []
        var result = []
        for (var index = 0; index < rows.length; index++) {
            var window = rows[index]
            if (window && String(window.workspace_id) === String(workspace.id) && !window.is_floating)
                result.push(window)
        }
        return result
    }

    function columnIndex(window) {
        var position = window && window.layout ? window.layout.pos_in_scrolling_layout : null
        return Array.isArray(position) && position.length > 0 ? Math.max(1, Number(position[0] || 1)) : 1
    }

    function columnCount(rows, workspace) {
        var windows = windowsForWorkspace(rows, workspace)
        if (!workspace)
            return 0
        var count = 1
        for (var index = 0; index < windows.length; index++)
            count = Math.max(count, columnIndex(windows[index]))
        return count
    }

    function focusedColumnForWorkspace(rows, workspace) {
        var windows = windowsForWorkspace(rows, workspace)
        for (var index = 0; index < windows.length; index++) {
            if (windows[index].is_focused || String(windows[index].id) === String(workspace.active_window_id))
                return columnIndex(windows[index])
        }
        return windows.length > 0 ? columnIndex(windows[0]) : 1
    }
}
