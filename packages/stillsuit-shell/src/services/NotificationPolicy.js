function stringValue(value) {
    return value === undefined || value === null ? "" : String(value)
}

function listValue(value) {
    if (Array.isArray(value)) return value.slice()
    if (value && typeof value === "object" && typeof value.length === "number") {
        var result = []
        for (var index = 0; index < value.length; index++) result.push(value[index])
        return result
    }
    return null
}

function boundedNumber(value, fallback, minimum, maximum) {
    var number = Number(value)
    if (!isFinite(number)) number = fallback
    return Math.max(minimum, Math.min(maximum, number))
}

var summaryPatternCache = Object.create(null)

function compiledSummaryPatterns(values, reportWarning) {
    var patterns = listValue(values) || []
    var compiled = []
    for (var index = 0; index < patterns.length; index++) {
        var pattern = stringValue(patterns[index])
        var cached = summaryPatternCache[pattern]
        if (!cached) {
            cached = { regex: null, error: "", reported: false }
            try {
                cached.regex = new RegExp(pattern)
            } catch (error) {
                cached.error = String(error)
            }
            summaryPatternCache[pattern] = cached
        }
        if (cached.regex) {
            compiled.push(cached.regex)
        } else if (!cached.reported && typeof reportWarning === "function") {
            cached.reported = true
            reportWarning("Invalid notifications.quietBypass.summaryPatterns pattern "
                + JSON.stringify(pattern) + ": " + cached.error)
        }
    }
    return compiled
}

function notificationsPolicy(settings, reportWarning) {
    var values = settings && settings.notifications ? settings.notifications : {}
    var bypass = values.quietBypass || values.dndBypass || {}
    return {
        popupLimit: Math.round(boundedNumber(values.popupLimit, 5, 1, 20)),
        deckRowLimit: Math.round(boundedNumber(values.deckRowLimit, 8, 1, 40)),
        heldLimit: Math.round(boundedNumber(values.heldLimit, 50, 1, 200)),
        avoidOutputs: (listValue(values.avoidOutputs) || []).map(stringValue),
        maxAgeMs: 24 * 60 * 60 * 1000,
        normalTimeoutMs: boundedNumber(values.normalTimeoutMs, 5000, 1, 24 * 60 * 60 * 1000),
        lowTimeoutMs: boundedNumber(values.lowTimeoutMs, 4000, 1, 24 * 60 * 60 * 1000),
        actionTimeoutMs: boundedNumber(values.actionTimeoutMs, 10000, 1, 24 * 60 * 60 * 1000),
        hoverGraceMs: boundedNumber(values.hoverGraceMs, 1200, 0, 60 * 1000),
        quietBypass: {
            critical: bypass.critical === undefined ? true : !!bypass.critical,
            appNames: listValue(bypass.appNames) || ["battery", "Battery"],
            appUrgencies: listValue(bypass.appUrgencies) || [
                { appName: "notify-send", urgency: "critical" }
            ],
            summaryPatterns: compiledSummaryPatterns(bypass.summaryPatterns, reportWarning)
        }
    }
}

function viewState(snapshot) {
    var row = snapshot || {}
    var hinted = stringValue((row.hints || {})["x-stillsuit-state"]).toLowerCase()
    if (["info", "success", "warning", "danger", "muted"].indexOf(hinted) !== -1)
        return hinted
    if (Number(row.urgency) === 2) return "danger"
    if (Number(row.urgency) === 0) return "muted"
    return "info"
}

function urgencyName(urgency) {
    if (Number(urgency) === 2) return "critical"
    if (Number(urgency) === 0) return "low"
    return "normal"
}

function isSettingsAction(action) {
    var identifier = stringValue((action || {}).identifier).trim().toLowerCase()
    var label = stringValue((action || {}).text).trim().toLowerCase()
    return identifier === "settings" || label === "settings"
}

function buttonActions(actions) {
    return (listValue(actions) || []).filter(function(action) {
        return action && stringValue(action.identifier) !== "default" && !isSettingsAction(action)
    })
}

