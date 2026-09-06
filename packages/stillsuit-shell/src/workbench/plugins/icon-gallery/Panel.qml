import QtQuick
import QtQuick.Layouts
import Stillsuit.Ui as Ui

Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: nameColumnWidth + roles.length * roleColumnWidth + columnGap * (roles.length + 1)
        + root.context.theme.metrics.panelPadding * 2
    implicitHeight: content.implicitHeight + root.context.theme.metrics.panelPadding * 2
    visible: false

    required property var context
    required property var screen
    required property string outputId
    property bool opened: false

    readonly property var roles: ["primary", "secondary", "muted", "accent", "danger", "success"]
    readonly property var sizes: ["small", "medium", "large"]
    readonly property var names: catalogProbe._catalog().concat(["unknown-name"])
    readonly property int nameColumnWidth: 118
    readonly property int columnGap: root.context.theme.metrics.spaceUnit * 2
    readonly property int roleColumnWidth: root.context.theme.metrics.iconSmall
        + root.context.theme.metrics.iconMedium + root.context.theme.metrics.iconLarge
        + root.context.theme.metrics.spaceUnit * 2

    function open(payloadJson) {
        opened = true;
    }

    function close() {
        opened = false;
    }

    Ui.ShellIcon {
        id: catalogProbe
        visible: false
        theme: root.context.theme
    }

    Ui.ShellSurface {
        anchors.fill: parent

        theme: root.context.theme
        kind: "panel"

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: root.context.theme.metrics.panelPadding
            spacing: 10

            Ui.ShellPanelHeader {
                Layout.fillWidth: true
                theme: root.context.theme
                title: "Icon gallery"
                subtitle: (root.names.length - 1) + " catalog icons at "
                    + root.context.theme.metrics.iconSmall + ", "
                    + root.context.theme.metrics.iconMedium + " and "
                    + root.context.theme.metrics.iconLarge + " px, plus the unknown-name fallback"
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: root.nameColumnWidth + root.columnGap
                spacing: root.columnGap

                Repeater {
                    model: root.roles

                    Ui.ShellSectionLabel {
                        required property string modelData

                        Layout.preferredWidth: root.roleColumnWidth
                        theme: root.context.theme
                        text: modelData
                    }
                }
            }

            Ui.ShellScrollArea {
                Layout.fillWidth: true
                theme: root.context.theme
                maximumHeight: root.screen ? Math.max(240, root.screen.height * 0.6) : 560
                contentHeight: rows.implicitHeight

                ColumnLayout {
                    id: rows

                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: root.names

                        ColumnLayout {
                            id: row

                            required property string modelData
                            required property int index

                            Layout.fillWidth: true
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: 6
                                Layout.bottomMargin: 6
                                spacing: root.columnGap

                                Ui.ShellText {
                                    Layout.preferredWidth: root.nameColumnWidth
                                    Layout.minimumWidth: root.nameColumnWidth
                                    theme: root.context.theme
                                    text: row.modelData
                                    sizeRole: "caption"
                                    role: row.index === root.names.length - 1 ? "muted" : "secondary"
                                    monospace: true
                                    elide: Text.ElideRight
                                }

                                Repeater {
                                    model: root.roles

                                    RowLayout {
                                        id: roleCell

                                        required property string modelData

                                        Layout.preferredWidth: root.roleColumnWidth
                                        Layout.alignment: Qt.AlignBottom
                                        spacing: root.context.theme.metrics.spaceUnit

                                        Repeater {
                                            model: root.sizes

                                            Ui.ShellIcon {
                                                required property string modelData

                                                Layout.alignment: Qt.AlignBottom
                                                theme: root.context.theme
                                                name: row.modelData
                                                role: roleCell.modelData
                                                sizeRole: modelData
                                                accessibleName: row.modelData + " " + roleCell.modelData + " " + modelData
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: root.context.theme.semantic.outline.subtle
                                visible: row.index < root.names.length - 1
                            }
                        }
                    }
                }
            }
        }
    }
}
