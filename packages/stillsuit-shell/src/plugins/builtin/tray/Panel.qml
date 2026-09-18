import QtQuick
import Quickshell
import Stillsuit.Ui as Ui

// Compact context menu for one tray item, rendered in-shell from its DBusMenu
// through nested QsMenuOpener objects. Each level keeps its own live opener: a
// child entry is owned by its parent opener's model, so a single reused opener
// would destroy the entry being displayed.
Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: Math.max(minimumWidth, Math.min(maximumWidth, contentWidth + padding * 2))
    implicitHeight: menuColumn.implicitHeight + padding * 2
    visible: false

    required property var context
    required property var service
    required property var screen
    required property string outputId

    readonly property var theme: context.theme
    readonly property int padding: theme.metrics.spaceUnit
    readonly property int rowHeight: theme.metrics.spaceUnit * 6
    readonly property int rowInset: theme.metrics.spaceUnit + 2
    readonly property int leadInset: rowInset
    readonly property int glyphColumn: theme.metrics.iconSmall
    readonly property int minimumWidth: theme.metrics.spaceUnit * 32
    readonly property int maximumWidth: theme.metrics.spaceUnit * 80
    readonly property int maximumRows: 14
    property real contentWidth: minimumWidth
    property var activeItem: null
    readonly property string activeTitle: service ? service.tooltipFor(activeItem) : ""
    readonly property var activeWindows: submenuDepth === 0 && service && activeItem
        ? service.windowsFor(activeItem) : []
    readonly property bool hasMenu: activeItem !== null && Boolean(activeItem.hasMenu)
        && activeItem.menu !== null && activeItem.menu !== undefined

    property var submenuStack: []
    readonly property int submenuDepth: submenuStack.length
    readonly property string currentTitle: submenuDepth > 0 ? submenuStack[submenuDepth - 1].title : ""
    readonly property var currentChildren: submenuDepth > 0
        ? submenuStack[submenuDepth - 1].opener.children
        : rootOpener.children
    // Entering a level rebuilds the rows under a cursor that has not moved;
    // ignore clicks for a beat so a double-click cannot fire the row that took
    // the spot. A timestamp rather than a Timer: per-output views own no timers.
    readonly property int settleMs: 250
    property real settleUntil: 0

    function open(payloadJson) {
        var payload = {}
        try { payload = JSON.parse(payloadJson || "{}") || {} } catch (error) { payload = {} }
        resetMenu()
        activeItem = service ? service.itemById(payload.itemId) : null
    }

    function close() {
        resetMenu()
        activeItem = null
    }

    function resetMenu() {
        settleUntil = 0
        menuScroll.contentY = 0
        var openers = submenuStack
        submenuStack = []
        for (var index = openers.length - 1; index >= 0; index--) openers[index].opener.destroy()
    }

    function settle() {
        settleUntil = Date.now() + settleMs
    }

    function clickAllowed() {
        return Date.now() >= settleUntil
    }

    function enterSubmenu(entry, title) {
        var opener = submenuOpenerComponent.createObject(root, { menu: entry })
        if (!opener) return
        menuScroll.contentY = 0
        var stack = submenuStack.slice()
        stack.push({ opener: opener, title: title })
        submenuStack = stack
        settle()
    }

    function leaveSubmenu() {
        if (submenuStack.length === 0) return
        menuScroll.contentY = 0
        var stack = submenuStack.slice()
        var top = stack.pop()
        submenuStack = stack
        top.opener.destroy()
        settle()
    }

    function trigger(entry) {
        entry.triggered()
        context.actions.surfaceClose("stillsuit.tray")
    }

    function measure() {
        var widest = 0
        for (var index = 0; index < rowRepeater.count; index++) {
            var row = rowRepeater.itemAt(index)
            if (row && row.visible && row.naturalWidth > widest) widest = row.naturalWidth
        }
        for (var w = 0; w < windowRepeater.count; w++) {
            var windowRow = windowRepeater.itemAt(w)
            if (windowRow && windowRow.naturalWidth > widest) widest = windowRow.naturalWidth
        }
        contentWidth = widest
    }

    function windowLabel(window) {
        var title = String(window && window.title || "").trim()
        return title !== "" ? title : String(window && window.app_id || "window")
    }

    function workspaceLabel(window) {
        var rows = context && context.compositor ? (context.compositor.workspaces || []) : []
        for (var index = 0; index < rows.length; index++) {
            var workspace = rows[index]
            if (workspace && String(workspace.id) === String(window.workspace_id))
                return String(workspace.name || workspace.idx || "")
        }
        return ""
    }

    function raise(window) {
        service.focusWindow(window)
        context.actions.surfaceClose("stillsuit.tray")
    }

    // The root row of a submenu-less app menu often repeats the app's own name
    // as a disabled title entry followed by a separator; the header already
    // says which item this is, so skip that pair.
    function rowHidden(entry, index) {
        if (!entry) return true
        if (submenuDepth > 0) return false
        var text = String(entry.text || "").toLowerCase()
        if (index === 0 && !entry.enabled && !entry.hasChildren && text === activeTitle.toLowerCase())
            return true
        return Boolean(entry.isSeparator) && index <= 1 && index === firstVisibleIndex(index)
    }

    function firstVisibleIndex(index) {
        return index === 0 ? 0 : (rowRepeater.itemAt(0) && rowRepeater.itemAt(0).hidden ? 1 : -1)
    }

    Component {
        id: submenuOpenerComponent
        QsMenuOpener {}
    }

    QsMenuOpener {
        id: rootOpener
        menu: root.hasMenu ? root.activeItem.menu : null
    }

    Ui.ShellSurface {
        anchors.fill: parent
        theme: root.theme
        kind: "panel"

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }

        Column {
            id: menuColumn
            anchors { fill: parent; margins: root.padding }
            spacing: 0

            // Submenu header: names the level and walks back out. Pinned above
            // the scroll area so the way back stays reachable in a tall menu.
            Item {
                id: backRow
                visible: root.submenuDepth > 0
                width: menuColumn.width
                height: visible ? root.rowHeight : 0

                Rectangle {
                    anchors.fill: parent
                    radius: root.theme.metrics.radiusSmall
                    color: backPointer.containsMouse ? root.theme.component.panel.rowHover : "transparent"
                }
                Ui.ShellIcon {
                    anchors { left: parent.left; leftMargin: root.rowInset; verticalCenter: parent.verticalCenter }
                    theme: root.theme
                    name: "chevron-left"
                    sizeRole: "small"
                    role: "secondary"
                }
                Ui.ShellText {
                    anchors {
                        left: parent.left; leftMargin: root.rowInset + root.glyphColumn + root.theme.metrics.spaceUnit
                        right: parent.right; rightMargin: root.rowInset
                        verticalCenter: parent.verticalCenter
                    }
                    theme: root.theme
                    text: root.currentTitle
                    sizeRole: "caption"
                    role: "secondary"
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: backPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.clickAllowed()) root.leaveSubmenu()
                }
            }

            Rectangle {
                visible: backRow.visible
                width: menuColumn.width
                height: visible ? 1 : 0
                color: root.theme.semantic.outline.subtle
            }

            // Open windows for this app, before the app's own menu: the most
            // common reason to click a tray icon is to get back to the window.
            Column {
                id: windowSection
                visible: root.activeWindows.length > 0
                width: menuColumn.width
                spacing: 0

                Repeater {
                    id: windowRepeater
                    model: root.activeWindows
                    onCountChanged: Qt.callLater(root.measure)

                    Item {
                        id: windowRow
                        required property var modelData
                        readonly property string labelText: root.windowLabel(modelData)
                        readonly property string workspaceText: root.workspaceLabel(modelData)
                        readonly property real naturalWidth: root.leadInset + root.rowInset
                            + root.theme.metrics.spaceUnit * 2 + Math.min(windowLabel.implicitWidth, root.maximumWidth * 0.7)
                            + (workspaceText !== "" ? workspaceLabel.implicitWidth + root.theme.metrics.spaceUnit * 2 : 0)

                        width: windowSection.width
                        height: root.rowHeight
                        onNaturalWidthChanged: Qt.callLater(root.measure)

                        Rectangle {
                            anchors.fill: parent
                            radius: root.theme.metrics.radiusSmall
                            color: windowPointer.containsMouse ? root.theme.component.panel.rowHover
                                : windowRow.modelData.is_focused ? root.theme.component.panel.rowSelected : "transparent"
                        }
                        Ui.ShellText {
                            id: windowLabel
                            anchors {
                                left: parent.left; leftMargin: root.leadInset
                                right: workspaceLabel.visible ? workspaceLabel.left : parent.right
                                rightMargin: root.rowInset
                                verticalCenter: parent.verticalCenter
                            }
                            theme: root.theme
                            text: windowRow.labelText
                            sizeRole: "caption"
                            role: "primary"
                            elide: Text.ElideRight
                        }
                        Ui.ShellText {
                            id: workspaceLabel
                            visible: windowRow.workspaceText !== ""
                            anchors { right: parent.right; rightMargin: root.rowInset; verticalCenter: parent.verticalCenter }
                            theme: root.theme
                            text: windowRow.workspaceText
                            sizeRole: "caption"
                            role: "muted"
                            monospace: true
                        }
                        MouseArea {
                            id: windowPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.raise(windowRow.modelData)
                        }
                    }
                }

                Rectangle {
                    visible: root.hasMenu
                    width: windowSection.width
                    height: visible ? root.theme.metrics.spaceUnit + 3 : 0
                    color: "transparent"
                    Rectangle {
                        anchors {
                            left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                            leftMargin: root.rowInset; rightMargin: root.rowInset
                        }
                        height: 1
                        color: root.theme.semantic.outline.subtle
                    }
                }
            }

            Ui.ShellEmptyRow {
                visible: root.activeItem === null || (!root.hasMenu && root.activeWindows.length === 0)
                width: menuColumn.width
                theme: root.theme
                iconName: "info"
                text: root.activeItem === null ? "Tray item is gone" : "No menu"
            }

            Ui.ShellScrollArea {
                id: menuScroll
                visible: root.hasMenu
                width: menuColumn.width
                theme: root.theme
                maximumHeight: root.rowHeight * root.maximumRows
                contentHeight: rows.implicitHeight

                Column {
                    id: rows
                    width: menuScroll.width
                    spacing: 0

                    Repeater {
                        id: rowRepeater
                        model: root.currentChildren
                        onCountChanged: Qt.callLater(root.measure)

                        Item {
                            id: menuRow
                            required property var modelData
                            required property int index
                            readonly property string rowText: String(modelData.text || "")
                            readonly property bool separator: Boolean(modelData.isSeparator)
                            readonly property bool checkable: modelData.buttonType !== undefined
                                && modelData.buttonType !== QsMenuButtonType.None
                            readonly property bool checked: modelData.checkState === Qt.Checked
                            readonly property bool enabled: Boolean(modelData.enabled)
                            readonly property bool hidden: root.rowHidden(modelData, index)
                            readonly property bool trailingGlyph: Boolean(modelData.hasChildren) || checkable
                            readonly property real naturalWidth: separator ? 0
                                : root.leadInset + root.rowInset + root.theme.metrics.spaceUnit * 2
                                    + label.implicitWidth + (trailingGlyph ? root.glyphColumn + root.theme.metrics.spaceUnit : 0)

                            visible: !hidden
                            width: rows.width
                            height: hidden ? 0 : separator ? root.theme.metrics.spaceUnit + 3 : root.rowHeight
                            onNaturalWidthChanged: Qt.callLater(root.measure)

                            Rectangle {
                                visible: menuRow.separator
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: root.rowInset; rightMargin: root.rowInset
                                }
                                height: 1
                                color: root.theme.semantic.outline.subtle
                            }

                            Rectangle {
                                visible: !menuRow.separator
                                anchors.fill: parent
                                radius: root.theme.metrics.radiusSmall
                                color: rowPointer.containsMouse && menuRow.enabled
                                    ? root.theme.component.panel.rowHover : "transparent"
                            }

                            Ui.ShellText {
                                id: label
                                visible: !menuRow.separator
                                anchors {
                                    left: parent.left
                                    leftMargin: root.leadInset
                                    right: trailingGlyphItem.visible ? trailingGlyphItem.left : parent.right
                                    rightMargin: root.rowInset
                                    verticalCenter: parent.verticalCenter
                                }
                                theme: root.theme
                                text: menuRow.rowText
                                sizeRole: "caption"
                                role: menuRow.enabled ? "primary" : "disabled"
                                elide: Text.ElideRight
                            }

                            Ui.ShellIcon {
                                id: trailingGlyphItem
                                visible: !menuRow.separator && (Boolean(menuRow.modelData.hasChildren) || menuRow.checked)
                                anchors { right: parent.right; rightMargin: root.rowInset; verticalCenter: parent.verticalCenter }
                                theme: root.theme
                                name: menuRow.modelData.hasChildren ? "chevron-right" : "check"
                                sizeRole: "small"
                                role: !menuRow.enabled ? "disabled" : menuRow.modelData.hasChildren ? "secondary" : "accent"
                            }

                            MouseArea {
                                id: rowPointer
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !menuRow.separator && menuRow.enabled
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (!root.clickAllowed()) return
                                    if (menuRow.modelData.hasChildren)
                                        root.enterSubmenu(menuRow.modelData, menuRow.rowText)
                                    else
                                        root.trigger(menuRow.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
