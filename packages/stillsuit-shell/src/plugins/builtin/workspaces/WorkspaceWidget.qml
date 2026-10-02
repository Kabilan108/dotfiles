// Ported from the retired v1 shell (TopBar and NiriState views)
// for Lane D4. This view uses HostContext compositor snapshots only and contains
// no Omarchy Quattro code.
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    required property var context
    required property string outputId

    readonly property var workspaces: workspacesForOutput(context.compositor.workspaces || [], outputId)
    readonly property var workspaceKeys: workspaceKeysFor(workspaces)
    readonly property var activeWorkspace: activeWorkspaceForOutput(workspaces)
    readonly property var columnState: columnStateForWorkspace(context.compositor.windows || [], activeWorkspace)
    readonly property int columns: columnState.count
    readonly property int focusedColumn: columnState.focused
    readonly property bool reducedMotion: context.settings
        && context.settings.values
        && context.settings.values.reducedMotion === true
    readonly property int motionDuration: reducedMotion ? 0 : context.theme.motion.fast
    readonly property string accessibleName: "Workspaces and Niri columns on " + outputId
    property string tooltipText: accessibleName
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

            // The model holds plain string keys, so a compositor event keeps
            // each workspace's cell instead of recreating every cell. Rows are
            // not used as values: with objectProp, Quickshell 0.3.1's
            // ScriptModel rewrites positions after a changed row without
            // checking keys, handing a removed cell to its neighbour.
            Repeater {
                model: ScriptModel {
                    values: root.workspaceKeys.keys
                }

                Item {
                    required property var modelData
                    readonly property var workspace: root.workspaceKeys.rows[modelData] || null
                    readonly property bool active: !!workspace && workspace.is_active === true
                    readonly property bool urgent: !!workspace && workspace.is_urgent === true
                    readonly property int workspaceNumber: Number(workspace && workspace.idx || 0)

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

    function workspaceKeysFor(rows) {
        var keys = []
        var byKey = {}
        for (var index = 0; index < rows.length; index++) {
            var workspace = rows[index]
            var key = workspace.id !== undefined ? "id:" + String(workspace.id) : "index:" + index
            keys.push(key)
            byKey[key] = workspace
        }
        return { keys: keys, rows: byKey }
    }

    function activeWorkspaceForOutput(rows) {
        for (var index = 0; index < rows.length; index++) {
            if (rows[index] && rows[index].is_active)
                return rows[index]
        }
        return rows.length > 0 ? rows[0] : null
    }

    function columnIndex(window) {
        var position = window && window.layout ? window.layout.pos_in_scrolling_layout : null
        return Array.isArray(position) && position.length > 0 ? Math.max(1, Number(position[0] || 1)) : 1
    }

    // One pass over the windows yields both the column count and the focused
    // column of the active workspace.
    function columnStateForWorkspace(rows, workspace) {
        if (!workspace)
            return { count: 0, focused: 1 }
        var workspaceId = String(workspace.id)
        var activeWindowId = String(workspace.active_window_id)
        var count = 1
        var firstColumn = 0
        var focused = 0
        for (var index = 0; index < rows.length; index++) {
            var window = rows[index]
            if (!window || String(window.workspace_id) !== workspaceId || window.is_floating)
                continue
            var column = columnIndex(window)
            count = Math.max(count, column)
            if (firstColumn === 0)
                firstColumn = column
            if (focused === 0 && (window.is_focused || String(window.id) === activeWindowId))
                focused = column
        }
        return { count: count, focused: focused || firstColumn || 1 }
    }
}
