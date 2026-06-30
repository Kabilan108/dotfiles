import QtQuick
import ".."

Row {
    id: root

    property int level: 0
    property color barColor: Theme.accent

    readonly property var heights: [5, 8, 11, 13]

    spacing: 2
    height: 13

    Repeater {
        model: root.heights

        Rectangle {
            required property int index
            required property var modelData

            width: 3
            height: modelData
            y: root.height - modelData
            radius: 1
            color: index < root.level ? root.barColor : Theme.textMuted
            opacity: index < root.level ? 1 : 0.38
        }
    }
}
