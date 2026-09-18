import QtQuick
import Stillsuit.Ui as Ui

Item {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property var theme: context.theme
    readonly property var items: service ? service.items : []
    readonly property bool panelOpen: context.panels && context.panels.selectedId === "stillsuit.tray"
        && context.panels.selectedOutputId === outputId
    readonly property bool selected: panelOpen
    readonly property int slotExtent: Math.max(22, theme.metrics.barHeight - 6)
    readonly property int iconExtent: theme.metrics.iconSmall
    property string hoveredTooltip: ""
    readonly property string tooltipText: hoveredTooltip
    readonly property string accessibleName: items.length === 0
        ? "System tray, empty" : "System tray, " + items.length + " items"

    visible: items.length > 0
    implicitWidth: visible ? iconRow.implicitWidth : 0
    implicitHeight: theme.metrics.barHeight

    function openMenu(item) {
        context.actions.surfaceOpen("stillsuit.tray",
            JSON.stringify({ outputId: root.outputId, itemId: String(item.id || "") }))
    }

    function primaryAction(item) {
        if (item.onlyMenu === true || (item.hasMenu && typeof item.activate !== "function")) {
            openMenu(item)
            return
        }
        service.activate(item)
    }

    Row {
        id: iconRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: root.items

            Item {
                id: entry
                required property var modelData
                readonly property string iconSource: String(modelData.icon || "")
                readonly property bool attention: root.service.statusOf(modelData) === "attention"
                readonly property bool hovered: pointer.containsMouse

                width: root.slotExtent
                height: root.slotExtent
                Accessible.role: Accessible.Button
                Accessible.name: root.service.tooltipFor(modelData)

                Rectangle {
                    anchors.fill: parent
                    radius: root.theme.metrics.radiusSmall
                    color: pointer.pressed ? root.theme.semantic.surface.pressed
                        : entry.hovered ? root.theme.component.bar.clusterHover : "transparent"
                }

                Image {
                    id: trayImage
                    anchors.centerIn: parent
                    width: root.iconExtent
                    height: root.iconExtent
                    visible: entry.iconSource !== "" && status === Image.Ready
                    source: entry.iconSource
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                    sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                    smooth: true
                    mipmap: true
                }

                Ui.ShellIcon {
                    anchors.centerIn: parent
                    visible: !trayImage.visible
                    theme: root.theme
                    name: String(entry.modelData.iconName || "circle")
                    sizeRole: "small"
                    role: entry.attention ? "warning" : "secondary"
                }

                Rectangle {
                    visible: entry.attention
                    width: root.theme.metrics.spaceUnit + 1
                    height: width
                    radius: width / 2
                    anchors { top: parent.top; right: parent.right; margins: 3 }
                    color: root.theme.semantic.status.warning
                }

                MouseArea {
                    id: pointer
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoveredTooltip = root.service.tooltipFor(entry.modelData)
                    onExited: if (root.hoveredTooltip === root.service.tooltipFor(entry.modelData)) root.hoveredTooltip = ""
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton)
                            root.openMenu(entry.modelData)
                        else if (mouse.button === Qt.MiddleButton)
                            root.service.secondaryActivate(entry.modelData)
                        else
                            root.primaryAction(entry.modelData)
                    }
                    onWheel: function(wheel) {
                        var horizontal = wheel.angleDelta.x !== 0 && wheel.angleDelta.y === 0
                        root.service.scroll(entry.modelData,
                            horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal)
                    }
                }
            }
        }
    }
}
