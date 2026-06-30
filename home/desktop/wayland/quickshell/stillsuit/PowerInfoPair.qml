import QtQuick
import QtQuick.Layouts

RowLayout {
    property string label: ""
    property string value: ""
    property int valueWidth: 56

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
        Layout.preferredWidth: parent.valueWidth
        text: parent.value
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
        font.bold: true
        horizontalAlignment: Text.AlignRight
    }
}
