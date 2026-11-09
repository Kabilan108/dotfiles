function deckKey(row) {
    return String((row || {}).sourceKey || "app:unknown")
}

// Rows newest first in, decks out in the order of their newest row.
function group(rows) {
    var input = Array.isArray(rows) ? rows : []
    var byKey = {}
    var result = []
    for (var index = 0; index < input.length; index++) {
        var row = input[index]
        var key = deckKey(row)
        if (!byKey[key]) {
            byKey[key] = { key: key, label: String(row.sourceLabel || row.appName || "Unknown"), rows: [] }
            result.push(byKey[key])
        }
        byKey[key].rows.push(row)
    }
    return result
}

if (typeof module !== "undefined") module.exports = {
    deckKey: deckKey,
    group: group
}
