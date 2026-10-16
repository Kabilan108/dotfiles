import QtQuick
import QtQuick.Layouts
import Stillsuit.Ui as Ui

Item {
    id: root
    required property var context
    required property var service
    required property var screen
    required property string outputId
    readonly property bool hostedPanel: true
    readonly property var theme: context.theme
    property bool opened: false
    implicitWidth: theme.metrics.panelWidth
    implicitHeight: content.implicitHeight + theme.metrics.panelPadding * 2
    visible: false

    function open(payloadJson) {
        opened = true
        service.setPanelOpen(outputId, true)
    }

    function close() {
        opened = false
        service.setPanelOpen(outputId, false)
    }

    Component.onDestruction: {
        if (opened && service && typeof service.setPanelOpen === "function")
            service.setPanelOpen(outputId, false)
    }

    Ui.ShellSurface {
        anchors.fill: parent
        theme: root.theme
        kind: "panel"
        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }
        ColumnLayout {
            id: content
            anchors { fill: parent; margins: root.theme.metrics.panelPadding }
            spacing: root.theme.metrics.spaceUnit * 3

            Ui.ShellPanelHeader {
                Layout.fillWidth: true
                theme: root.theme
                title: "Performance"
                Ui.ShellButton {
                    theme: root.theme
                    label: ""
                    iconName: "refresh"
                    compact: true
                    ghost: true
                    busy: root.service.localRefreshing || root.service.remoteRefreshing
                    accessibleName: "Refresh performance for both machines"
                    onClicked: root.service.refreshDetails()
                }
            }

            Ui.ShellScrollArea {
                Layout.fillWidth: true
                theme: root.theme
                maximumHeight: Math.min(root.theme.metrics.spaceUnit * 180,
                    Math.max(root.theme.metrics.spaceUnit * 40,
                        root.screen.height - root.theme.metrics.barHeight - root.theme.metrics.panelPadding * 2
                        - root.theme.metrics.spaceUnit * 24))
                contentHeight: hosts.implicitHeight

                ColumnLayout {
                    id: hosts
                    width: parent.width
                    spacing: root.theme.metrics.spaceUnit * 3.5

                    HostCard {
                        Layout.fillWidth: true
                        theme: root.theme
                        service: root.service
                        hostName: root.service.localName
                        remote: false
                        snapshot: root.service.localSnapshot
                        refreshing: root.service.localRefreshing
                        errorMessage: root.service.localError
                        updatedAt: root.service.localUpdatedAt
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.service.remoteAvailable
                        implicitHeight: 1
                        color: root.theme.semantic.outline.subtle
                    }
                    HostCard {
                        Layout.fillWidth: true
                        visible: root.service.remoteAvailable
                        theme: root.theme
                        service: root.service
                        hostName: root.service.remoteName
                        remote: true
                        snapshot: root.service.remoteSnapshot
                        refreshing: root.service.remoteRefreshing
                        errorMessage: root.service.remoteError
                        updatedAt: root.service.remoteUpdatedAt
                    }
                }
            }

        }
    }
}
