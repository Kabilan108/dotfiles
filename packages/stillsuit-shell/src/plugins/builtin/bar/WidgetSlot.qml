// Adapted from Omarchy Quattro v4.0.0's per-slot widget construction pattern.
// Copyright (c) David Heinemeier Hansson. Licensed under MIT.
import QtQuick

Item {
    id: root

    required property var registration
    readonly property string pluginId: registration && registration.manifest
        ? String(registration.manifest.id)
        : "unknown"
    property bool failed: false

    implicitWidth: failed || !widgetLoader.item
        ? 0
        : Math.max(0, widgetLoader.item.implicitWidth || widgetLoader.item.width || 0)
    implicitHeight: failed || !widgetLoader.item
        ? 0
        : Math.max(0, widgetLoader.item.implicitHeight || widgetLoader.item.height || 0)
    visible: !failed && widgetLoader.item !== null

    function loadRegistration() {
        failed = false
        if (!registration || !registration.component || !registration.context) {
            failed = true
            return
        }
        var properties = { context: registration.context }
        if (registration.service !== undefined)
            properties.service = registration.service
        widgetLoader.setSourceComponent(registration.component, properties)
    }

    function releaseSlot(message) {
        if (failed)
            return
        failed = true
        widgetLoader.active = false
        if (registration && registration.context && registration.context.logger)
            registration.context.logger.warn("bar widget " + pluginId + " omitted: " + message)
    }

    Loader {
        id: widgetLoader
        asynchronous: true
        onStatusChanged: {
            if (status === Loader.Error)
                root.releaseSlot("component construction failed")
        }
        onLoaded: {
            if (!item)
                root.releaseSlot("component returned no item")
        }
    }

    Component.onCompleted: loadRegistration()
    onRegistrationChanged: loadRegistration()
}
