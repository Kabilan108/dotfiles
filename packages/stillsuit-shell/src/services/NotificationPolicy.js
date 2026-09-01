function stringValue(value) {
    return value === undefined || value === null ? "" : String(value)
}

function boundedNumber(value, fallback, minimum, maximum) {
    var number = Number(value)
    if (!isFinite(number)) number = fallback
    return Math.max(minimum, Math.min(maximum, number))
}

function notificationsPolicy(settings) {
    var values = settings && settings.notifications ? settings.notifications : {}
    var bypass = values.dndBypass || {}
    return {
        popupLimit: Math.round(boundedNumber(values.popupLimit, 5, 1, 20)),
        historyLimit: Math.round(boundedNumber(values.historyLimit, 100, 1, 100)),
        historyMaxAgeMs: 24 * 60 * 60 * 1000,
        normalTimeoutMs: boundedNumber(values.normalTimeoutMs, 5000, 1, 24 * 60 * 60 * 1000),
        lowTimeoutMs: boundedNumber(values.lowTimeoutMs, 4000, 1, 24 * 60 * 60 * 1000),
        dndBypass: {
            critical: bypass.critical === undefined ? true : !!bypass.critical,
            appNames: Array.isArray(bypass.appNames) ? bypass.appNames : ["battery", "Battery"],
            appUrgencies: Array.isArray(bypass.appUrgencies) ? bypass.appUrgencies : [
                { appName: "notify-send", urgency: "critical" }
            ],
            summaryPatterns: Array.isArray(bypass.summaryPatterns) ? bypass.summaryPatterns : []
        }
    }
}

function viewState(snapshot) {
    var row = snapshot || {}
    if (row.read !== true) return "unread"

    var hinted = stringValue((row.hints || {})["x-stillsuit-state"]).toLowerCase()
    if (["info", "success", "warning", "danger", "muted"].indexOf(hinted) !== -1)
        return hinted
    if (Number(row.urgency) === 2) return "danger"
    if (Number(row.urgency) === 0 || stringValue(row.dndClass).indexOf("silenced-") === 0)
        return "muted"
    return "info"
}

function urgencyName(urgency) {
    if (Number(urgency) === 2) return "critical"
    if (Number(urgency) === 0) return "low"
    return "normal"
}

function durationFor(snapshot, settings) {
    var policy = notificationsPolicy(settings)
    if (Number((snapshot || {}).urgency) === 2) return 0
    if (Number((snapshot || {}).urgency) === 0) return Math.round(policy.lowTimeoutMs)
    var requested = Number((snapshot || {}).expireTimeout || 0)
    if (isFinite(requested) && requested > 0) return Math.round(requested)
    return Math.round(policy.normalTimeoutMs)
}

function shouldBypassDnd(snapshot, settings) {
    var policy = notificationsPolicy(settings).dndBypass
    var appName = stringValue((snapshot || {}).appName)
    var summary = stringValue((snapshot || {}).summary)
    var urgency = urgencyName((snapshot || {}).urgency)
    if (policy.critical && urgency === "critical") return true

    for (var index = 0; index < policy.appNames.length; index++)
        if (appName === stringValue(policy.appNames[index])) return true

    for (var ruleIndex = 0; ruleIndex < policy.appUrgencies.length; ruleIndex++) {
        var rule = policy.appUrgencies[ruleIndex] || {}
        if (appName === stringValue(rule.appName) && urgency === stringValue(rule.urgency).toLowerCase()) return true
    }

    for (var patternIndex = 0; patternIndex < policy.summaryPatterns.length; patternIndex++) {
        try {
            if (new RegExp(stringValue(policy.summaryPatterns[patternIndex])).test(summary)) return true
        } catch (error) {
            // A malformed optional rule cannot block the rest of notification policy.
        }
    }
    return false
}

function isTransient(snapshot) {
    var hints = (snapshot || {}).hints || {}
    return hints.transient === true || hints["transient"] === 1
}

function dndClass(snapshot, dnd, settings) {
    if (!dnd) return "visible"
    if (shouldBypassDnd(snapshot, settings)) return "bypass"
    return isTransient(snapshot) ? "silenced-ephemeral" : "silenced-retained"
}

// Multi-output rule: a toast stays on the output focused when it arrived.
// If that output disappeared, exactly one fallback is selected: the currently
// focused output, then the first output in stable input order.
function presentationOutput(snapshot, outputIds, focusedOutputId) {
    var outputs = Array.isArray(outputIds) ? outputIds.map(stringValue) : []
    var saved = stringValue((snapshot || {}).outputId)
    if (saved && outputs.indexOf(saved) !== -1) return saved
    var focused = stringValue(focusedOutputId)
    if (focused && outputs.indexOf(focused) !== -1) return focused
    return outputs.length > 0 ? outputs[0] : saved || focused
}

function shouldPresentOn(snapshot, viewOutputId, outputIds, focusedOutputId) {
    return stringValue(viewOutputId) === presentationOutput(snapshot, outputIds, focusedOutputId)
}

if (typeof module !== "undefined") {
    module.exports = {
        notificationsPolicy: notificationsPolicy,
        urgencyName: urgencyName,
        durationFor: durationFor,
        shouldBypassDnd: shouldBypassDnd,
        isTransient: isTransient,
        dndClass: dndClass,
        viewState: viewState,
        presentationOutput: presentationOutput,
        shouldPresentOn: shouldPresentOn
    }
}
