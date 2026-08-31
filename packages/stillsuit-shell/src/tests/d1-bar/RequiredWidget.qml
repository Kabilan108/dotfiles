import QtQuick

Item {
    required property var context
    required property var service

    implicitWidth: 19
    implicitHeight: 11

    Component.onCompleted: {
        if (service)
            service.recordConstruction(context.instanceId)
    }
    Component.onDestruction: {
        if (service)
            service.recordDestruction()
    }
}
