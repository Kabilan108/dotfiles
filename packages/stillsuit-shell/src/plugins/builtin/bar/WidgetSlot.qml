// Adapted from Omarchy Quattro v4.0.0's per-slot widget construction pattern.
// Copyright (c) David Heinemeier Hansson. Licensed under MIT.
import QtQuick
import "../../../ui" as Ui

Item {
    id: root

    required property var registration
    required property string outputId
    property var panelAnchors: null
    property real anchorOffset: 0
    property string anchoredPluginId: ""
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

    HoverHandler { id: tooltipHover }
    Ui.ShellBarTooltip {
        theme: root.activeRegistration ? root.activeRegistration.context.theme : ({})
        target: root
        hovering: tooltipHover.hovered && root.visible
            && !(root.createdWidget && root.createdWidget.selected === true)
        text: root.createdWidget && typeof root.createdWidget.tooltipText === "string"
            ? root.createdWidget.tooltipText : ""
    }

    function loadRegistration() {
        invalidateConstruction()
        clearAnchor()
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

        var properties = { context: record.context, outputId: outputId }
        if (record.service !== undefined)
            properties.service = record.service
        var widget = component.createObject(root, properties)
        if (!widget) {
            releaseSlot("component construction returned null", token.generation)
            return
        }
        createdWidget = widget
        registerAnchor()
    }

    function registerAnchor() {
        if (!panelAnchors || typeof panelAnchors.set !== "function"
                || pluginId === "unknown")
            return
        anchoredPluginId = pluginId
        panelAnchors.set(anchoredPluginId, outputId, function() {
            if (!root.visible || root.width <= 0)
                return -1
            return root.anchorOffset + root.mapToItem(null, root.width / 2, 0).x
        })
    }

    function clearAnchor() {
        if (anchoredPluginId === "")
            return
        if (panelAnchors && typeof panelAnchors.clear === "function")
            panelAnchors.clear(anchoredPluginId, outputId)
        anchoredPluginId = ""
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
        clearAnchor()
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
        clearAnchor()
        destroyWidget()
    }
    onRegistrationChanged: {
        if (componentComplete)
            loadRegistration()
    }
    onPanelAnchorsChanged: {
        if (componentComplete && createdWidget)
            registerAnchor()
    }
}
