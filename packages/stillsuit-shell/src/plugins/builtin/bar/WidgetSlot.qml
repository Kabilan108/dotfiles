// Adapted from Omarchy Quattro v4.0.0's per-slot widget construction pattern.
// Copyright (c) David Heinemeier Hansson. Licensed under MIT.
import QtQuick

Item {
    id: root

    required property var registration
    readonly property string pluginId: activeRegistration && activeRegistration.manifest
        ? String(activeRegistration.manifest.id)
        : "unknown"
    property bool failed: false
    property bool componentComplete: false
    property bool releaseNotified: false
    property var activeRegistration: null
    property var createdWidget: null

    implicitWidth: failed || !createdWidget
        ? 0
        : Math.max(0, createdWidget.implicitWidth || createdWidget.width || 0)
    implicitHeight: failed || !createdWidget
        ? 0
        : Math.max(0, createdWidget.implicitHeight || createdWidget.height || 0)
    visible: !failed && createdWidget !== null

    function loadRegistration() {
        constructionTimer.stop()
        destroyWidget()
        failed = false
        releaseNotified = false
        activeRegistration = registration
        constructionTimer.start()
    }

    function constructWidget() {
        var record = activeRegistration
        if (!record || !record.component || !record.context) {
            releaseSlot("registration is incomplete")
            return
        }

        var component = record.component
        if (component.status !== Component.Ready) {
            var detail = component.status === Component.Error
                ? component.errorString()
                : "component is not ready"
            releaseSlot("component compilation failed: " + detail)
            return
        }

        var properties = { context: record.context }
        if (record.service !== undefined)
            properties.service = record.service
        var widget = component.createObject(root, properties)
        if (!widget) {
            releaseSlot("component construction returned null")
            return
        }
        createdWidget = widget
    }

    function destroyWidget() {
        var widget = createdWidget
        createdWidget = null
        if (widget && typeof widget.destroy === "function")
            widget.destroy()
    }

    function releaseSlot(message) {
        if (failed)
            return
        failed = true
        constructionTimer.stop()
        destroyWidget()
        var record = activeRegistration
        if (record && record.context && record.context.logger)
            record.context.logger.warn("bar widget " + pluginId + " omitted: " + message)
        if (!releaseNotified && record && typeof record.release === "function") {
            releaseNotified = true
            record.release(message)
        }
    }

    Timer {
        id: constructionTimer
        interval: 0
        repeat: false
        onTriggered: root.constructWidget()
    }

    Component.onCompleted: {
        componentComplete = true
        loadRegistration()
    }
    Component.onDestruction: {
        constructionTimer.stop()
        destroyWidget()
    }
    onRegistrationChanged: {
        if (componentComplete)
            loadRegistration()
    }
}
