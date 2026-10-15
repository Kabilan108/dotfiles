pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Stillsuit.Ui as Ui

Item {
    id: root
    required property var theme
    required property var service
    required property Item target
    property bool showing: false

    Loader {
        active: root.showing && root.visible
        sourceComponent: Component {
            PopupWindow {
                visible: true
                color: "transparent"
                implicitWidth: rows.implicitWidth + root.theme.metrics.spaceUnit * 4
                implicitHeight: rows.implicitHeight + root.theme.metrics.spaceUnit * 4
                mask: Region {}
                anchor.item: root.target
                anchor.rect.y: root.target.height + root.theme.metrics.spaceUnit

                Ui.ShellSurface {
                    anchors.fill: parent
                    theme: root.theme

                    ColumnLayout {
                        id: rows
                        anchors { fill: parent; margins: root.theme.metrics.spaceUnit * 2 }
                        spacing: root.theme.metrics.spaceUnit * 2

                        RowLayout {
                            spacing: root.theme.metrics.spaceUnit * 2
                            HostIcon {
                                theme: root.theme
                                desktop: root.service.localSnapshot && root.service.localSnapshot.deviceKind === "desktop"
                                Accessible.name: desktop ? "This PC" : "Laptop"
                            }
                            Ui.ShellText {
                                theme: root.theme
                                text: root.service.headline(false)
                                sizeRole: "caption"
                                monospace: true
                            }
                        }
                        RowLayout {
                            visible: root.service.remoteAvailable
                            spacing: root.theme.metrics.spaceUnit * 2
                            HostIcon {
                                theme: root.theme
                                desktop: true
                                server: true
                                Accessible.name: "Server"
                            }
                            Ui.ShellText {
                                theme: root.theme
                                text: root.service.headline(true)
                                sizeRole: "caption"
                                monospace: true
                                role: root.service.remoteError || root.service.remoteStale ? "warning" : "primary"
                            }
                        }
                    }
                }
            }
        }
    }
}
