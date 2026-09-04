import QtQuick

Item {
    required property var context
    required property var service
    required property string outputId

    implicitWidth: 19
    implicitHeight: 11

    Component.onCompleted: {
        if (service)
            service.recordConstruction(context.instanceId, outputId)
    }
    Component.onDestruction: {
        if (service)
            service.recordDestruction()
    }
}
