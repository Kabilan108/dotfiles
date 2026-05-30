import QtQuick
import ".."

Text {
    id: root

    property string label: ""

    text: label
    color: Theme.mutedText
    font.family: Theme.bodyFontFamily
    font.pixelSize: 10
    font.bold: true
}
