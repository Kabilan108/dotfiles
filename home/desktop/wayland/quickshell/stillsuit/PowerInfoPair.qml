import QtQuick
import QtQuick.Layouts

RowLayout {
    property string label: ""
    property string value: ""

    Layout.fillWidth: true
    spacing: 8

    Text {
        text: parent.label
        color: Theme.dimText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    Item {
        Layout.fillWidth: true
    }

    Text {
        text: parent.value
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}
