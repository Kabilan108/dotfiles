import QtQuick
import Quickshell
import "../../../ui" as Ui

// Hosted menu content: a view over the launcher service. The result list is
// keyed by row key: a narrowed or reordered result set moves, inserts, and
// removes delegates, and a surviving delegate reads its row from a key map.
// The model holds plain strings, never row objects, because Quickshell 0.3.1
// ScriptModel rebinds object rows by position after a removal.
FocusScope {
    id: root

    readonly property bool hostedMenu: true
    required property var context
    required property var service

    readonly property var theme: context.theme
    readonly property real unit: theme.metrics.spaceUnit
    readonly property real padding: unit * 3
    readonly property real rowHeight: theme.metrics.rowHeight + unit
    readonly property real maxVisibleRows: 8.5
    readonly property bool clipboardView: service.clipboardActive
    // Short single-purpose lists get a narrower frame so it doesn't read as
    // mostly empty space.
    readonly property bool compactView: viewName === "power" || viewName === "profiles"
    // 560, 256, and 420 px at the default 4 px unit.
    readonly property real standardWidth: unit * 140
    readonly property real connectionsWidth: unit * 120
    readonly property real compactWidth: unit * 64
    readonly property real clipboardListWidth: unit * 105
    readonly property real clipboardWidth: padding * 2 + clipboardListWidth + unit * 2 + theme.metrics.panelWidth
    readonly property bool clipboardProblem: clipboardView
        && (service.clipboardStatus === "error"
            || (service.clipboardStatus === "degraded" && service.clipboardError !== ""))
    readonly property var selectedRow: service.selectedRow
    readonly property string selectedKey: selectedRow ? String(selectedRow.key) : ""
    readonly property var keyedRows: {
        var rows = service.rows
        var keys = []
        var byKey = {}
        for (var index = 0; index < rows.length; index++) {
            keys.push(String(rows[index].key))
            byKey[rows[index].key] = rows[index]
        }
        return { keys: keys, rows: byKey }
    }
    readonly property string bannerText: service.actionError !== "" ? service.actionError
        : !clipboardProblem ? ""
        : service.clipboardError !== "" ? service.clipboardError : "Clipboard history is unavailable"
    readonly property bool bannerDanger: service.actionError !== "" || service.clipboardStatus === "error"
    readonly property var previewData: clipboardView && selectedRow && selectedRow.preview ? selectedRow.preview : null
    readonly property bool imagesOnly: clipboardView && service.clipboardImagesOnly
    readonly property var modeIcons: ({
        combi: "apps", windows: "window", power: "power", profiles: "layers", clipboard: "clipboard",
        remmina: "window", files: "folder"
    })
    readonly property var placeholders: ({
        combi: "Search applications", windows: "Switch to a window", power: "Power",
        profiles: "Switch profile", clipboard: "Search clipboard history",
        remmina: "Search connections, groups, or servers", files: "Search files"
    })
    readonly property string viewName: service.prefixProvider !== "" ? service.prefixProvider : service.mode
    // Rows name their provider only when several can appear together.
    readonly property bool mixedProviders: service.providerIds.length > 1

    implicitWidth: clipboardView ? clipboardWidth : viewName === "remmina" ? connectionsWidth
        : compactView ? compactWidth : standardWidth
    implicitHeight: frame.implicitHeight
    visible: false

    function open(payloadJson) {
        service.open(payloadJson)
        field.text = service.query
        field.forceActiveFocus()
        // A pointer resting where the menu appears must not pick a row.
        pointerGate.reset()
        list.positionViewAtBeginning()
    }

    function close() {
        service.close()
    }

    // A toggle that asks for another mode switches to it instead of closing.
    function keepOpenOnToggle(payloadJson) {
        return service.opened && service.requestedMode(payloadJson) !== service.mode
    }

    function dismiss() {
        context.actions.surfaceClose(service.pluginId)
    }

    function activateSelected() {
        service.activate(service.selectedIndex, service.selectedAction ? service.selectedAction.id : "")
    }

    function handleKey(event) {
        var control = (event.modifiers & Qt.ControlModifier) !== 0
        var shift = (event.modifiers & Qt.ShiftModifier) !== 0
        if (event.key === Qt.Key_Up || (control && event.key === Qt.Key_K))
            service.move(-1)
        else if (event.key === Qt.Key_Down || (control && event.key === Qt.Key_J))
            service.move(1)
        else if (event.key === Qt.Key_PageUp)
            service.move(-service.pageSize)
        else if (event.key === Qt.Key_PageDown)
            service.move(service.pageSize)
        else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && shift))
            service.cycleAction(-1)
        else if (event.key === Qt.Key_Tab)
            service.cycleAction(1)
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && control)
            service.cycleAction(1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            activateSelected()
        else if (control && event.key === Qt.Key_D) {
            if (selectedRow && selectedRow.provider === "clipboard")
                service.activate(service.selectedIndex, "remove")
        } else if (control && event.key === Qt.Key_I) {
            service.toggleClipboardImages()
            list.positionViewAtBeginning()
        } else if (event.key === Qt.Key_Escape)
            dismiss()
        else
            return
        event.accepted = true
    }

    function escaped(text) {
        return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    // StyledText with the matched characters in the accent color.
    function highlighted(text, positions) {
        var value = String(text || "")
        if (!positions || positions.length === 0)
            return escaped(value)
        var marked = {}
        for (var p = 0; p < positions.length; p++)
            marked[positions[p]] = true
        var open = "<font color=\"" + String(theme.semantic.accent.primary) + "\"><b>"
        var result = ""
        var run = ""
        var inRun = false
        for (var index = 0; index < value.length; index++) {
            var hit = marked[index] === true
            if (hit !== inRun) {
                result += inRun ? open + escaped(run) + "</b></font>" : escaped(run)
                run = ""
                inRun = hit
            }
            run += value.charAt(index)
        }
        return result + (inRun ? open + escaped(run) + "</b></font>" : escaped(run))
    }

    function fileUrl(path) {
        var value = String(path || "")
        return value.charAt(0) === "/" ? "file://" + value.split("/").map(encodeURIComponent).join("/") : ""
    }

    function rowIcon(row) {
        if (!row)
            return ""
        return row.provider === "windows" ? service.iconForAppId(row.appId) : String(row.icon || "")
    }

    // "shell:<name>" rows show a glyph from Stillsuit's icon pack; app and
    // window rows keep the icon theme.
    function shellIconName(row) {
        var icon = row ? String(row.icon || "") : ""
        return icon.indexOf("shell:") === 0 ? icon.slice(6) : ""
    }

    function emptyText() {
        if (service.busy)
            return service.connectionsBusy ? "Loading connections…"
                : service.filesBusy ? "Searching files…" : "Calculating…"
        if (service.prefixProvider === "files" && service.query.slice(1).trim() === "")
            return "Search file names under " + service.searchRoot + ", or a folder: downloads/*.pdf"
        if (clipboardView && service.query.replace(/^:/, "").trim() === "")
            return imagesOnly ? "No images in clipboard history" : "Clipboard history is empty"
        if (viewName === "remmina" && service.query.replace(/^>/, "").trim() === "")
            return "No saved Remmina connections"
        return "No results"
    }

    Connections {
        target: root.service
        function onSelectedIndexChanged() { Qt.callLater(root.revealSelection) }
        function onRowsChanged() { Qt.callLater(root.revealSelection) }
    }

    function revealSelection() {
        if (service.opened && service.selectedIndex >= 0 && service.selectedIndex < list.count)
            list.positionViewAtIndex(service.selectedIndex, ListView.Contain)
    }

    Ui.PointerMoveGate {
        id: pointerGate
        referenceItem: root
    }

    Ui.ShellSurface {
        id: frame
        anchors.fill: parent
        theme: root.theme
        kind: "panel"
        implicitHeight: content.implicitHeight + root.padding * 2

        Column {
            id: content
            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            spacing: root.unit * 2

            Item {
                width: parent.width
                height: field.implicitHeight

                Ui.ShellTextField {
                    id: field
                    objectName: "launcher-field"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    focus: true
                    theme: root.theme
                    iconName: root.imagesOnly ? "image" : root.modeIcons[root.viewName] || "search"
                    iconRole: "accent"
                    placeholderText: root.imagesOnly ? "Search clipboard images"
                        : root.placeholders[root.viewName] || "Search"
                    accessibleName: "Launcher search"
                    onTextChanged: root.service.setQuery(text)
                    onKeyPressed: event => root.handleKey(event)
                }

                Ui.ShellBusyIndicator {
                    anchors.right: field.right
                    anchors.rightMargin: root.unit * 2
                    anchors.verticalCenter: field.verticalCenter
                    visible: root.service.busy
                    theme: root.theme
                    sizeRole: "small"
                }
            }

            Item {
                id: statusRow
                objectName: "launcher-status-row"
                visible: root.bannerText !== ""
                width: parent.width
                height: visible ? root.rowHeight : 0

                Rectangle {
                    anchors.fill: parent
                    radius: root.theme.metrics.radiusMedium
                    color: root.bannerDanger ? root.theme.semantic.surface.danger : root.theme.component.panel.section
                    border.width: 1
                    border.color: root.bannerDanger ? root.theme.semantic.status.danger : root.theme.semantic.status.warning
                }

                Ui.ShellIcon {
                    id: statusIcon
                    anchors.left: parent.left
                    anchors.leftMargin: root.unit * 3
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root.theme
                    name: root.bannerDanger ? "danger" : "warning"
                    role: root.bannerDanger ? "danger" : "warning"
                    sizeRole: "small"
                }

                Ui.ShellText {
                    objectName: "launcher-status-text"
                    anchors.left: statusIcon.right
                    anchors.leftMargin: root.unit * 2
                    anchors.right: parent.right
                    anchors.rightMargin: root.unit * 3
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root.theme
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                    text: root.bannerText
                    role: root.bannerDanger ? "danger" : "warning"
                }
            }

            Row {
                id: body
                width: parent.width
                spacing: root.unit * 2
                readonly property real fullHeight: root.rowHeight * root.maxVisibleRows
                readonly property real listHeight: root.service.rows.length === 0 ? root.rowHeight * 2
                    : Math.min(root.service.rows.length, root.maxVisibleRows) * root.rowHeight
                height: root.clipboardView ? fullHeight : listHeight

                Item {
                    width: root.clipboardView ? root.clipboardListWidth : body.width
                    height: body.height

                    ListView {
                        id: list
                        objectName: "launcher-results"
                        anchors.fill: parent
                        clip: true
                        reuseItems: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        model: ScriptModel {
                            values: root.keyedRows.keys
                        }
                        delegate: resultRow
                    }

                    Item {
                        anchors.fill: parent
                        visible: root.service.rows.length === 0

                        Ui.ShellText {
                            objectName: "launcher-empty"
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - root.unit * 4)
                            elide: Text.ElideMiddle
                            theme: root.theme
                            text: root.emptyText()
                            role: "muted"
                        }
                    }
                }

                Rectangle {
                    id: preview
                    objectName: "launcher-preview"
                    visible: root.clipboardView
                    width: root.clipboardView ? body.width - root.clipboardListWidth - body.spacing : 0
                    height: body.height
                    radius: root.theme.metrics.radiusMedium
                    color: root.theme.component.panel.section
                    border.width: 1
                    border.color: root.theme.component.panel.border
                    clip: true

                    Ui.ShellScrollArea {
                        id: textPreview
                        anchors.fill: parent
                        anchors.margins: root.unit * 3
                        theme: root.theme
                        maximumHeight: height
                        visible: !!root.previewData && root.previewData.kind === "text"
                        contentHeight: previewText.implicitHeight

                        Ui.ShellText {
                            id: previewText
                            width: textPreview.width
                            theme: root.theme
                            monospace: true
                            sizeRole: "caption"
                            role: "secondary"
                            wrapMode: Text.WrapAnywhere
                            textFormat: Text.PlainText
                            text: textPreview.visible ? String(root.previewData.text || "") : ""
                        }
                    }

                    Image {
                        id: imagePreview
                        objectName: "launcher-image-preview"
                        anchors.fill: parent
                        anchors.margins: root.unit * 3
                        visible: !!root.previewData && root.previewData.kind === "image"
                        source: visible ? root.fileUrl(root.previewData.path) : ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: Math.ceil(width)
                        sourceSize.height: Math.ceil(height)
                    }

                    Ui.ShellText {
                        anchors.centerIn: parent
                        visible: !root.previewData
                            || (imagePreview.visible && imagePreview.status === Image.Error)
                        theme: root.theme
                        text: root.previewData ? "Image unavailable" : "Nothing selected"
                        role: "muted"
                        sizeRole: "caption"
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.semantic.outline.subtle
            }

            Row {
                id: hints
                objectName: "launcher-hints"
                width: parent.width
                spacing: root.unit * 3
                readonly property var actions: root.selectedRow && root.selectedRow.actions ? root.selectedRow.actions : []
                readonly property int armed: root.service.actionIndex
                readonly property var nextAction: actions.length > 1 ? actions[(armed + 1) % actions.length] : null
                readonly property bool removable: !!root.selectedRow && root.selectedRow.provider === "clipboard"

                Hint {
                    visible: hints.actions.length > 0
                    keys: "↵"
                    label: root.service.selectedAction ? root.service.selectedAction.label : ""
                    armed: true
                }
                Hint {
                    visible: hints.nextAction !== null && !(hints.removable && hints.nextAction.id === "remove")
                    keys: "Tab"
                    label: hints.nextAction ? hints.nextAction.label : ""
                }
                Hint {
                    visible: hints.removable
                    keys: "Ctrl+D"
                    label: "Delete"
                }
                Hint {
                    visible: root.clipboardView
                    keys: "Ctrl+I"
                    label: root.imagesOnly ? "All items" : "Images only"
                }
                Hint {
                    keys: "Esc"
                    label: "Close"
                }
            }
        }
    }

    component Hint: Row {
        id: hint
        property string keys: ""
        property string label: ""
        property bool armed: false
        spacing: root.unit

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: keyText.implicitWidth + root.unit * 2
            height: keyText.implicitHeight + 2
            radius: root.theme.metrics.radiusSmall
            color: "transparent"
            border.width: 1
            border.color: hint.armed ? root.theme.semantic.accent.primary : root.theme.semantic.outline.default

            Ui.ShellText {
                id: keyText
                anchors.centerIn: parent
                theme: root.theme
                text: hint.keys
                monospace: true
                sizeRole: "caption"
                role: hint.armed ? "accent" : "primary"
            }
        }

        Ui.ShellText {
            anchors.verticalCenter: parent.verticalCenter
            theme: root.theme
            text: hint.label
            sizeRole: "caption"
            role: hint.armed ? "primary" : "muted"
        }
    }

    Component {
        id: resultRow

        Item {
            id: rowItem
            objectName: "launcher-row"
            required property int index
            required property string modelData
            readonly property var row: root.keyedRows.rows[modelData] || null
            readonly property bool selected: modelData === root.selectedKey
            readonly property bool current: !!row && row.current === true
            readonly property string shellIcon: root.shellIconName(row)
            width: ListView.view ? ListView.view.width : 0
            height: root.rowHeight

            Rectangle {
                anchors.fill: parent
                radius: root.theme.metrics.radiusMedium
                color: rowItem.selected ? root.theme.component.panel.rowSelected : "transparent"
            }

            Item {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: root.unit * 2
                anchors.verticalCenter: parent.verticalCenter
                width: appIcon.implicitWidth
                height: appIcon.implicitHeight

                Ui.ShellAppIcon {
                    id: appIcon
                    objectName: "launcher-row-app-icon"
                    anchors.fill: parent
                    visible: rowItem.shellIcon === ""
                    theme: root.theme
                    icon: visible ? root.rowIcon(rowItem.row) : ""
                    fallbackLabel: rowItem.row ? String(rowItem.row.text || "") : ""
                    sizeRole: "large"
                    themeCheckAllowed: Window.active
                }

                Ui.ShellIcon {
                    objectName: "launcher-row-shell-icon"
                    anchors.centerIn: parent
                    visible: rowItem.shellIcon !== ""
                    theme: root.theme
                    name: visible ? rowItem.shellIcon : "circle"
                    role: rowItem.current ? "accent" : "secondary"
                }
            }

            Column {
                anchors.left: icon.right
                anchors.leftMargin: root.unit * 3
                anchors.right: trailing.left
                anchors.rightMargin: root.unit * 2
                anchors.verticalCenter: parent.verticalCenter

                Ui.ShellText {
                    width: parent.width
                    theme: root.theme
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: rowItem.row ? root.highlighted(rowItem.row.text, rowItem.row.positions) : ""
                    role: rowItem.current ? "accent" : "primary"
                    sizeRole: "label"
                }

                Ui.ShellText {
                    width: parent.width
                    visible: text !== ""
                    theme: root.theme
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    textFormat: Text.PlainText
                    text: rowItem.row ? String(rowItem.row.subtext || "") : ""
                    role: "muted"
                    sizeRole: "caption"
                }
            }

            Ui.ShellText {
                id: trailing
                anchors.right: parent.right
                anchors.rightMargin: root.unit * 3
                anchors.verticalCenter: parent.verticalCenter
                theme: root.theme
                monospace: true
                sizeRole: "caption"
                text: !rowItem.row ? "" : rowItem.current ? "current"
                    : root.mixedProviders ? String(rowItem.row.provider || "") : ""
                role: rowItem.current ? "accent" : "muted"
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                onPositionChanged: mouse => {
                    if (pointerGate.moved(rowItem, mouse))
                        root.service.select(rowItem.index)
                }
                onClicked: root.service.activate(rowItem.index, "")
            }
        }
    }
}
