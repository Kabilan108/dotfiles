import QtQuick
import QtQuick.Layouts
import Quickshell

Scope {
    id: root

    required property var context
    required property var screen

    property var service: context.services.get("stillsuit.notifications")
    property string outputId: String(screen.name || "")
    readonly property var rows: service ? service.centerRows() : []

    function open(payloadJson) {
        return service ? service.openCenter(outputId) : "error"
    }

    function close() {
        return service ? service.closeCenter(outputId) : "error"
    }

    function toggle(payloadJson) {
        return service ? service.toggleCenter(outputId) : "error"
    }

    function relativeTime(timestamp) {
        var minutes = Math.floor(Math.max(0, Date.now() - Number(timestamp || 0)) / 60000)
        if (minutes < 1) return "now"
        if (minutes < 60) return String(minutes) + "m"
        var hours = Math.floor(minutes / 60)
        return hours < 24 ? String(hours) + "h" : String(Math.floor(hours / 24)) + "d"
    }

    PanelWindow {
        screen: root.screen
        visible: root.service && root.service.centerOutputId === root.outputId
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        focusable: true
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: root.service.closeCenter(root.outputId)
        }

        Rectangle {
            id: panel
            anchors {
                top: parent.top
                right: parent.right
                topMargin: root.context.theme.geometry.barHeight + root.context.theme.geometry.panelGap
                rightMargin: root.context.theme.geometry.panelGap
            }
            width: 400
            implicitHeight: Math.min(panelLayout.implicitHeight + 28, parent.height - anchors.topMargin - root.context.theme.geometry.panelGap)
            radius: root.context.theme.geometry.radius
            color: root.context.theme.colors.surface.panel
            border.width: 1
            border.color: root.context.theme.colors.border.normal

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
                    margins: 14
                }
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Notifications"
                        color: root.context.theme.colors.text.primary
                        font.family: root.context.theme.typography.family
                        font.pixelSize: root.context.theme.typography.baseSize * 1.15
                        font.bold: true
                    }

                    Text {
                        text: String(root.rows.length) + " recent"
                        color: root.context.theme.colors.text.secondary
                        font.family: root.context.theme.typography.monospaceFamily
                        font.pixelSize: root.context.theme.typography.baseSize * 0.8
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: dndLabel.implicitWidth + 18
                        Layout.preferredHeight: dndLabel.implicitHeight + 10
                        radius: root.context.theme.geometry.radius * 0.6
                        color: root.service && root.service.doNotDisturb
                            ? root.context.theme.controls.active.fill : root.context.theme.controls.normal.fill
                        border.width: 1
                        border.color: root.context.theme.controls.normal.border

                        Text {
                            id: dndLabel
                            anchors.centerIn: parent
                            text: "DND"
                            color: root.context.theme.controls.normal.text
                            font.family: root.context.theme.typography.family
                            font.pixelSize: root.context.theme.typography.baseSize * 0.8
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.toggleDnd()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: clearLabel.implicitWidth + 18
                        Layout.preferredHeight: clearLabel.implicitHeight + 10
                        radius: root.context.theme.geometry.radius * 0.6
                        color: root.context.theme.controls.normal.fill
                        border.width: 1
                        border.color: root.context.theme.colors.status.danger
                        visible: root.rows.length > 0

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "clear all"
                            color: root.context.theme.colors.status.danger
                            font.family: root.context.theme.typography.family
                            font.pixelSize: root.context.theme.typography.baseSize * 0.8
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.dismissAll()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: root.context.theme.geometry.radius * 0.6
                    color: root.context.theme.controls.active.fill
                    visible: root.service && root.service.doNotDisturb

                    Text {
                        anchors.centerIn: parent
                        text: "notifications silenced; retained alerts remain in this center"
                        color: root.context.theme.colors.text.secondary
                        font.family: root.context.theme.typography.family
                        font.pixelSize: root.context.theme.typography.baseSize * 0.85
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(centerColumn.implicitHeight, 420)
                    contentHeight: centerColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: centerColumn
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: root.rows

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

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 24
                            Layout.bottomMargin: 24
                            text: "No notifications"
                            visible: root.rows.length === 0
                            color: root.context.theme.colors.text.tertiary
                            font.family: root.context.theme.typography.family
                            font.pixelSize: root.context.theme.typography.baseSize
                        }
                    }
                }
            }
        }
    }
}
