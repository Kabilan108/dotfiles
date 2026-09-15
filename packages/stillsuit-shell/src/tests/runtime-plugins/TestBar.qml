import QtQuick
import "../../plugins/builtin/bar" as Bar

Item {
    id: root

    required property var context
    property var widgetRegistrations: []
    property var outputScreens: []
    property alias slots: slots

    Repeater {
        id: slots
        model: root.widgetRegistrations

        Bar.WidgetSlot {
            required property var modelData
            registration: modelData
            outputId: "fixture"
        }
    }
}
