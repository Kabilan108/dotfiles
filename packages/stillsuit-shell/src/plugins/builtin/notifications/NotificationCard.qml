import QtQuick
import QtQuick.Layouts
import "../../../ui" as Ui

Ui.ShellSurface {
    id: root

    required property var context
    required property var service
    required property var snapshot
    property bool inline: false
    property string timeText: ""

    readonly property var theme: context.theme
    readonly property var actions: Array.isArray(snapshot.actions) ? snapshot.actions : []
    readonly property string actionState: service ? service.actionState(snapshot.key) : "expired"
    readonly property string stateRole: service ? service.viewState(snapshot) : "info"
    readonly property color stateColor: theme.component.notification[stateRole]

    kind: "notification"
    implicitWidth: theme.metrics.panelWidth - theme.metrics.panelPadding * 2
    implicitHeight: contentColumn.implicitHeight + 24

    function cleanBody(value) {
        return String(value || "").replace(/<img[^>]*>/gi, "").trim()
    }

    function iconForState(state) {
        if (state === "success") return "success"
        if (state === "warning") return "warning"
        if (state === "danger") return "danger"
        if (state === "info") return "info"
        return "notifications"
    }

    function withAlpha(value, alpha) {
        var parsed = Qt.color(value)
        return Qt.rgba(parsed.r, parsed.g, parsed.b, Math.max(0, Math.min(1, alpha)))
    }

    ColumnLayout {
        id: contentColumn

        anchors {
            fill: parent
            margins: 12
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignTop
                radius: root.theme.metrics.radiusSmall
                color: root.withAlpha(root.stateColor, 0.16)

                Ui.ShellIcon {
                    anchors.centerIn: parent
                    theme: root.theme
                    name: root.iconForState(root.stateRole)
                    color: root.stateColor
                    accessibleName: root.stateRole + " notification"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Ui.ShellText {
                    Layout.fillWidth: true
                    theme: root.theme
                    text: root.snapshot.appName || "Notification"
                    sizeRole: "caption"
                    color: root.stateColor
                    elide: Text.ElideRight
                }

                Ui.ShellText {
                    Layout.fillWidth: true
                    theme: root.theme
                    text: root.snapshot.summary || "Notification"
                    sizeRole: "label"
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Ui.ShellText {
                visible: root.timeText !== ""
                theme: root.theme
                text: root.timeText
                sizeRole: "caption"
                role: "muted"
                monospace: true
            }

            Ui.ShellButton {
                theme: root.theme
                label: ""
                iconName: root.inline ? "delete" : "close"
                compact: true
                ghost: true
                destructive: root.inline
                accessibleName: root.inline ? "Delete notification" : "Dismiss notification"
                onClicked: {
                    if (root.inline)
                        root.service.deleteHistory(root.snapshot.key)
                    else
                        root.service.dismiss(root.snapshot.key)
                }
            }
        }

        Ui.ShellText {
            Layout.fillWidth: true
            theme: root.theme
            text: root.cleanBody(root.snapshot.body)
            visible: text !== ""
            role: "secondary"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: root.inline ? 5 : 3
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.actions.length > 0 && root.actionState === "available"

            Item { Layout.fillWidth: true }

            Repeater {
                model: root.actions

                Ui.ShellButton {
                    required property var modelData

                    theme: root.theme
                    label: modelData.text || modelData.identifier
                    accessibleName: label
                    compact: true
                    active: modelData.identifier === "default"
                    onClicked: root.service.invokeAction(root.snapshot.key, modelData.identifier)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.actions.length > 0 && root.actionState === "expired"

            Ui.ShellIcon {
                theme: root.theme
                name: "info"
                sizeRole: "small"
                role: "muted"
            }

            Ui.ShellText {
                theme: root.theme
                text: "Actions expired"
                sizeRole: "caption"
                role: "muted"
            }
        }
    }
}
