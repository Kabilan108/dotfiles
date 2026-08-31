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
    property int constructionGeneration: 0
    property var activeRegistration: null
    property var createdWidget: null
    property var pendingConstruction: null

    implicitWidth: failed || !createdWidget
        ? 0
        : Math.max(0, createdWidget.implicitWidth || createdWidget.width || 0)
    implicitHeight: failed || !createdWidget
        ? 0
        : Math.max(0, createdWidget.implicitHeight || createdWidget.height || 0)
    visible: !failed && createdWidget !== null

    function loadRegistration() {
        invalidateConstruction()
        destroyWidget()
        failed = false
        releaseNotified = false
        var token = {
            cancelled: false,
            generation: constructionGeneration,
            registration: registration
        }
        activeRegistration = token.registration
        pendingConstruction = token
        Qt.callLater(function() {
            if (token.cancelled)
                return
            root.constructWidget(token)
        })
    }

    function constructWidget(token) {
        if (token !== pendingConstruction
                || token.generation !== constructionGeneration
                || !componentComplete)
            return
        pendingConstruction = null

        var record = token.registration
        if (!record || !record.component || !record.context) {
            releaseSlot("registration is incomplete", token.generation)
            return
        }

        var component = record.component
        if (component.status !== Component.Ready) {
            var detail = component.status === Component.Error
                ? component.errorString()
                : "component is not ready"
            releaseSlot("component compilation failed: " + detail, token.generation)
            return
        }

        var properties = { context: record.context }
        if (record.service !== undefined)
            properties.service = record.service
        var widget = component.createObject(root, properties)
        if (!widget) {
            releaseSlot("component construction returned null", token.generation)
            return
        }
        createdWidget = widget
    }

    function invalidateConstruction() {
        constructionGeneration++
        if (pendingConstruction)
            pendingConstruction.cancelled = true
        pendingConstruction = null
    }

    function destroyWidget() {
        var widget = createdWidget
        createdWidget = null
        if (widget && typeof widget.destroy === "function")
            widget.destroy()
    }

    function releaseSlot(message, generation) {
        if (generation !== constructionGeneration || failed || !componentComplete)
            return
        failed = true
        destroyWidget()
        var record = activeRegistration
        if (record && record.context && record.context.logger)
            record.context.logger.warn("bar widget " + pluginId + " omitted: " + message)
        if (!releaseNotified && record && typeof record.release === "function") {
            releaseNotified = true
            record.release(message)
        }
    }

    Component.onCompleted: {
        componentComplete = true
        loadRegistration()
    }
    Component.onDestruction: {
        componentComplete = false
        invalidateConstruction()
        destroyWidget()
    }
    onRegistrationChanged: {
        if (componentComplete)
            loadRegistration()
    }
}
