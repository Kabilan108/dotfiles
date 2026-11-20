var PREFIXES = {
    "/": "files",
    ">": "remmina",
    "$": "windows",
    ":": "clipboard"
}

var MODES = {
    combi: ["calc", "apps", "web"],
    windows: ["windows"],
    power: ["power"],
    profiles: ["profiles"],
    remmina: ["remmina"],
    clipboard: ["clipboard"]
}

var DEFAULT_MODE = "combi"
var MAX_INPUT_LENGTH = 1024

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function isHigh(code) {
    return code >= 0xD800 && code <= 0xDBFF
}

function isLow(code) {
    return code >= 0xDC00 && code <= 0xDFFF
}

function wellFormed(text, limit) {
    var cut = text
    if (text.length > limit) {
        cut = text.slice(0, limit)
        if (isHigh(text.charCodeAt(limit - 1)) && isLow(text.charCodeAt(limit))) cut = cut.slice(0, -1)
    }
    if (!/[\uD800-\uDFFF]/.test(cut)) return cut
    var result = ""
    var start = 0
    for (var index = 0; index < cut.length; index++) {
        var code = cut.charCodeAt(index)
        if (isHigh(code) && isLow(cut.charCodeAt(index + 1))) {
            index++
        } else if (isHigh(code) || isLow(code)) {
            result += cut.slice(start, index) + "\uFFFD"
            start = index + 1
        }
    }
    return result + cut.slice(start)
}

function normalizeMode(mode) {
    var name = safeString(mode)
    return Object.prototype.hasOwnProperty.call(MODES, name) ? name : DEFAULT_MODE
}

function prefixProvider(character) {
    return Object.prototype.hasOwnProperty.call(PREFIXES, character) ? PREFIXES[character] : ""
}

function parse(rawInput, mode) {
    var raw = wellFormed(safeString(rawInput), MAX_INPUT_LENGTH)
    var modeName = normalizeMode(mode)
    var first = raw.charAt(0)
    var prefixed = prefixProvider(first)
    if (prefixed !== "") {
        return {
            mode: modeName,
            raw: raw,
            prefix: first,
            providerIds: [prefixed],
            text: raw.slice(1).trim()
        }
    }
    return {
        mode: modeName,
        raw: raw,
        prefix: "",
        providerIds: MODES[modeName].slice(),
        text: raw.trim()
    }
}

if (typeof module !== "undefined") {
    module.exports = {
        parse: parse,
        wellFormed: wellFormed,
        normalizeMode: normalizeMode,
        PREFIXES: PREFIXES,
        MODES: MODES,
        DEFAULT_MODE: DEFAULT_MODE
    }
}
