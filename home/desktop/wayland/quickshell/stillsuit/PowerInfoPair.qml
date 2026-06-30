import QtQuick
import QtQuick.Layouts

RowLayout {
    property string label: ""
    property string value: ""

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: parent.label
        color: Theme.textTertiary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
    }

    Item {
        Layout.fillWidth: true
    }

    Text {
        text: parent.value
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
        font.bold: true
    }
}