function durationFor(snapshot, settings) {
    var row = snapshot || {}
    var policy = notificationsPolicy(settings)
    if (Number(row.urgency) === 2) return 0
    if (Number(row.urgency) === 0) return Math.round(policy.lowTimeoutMs)
    var requested = Number(row.expireTimeout || 0)
    if (isFinite(requested) && requested > 0) return Math.round(requested)
    if (buttonActions(row.actions).length > 0)
        return Math.round(Math.max(policy.normalTimeoutMs, policy.actionTimeoutMs))
    return Math.round(policy.normalTimeoutMs)
}

function resumedDeadline(deadline, pausedAt, now, settings) {
    var current = Number(deadline || 0)
    if (current <= 0) return current
    var left = Math.max(0, current - Number(pausedAt || now))
    return Number(now) + Math.max(left, notificationsPolicy(settings).hoverGraceMs)
}

function shouldBypassQuiet(snapshot, settings) {
    var policy = notificationsPolicy(settings).quietBypass
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
        if (policy.summaryPatterns[patternIndex].test(summary)) return true
    }
    return false
}

function isTransient(snapshot) {
    var hints = (snapshot || {}).hints || {}
    return hints.transient === true || hints["transient"] === 1
}

function quietClass(snapshot, held, settings) {
    if (!held) return "visible"
    if (shouldBypassQuiet(snapshot, settings)) return "bypass"
    var hints = (snapshot || {}).hints || {}
    var stacked = stringValue(hints["x-dunst-stack-tag"] || hints["x-canonical-private-synchronous"]) !== ""
    return isTransient(snapshot) || stacked ? "silenced-ephemeral" : "silenced-retained"
}

function sourceTint(key) {
    var text = stringValue(key)
    var hash = 2166136261
    for (var index = 0; index < text.length; index++) {
        hash ^= text.charCodeAt(index) & 0xff
        hash = Math.imul(hash, 16777619) >>> 0
    }
    return oklchHex(0.76, 0.11, hash % 360)
}

function oklchHex(lightness, chroma, hue) {
    var radians = hue * Math.PI / 180
    var a = chroma * Math.cos(radians)
    var b = chroma * Math.sin(radians)
    var l = Math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
    var m = Math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
    var s = Math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
    var linear = [
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    ]
    return "#" + linear.map(function(channel) {
        var clamped = Math.max(0, Math.min(1, channel))
        var encoded = clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * Math.pow(clamped, 1 / 2.4) - 0.055
        var hex = Math.round(encoded * 255).toString(16)
        return hex.length === 1 ? "0" + hex : hex
    }).join("")
}

function presentationOutput(snapshot, outputIds, focusedOutputId, avoidOutputs) {
    var all = (listValue(outputIds) || []).map(stringValue)
    var avoid = (listValue(avoidOutputs) || []).map(stringValue)
    var allowed = all.filter(function(id) { return avoid.indexOf(id) === -1 })
    var outputs = allowed.length > 0 ? allowed : all
    var saved = stringValue((snapshot || {}).outputId)
    if (saved && outputs.indexOf(saved) !== -1) return saved
    var focused = stringValue(focusedOutputId)
    if (focused && outputs.indexOf(focused) !== -1) return focused
    return outputs.length > 0 ? outputs[0] : saved || focused
}

function shouldPresentOn(snapshot, viewOutputId, outputIds, focusedOutputId, avoidOutputs) {
    return stringValue(viewOutputId) === presentationOutput(snapshot, outputIds, focusedOutputId, avoidOutputs)
}

if (typeof module !== "undefined") {
    module.exports = {
        notificationsPolicy: notificationsPolicy,
        urgencyName: urgencyName,
        durationFor: durationFor,
        resumedDeadline: resumedDeadline,
        buttonActions: buttonActions,
        isSettingsAction: isSettingsAction,
        sourceTint: sourceTint,
        oklchHex: oklchHex,
        shouldBypassQuiet: shouldBypassQuiet,
        isTransient: isTransient,
        quietClass: quietClass,
        viewState: viewState,
        presentationOutput: presentationOutput,
        shouldPresentOn: shouldPresentOn,
        listValue: listValue
    }
}
