import QtQuick
import Quickshell

Scope {
    id: root
    property var router: null
    property var theme: ({})
    property var screens: []
    Variants {
        model: root.screens
        PanelHost {
            required property var modelData
            screen: modelData
            outputId: String(modelData.name)
            theme: root.theme
            router: root.router
        }
    }
}
