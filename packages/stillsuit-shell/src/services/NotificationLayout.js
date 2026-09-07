function deckKey(row) {
    return String((row || {}).sourceKey || "app:unknown")
}

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

function placements(rows, openDeckKey, options) {
    var opts = options || {}
    var peek = Number(opts.peek || 10)
    var gap = Number(opts.gap || 8)
    var deckGap = Number(opts.deckGap || 12)
    var cardHeight = Number(opts.cardHeight || 120)
    var decks = group(rows)
    var result = {}
    var y = 0
    for (var deckIndex = 0; deckIndex < decks.length; deckIndex++) {
        var deck = decks[deckIndex]
        var open = deck.key === String(openDeckKey || "")
        for (var rowIndex = 0; rowIndex < deck.rows.length; rowIndex++) {
            var row = deck.rows[rowIndex]
            result[row.key] = {
                y: y + (open ? rowIndex * (cardHeight + gap) : rowIndex * peek),
                z: 1000 - rowIndex,
                opacity: open || rowIndex < 3 ? (open || rowIndex === 0 ? 1 : 0.82 - rowIndex * 0.14) : 0,
                scale: open ? 1 : Math.max(0.92, 1 - rowIndex * 0.025),
                hidden: !open && rowIndex >= 3,
                front: rowIndex === 0,
                count: deck.rows.length
            }
        }
        y += open ? deck.rows.length * cardHeight + Math.max(0, deck.rows.length - 1) * gap
            : cardHeight + Math.min(2, Math.max(0, deck.rows.length - 1)) * peek
        if (deckIndex < decks.length - 1) y += deckGap
    }
    return { decks: decks, placements: result, height: y }
}

if (typeof module !== "undefined") module.exports = {
    deckKey: deckKey,
    group: group,
    placements: placements
}
