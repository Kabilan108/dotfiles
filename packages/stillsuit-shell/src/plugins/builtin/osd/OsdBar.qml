import QtQuick
import QtQuick.Layouts
import "../../../ui" as Ui

Item {
    id: root

    required property var context
    required property string iconName
    required property real value
    required property string signalRole
    property string label: ""
    property string accessibleName: label === ""
        ? signalRole + " level"
        : signalRole + " level " + label

    readonly property real clampedValue: Math.min(Math.max(value, 0), 1)
    readonly property bool reducedMotion: context.settings
        && context.settings.values
        && context.settings.values.reducedMotion === true
    readonly property int motionDuration: reducedMotion ? 0 : context.theme.motion.normal
    readonly property color backgroundColor: context.theme.semantic.surface.panel
    readonly property color borderColor: context.theme.component.osd.border
    readonly property color trackColor: context.theme.component.osd.track
    readonly property color configuredFillColor: context.theme.component.osd.fill
    readonly property color textColor: context.theme.component.osd.text
    readonly property real surfaceRadius: context.theme.metrics.radiusMedium
    readonly property color signalColor: context.theme.semantic.signal[signalRole] !== undefined
        ? context.theme.semantic.signal[signalRole]
        : configuredFillColor

    implicitWidth: 300
    implicitHeight: 48

    Ui.ShellSurface {
        id: surface

        anchors.fill: parent
        theme: root.context.theme
        kind: "osd"

        RowLayout {
            anchors {
                fill: parent
                leftMargin: root.context.theme.metrics.spaceUnit * 4
                rightMargin: root.context.theme.metrics.spaceUnit * 4
            }
            spacing: root.context.theme.metrics.spaceUnit * 3

            Ui.ShellIcon {
                theme: root.context.theme
                name: root.iconName
                role: root.signalRole
                sizeRole: "medium"
                accessibleName: root.accessibleName
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: height / 2
                color: root.trackColor

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.signalColor
                    transformOrigin: Item.Left

                    transform: Scale {
                        origin.x: 0
                        origin.y: 0
                        xScale: root.clampedValue
                        yScale: 1

                        Behavior on xScale {
                            NumberAnimation {
                                duration: root.motionDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            Ui.ShellText {
                visible: root.label !== ""
                theme: root.context.theme
                text: root.label
                color: root.textColor
                sizeRole: "caption"
                monospace: true
            }
        }
    }
}
