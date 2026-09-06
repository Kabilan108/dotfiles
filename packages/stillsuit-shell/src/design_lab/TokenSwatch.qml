import QtQuick
import QtQuick.Layouts
import "../ui" as Ui

Rectangle {
    id: root

    required property var theme
    property string tokenName: "token"
    property color tokenColor: "#ffffff"

    implicitWidth: 178
    implicitHeight: 54
    radius: theme.metrics.radiusSmall
    color: theme.semantic.surface.raised
    border.width: 1
    border.color: theme.semantic.outline.subtle

    RowLayout {
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 9

        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: root.theme.metrics.radiusSmall
            color: root.tokenColor
            border.width: 1
            border.color: root.theme.semantic.outline.default
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Ui.ShellText {
                Layout.fillWidth: true
                theme: root.theme
                text: root.tokenName
                sizeRole: "caption"
                elide: Text.ElideRight
            }

            Ui.ShellText {
                theme: root.theme
                text: String(root.tokenColor).toUpperCase()
                sizeRole: "caption"
                role: "muted"
                monospace: true
            }
        }
    }
}
