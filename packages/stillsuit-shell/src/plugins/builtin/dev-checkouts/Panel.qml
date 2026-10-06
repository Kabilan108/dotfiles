pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Stillsuit.Ui as Ui

Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: root.context.theme.metrics.panelWidth
    implicitHeight: content.implicitHeight + root.context.theme.metrics.panelPadding * 2
    visible: false

    required property var context
    required property var service
    required property var screen
    required property string outputId
    property bool opened: false
    property bool showIdle: false

    readonly property var theme: context.theme
    readonly property int unit: theme.metrics.spaceUnit

    function open(payloadJson) {
        opened = true
        service.refresh()
    }

    function close() {
        opened = false
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
            spacing: root.unit * 3

            Ui.ShellPanelHeader {
                Layout.fillWidth: true
                theme: root.theme
                title: "Dev checkouts"
                subtitle: root.service.loaded
                    ? root.service.runningCount + " running · " + root.service.checkouts.length + " on sietch"
                    : "sietch"

                Ui.ShellButton {
                    theme: root.theme
                    label: ""
                    iconName: "refresh"
                    compact: true
                    ghost: true
                    busy: root.service.refreshing
                    accessibleName: "Refresh dev checkouts"
                    onClicked: root.service.refresh()
                }
            }

            Ui.ShellStatus {
                Layout.fillWidth: true
                visible: root.service.lastError !== ""
                theme: root.theme
                status: "danger"
                iconName: "warning"
                label: root.service.lastError
                wrap: true
                maximumLines: 3
            }

            Ui.ShellStatus {
                Layout.fillWidth: true
                visible: root.service.actionError !== ""
                theme: root.theme
                status: "danger"
                iconName: "warning"
                label: root.service.actionError
                wrap: true
                maximumLines: 3
            }

            Ui.ShellStateView {
                Layout.fillWidth: true
                visible: !root.service.available
                theme: root.theme
                mode: "error"
                title: "Status helper unavailable"
                message: "Set helperPath for stillsuit.dev-checkouts."
                iconName: "warning"
            }

            Ui.ShellStateView {
                Layout.fillWidth: true
                visible: root.service.available && !root.service.loaded && root.service.lastError === ""
                theme: root.theme
                mode: "loading"
                title: "Reading checkouts"
            }

            Ui.ShellScrollArea {
                Layout.fillWidth: true
                visible: root.service.loaded
                theme: root.theme
                maximumHeight: 560
                contentHeight: checkoutList.implicitHeight

                ColumnLayout {
                    id: checkoutList
                    width: parent.width
                    spacing: root.unit * 2

                    Ui.ShellEmptyRow {
                        Layout.fillWidth: true
                        visible: root.service.runningCount === 0
                        theme: root.theme
                        iconName: "pause"
                        text: "No checkouts running"
                    }

                    Repeater {
                        model: root.service.running

                        delegate: RunningCheckout {
                            required property var modelData
                            Layout.fillWidth: true
                            checkout: modelData
                        }
                    }

                    Ui.ShellRow {
                        Layout.fillWidth: true
                        visible: root.service.idle.length > 0
                        theme: root.theme
                        iconName: root.showIdle ? "expand-less" : "expand-more"
                        label: "Stopped"
                        trailingText: String(root.service.idle.length)
                        onClicked: root.showIdle = !root.showIdle
                    }

                    Repeater {
                        model: root.showIdle ? root.service.idle : []

                        delegate: Ui.ShellRow {
                            required property var modelData
                            Layout.fillWidth: true
                            theme: root.theme
                            iconName: modelData.issue ? "warning" : "pause"
                            danger: Boolean(modelData.issue)
                            label: root.service.title(modelData)
                            description: modelData.issue || root.service.subtitle(modelData)
                            trailingText: root.service.canResume(modelData)
                                ? "" : String(modelData.state || "")
                            interactive: false

                            Ui.ShellButton {
                                visible: root.service.canResume(modelData)
                                theme: root.theme
                                compact: true
                                ghost: true
                                iconName: "play"
                                label: "Resume"
                                busy: root.service.pending(modelData, "resume")
                                enabled: !root.service.acting || busy
                                accessibleName: "Resume " + root.service.title(modelData)
                                onClicked: root.service.resume(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    component RunningCheckout: Ui.ShellSurface {
        id: card
        required property var checkout
        readonly property var links: root.service.liveLinks(checkout)

        theme: root.theme
        kind: "raised"
        implicitHeight: cardContent.implicitHeight + root.unit * 4

        ColumnLayout {
            id: cardContent
            anchors { fill: parent; margins: root.unit * 2 }
            spacing: root.unit * 2

            RowLayout {
                Layout.fillWidth: true
                spacing: root.unit * 2

                Ui.ShellIcon {
                    theme: root.theme
                    name: card.checkout.issue ? "warning" : "play"
                    role: card.checkout.issue ? "warning" : "success"
                    sizeRole: "small"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Ui.ShellText {
                        Layout.fillWidth: true
                        theme: root.theme
                        text: root.service.title(card.checkout)
                        elide: Text.ElideRight
                    }

                    Ui.ShellText {
                        Layout.fillWidth: true
                        theme: root.theme
                        text: card.checkout.issue || root.service.subtitle(card.checkout)
                        role: card.checkout.issue ? "warning" : "muted"
                        sizeRole: "caption"
                        monospace: !card.checkout.issue
                        elide: Text.ElideMiddle
                    }
                }

                Ui.ShellButton {
                    theme: root.theme
                    compact: true
                    ghost: true
                    iconName: "pause"
                    label: ""
                    busy: root.service.pending(card.checkout, "pause")
                    enabled: !root.service.acting || busy
                    accessibleName: "Pause " + root.service.title(card.checkout)
                    onClicked: root.service.pause(card.checkout)
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: root.unit

                Repeater {
                    model: card.links

                    delegate: Ui.ShellButton {
                        required property var modelData
                        theme: root.theme
                        compact: true
                        ghost: !root.service.isPrimary(modelData)
                        label: root.service.linkLabel(modelData)
                        accessibleName: "Open " + label + " for " + root.service.title(card.checkout)
                        onClicked: root.service.openLink(modelData)
                    }
                }
            }
        }
    }
}
