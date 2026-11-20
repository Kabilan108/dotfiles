var WORDS = [
    "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel",
    "india", "juliet", "kilo", "lima", "mike", "november", "oscar", "papa", "quebec",
    "romeo", "sierra", "tango", "uniform", "victor", "whiskey", "xray", "yankee", "zulu",
    "studio", "editor", "manager", "viewer", "player", "browser", "terminal", "monitor"
]

function capitalized(word) {
    return word.charAt(0).toUpperCase() + word.slice(1)
}

function syntheticApps(count) {
    var result = []
    var seed = 12345
    function next() {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff
        return seed
    }
    for (var index = 0; index < count; index++) {
        var nameWords = []
        var length = 1 + next() % 3
        for (var w = 0; w < length; w++) {
            nameWords.push(capitalized(WORDS[next() % WORDS.length]))
        }
        var keywords = []
        for (var k = 0; k < 4; k++) {
            keywords.push(WORDS[next() % WORDS.length])
        }
        var genericName = WORDS[next() % WORDS.length] + " " + WORDS[next() % WORDS.length]
        var comment = "A synthetic " + WORDS[next() % WORDS.length] + " application for "
            + WORDS[next() % WORDS.length] + " and " + WORDS[next() % WORDS.length]
        result.push({
            id: "synthetic-" + index,
            name: nameWords.join(" ") + " " + index,
            genericName: genericName,
            comment: comment,
            keywords: keywords,
            icon: "synthetic-" + index,
            categories: [],
            actions: [],
            runInTerminal: false
        })
    }
    return result
}

if (typeof module !== "undefined") {
    module.exports = {
        syntheticApps: syntheticApps
    }
}
