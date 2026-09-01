import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    required property var context
    required property var service
    required property var snapshot
    property bool inline: false
    property string timeText: ""

    readonly property var theme: context.theme
    readonly property bool critical: Number(snapshot.urgency) === 2
    readonly property bool low: Number(snapshot.urgency) === 0
    readonly property color accent: critical ? theme.colors.status.danger
        : low ? theme.colors.text.secondary : theme.colors.status.info
    readonly property var actions: Array.isArray(snapshot.actions) ? snapshot.actions : []
    readonly property string iconSource: {
        var value = String(snapshot.image || snapshot.appIcon || "")
        if (!value) return ""
        if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
        if (value.charAt(0) === "/") return "file://" + value
        return Quickshell.iconPath(value, true)
    }

    function cleanBody(value) {
        return String(value || "").replace(/<img[^>]*>/gi, "").trim()
    }

    implicitWidth: inline ? 368 : 360
    implicitHeight: content.implicitHeight + 20
    radius: theme.geometry.radius
    color: inline ? "transparent" : theme.colors.surface.raised
    border.width: inline ? 0 : 1
    border.color: critical ? theme.colors.status.danger : theme.colors.border.normal
    clip: true

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.service.invokeAction(root.snapshot.key, "default")
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 10
        }
        spacing: 10

        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignTop

            Image {
                id: icon
                anchors.fill: parent
                source: root.iconSource
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: status === Image.Ready
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                visible: icon.status !== Image.Ready
                color: root.accent

                Text {
                    anchors.centerIn: parent
                    text: root.critical ? "!" : "i"
                    color: root.theme.colors.text.onAccent
                    font.family: root.theme.typography.family
                    font.pixelSize: root.theme.typography.baseSize
                    font.bold: true
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: root.snapshot.appName || "notification"
                    color: root.accent
                    font.family: root.theme.typography.family
                    font.pixelSize: root.theme.typography.baseSize * 0.8
                    elide: Text.ElideRight
                }

                Text {
                    text: root.timeText
                    visible: text !== ""
                    color: root.theme.colors.text.tertiary
                    font.family: root.theme.typography.monospaceFamily
                    font.pixelSize: root.theme.typography.baseSize * 0.75
                }

                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: root.theme.geometry.radius * 0.5
                    color: closeMouse.containsMouse ? root.theme.controls.hover.fill : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: root.theme.colors.text.secondary
                        font.pixelSize: root.theme.typography.baseSize
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.service.dismiss(root.snapshot.key)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.snapshot.summary || "Notification"
                color: root.theme.colors.text.primary
                font.family: root.theme.typography.family
                font.pixelSize: root.theme.typography.baseSize
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.cleanBody(root.snapshot.body)
                visible: text !== ""
                color: root.theme.colors.text.secondary
                font.family: root.theme.typography.family
                font.pixelSize: root.theme.typography.baseSize * 0.9
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: root.actions.length > 0

                Repeater {
                    model: root.actions

                    Rectangle {
                        required property var modelData
                        Layout.preferredWidth: actionText.implicitWidth + 18
                        Layout.preferredHeight: actionText.implicitHeight + 10
                        radius: root.theme.geometry.radius * 0.6
                        color: actionMouse.containsMouse
                            ? root.theme.controls.hover.fill : root.theme.controls.normal.fill
                        border.width: 1
                        border.color: root.theme.controls.normal.border

                        Text {
                            id: actionText
                            anchors.centerIn: parent
                            text: modelData.text || modelData.identifier
                            color: root.theme.controls.normal.text
                            font.family: root.theme.typography.family
                            font.pixelSize: root.theme.typography.baseSize * 0.85
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.service.invokeAction(root.snapshot.key, modelData.identifier)
                        }
                    }
                }
            }
        }
    }
}
