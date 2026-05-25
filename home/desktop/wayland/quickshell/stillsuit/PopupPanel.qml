import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    default property alias content: contentLayout.children

    property int padding: Theme.paddingMedium

    implicitWidth: 320
    implicitHeight: contentLayout.implicitHeight + padding * 2
    radius: Theme.radiusMedium
    color: Theme.panelBgStrong
    border.width: Theme.borderWidth
    border.color: Theme.panelBorderStrong

    ColumnLayout {
        id: contentLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: Theme.paddingSmall
    }
}
