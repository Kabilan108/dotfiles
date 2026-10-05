const assert = require("node:assert/strict")
const { Matcher } = require("./load.js")

const score = (query, fields, opts) => Matcher.score(query, fields, opts)

// No match and empty input return 0.
assert.equal(score("xyz", ["Ghostty"]).score, 0)
assert.equal(score("", ["Ghostty"]).score, 0)
assert.equal(score("ghost", []).score, 0)
assert.equal(score("ghost", [null, undefined, ""]).score, 0)
assert.equal(score("ghostty!", ["Ghostty"]).score, 0, "every query char must appear")

// fzf v2 values: start-of-string bonus doubled on the first char, then
// consecutive bonuses; minus the start offset.
assert.equal(score("ghost", ["Ghostty"]).score, 140)
assert.equal(score("obs", ["Obsidian"]).score, 88)
assert.equal(score("hel", ["~/shell"]).score, 53, "late start and no boundary score lower")
assert.ok(score("ss", ["Super Studio"]).score > score("ss", ["classes"]).score, "word boundaries beat mid-word runs")
assert.ok(score("fb", ["FooBar"]).score > score("fb", ["foobar"]).score, "camelCase boundary bonus")
assert.ok(score("abc", ["abc"]).score > score("abc", ["a-b-c"]).score, "consecutive run beats gaps")
assert.ok(score("abc", ["xx abc"]).score > score("abc", ["xxxxxxxx abc"]).score, "later start is penalised")

// Positions are ascending indices into the matched field.
assert.deepEqual(score("vsc", ["Visual Studio Code"]).positions, [0, 7, 14])
assert.deepEqual(score("code", ["Visual Studio Code"]).positions, [14, 15, 16, 17])
assert.deepEqual(score("sc", ["SuperCollider"]).positions, [0, 5])

// Field index penalty min(index * 5, 50).
const first = score("term", ["Terminal"])
const second = score("term", ["", "Terminal"])
const far = score("term", ["", "", "", "", "", "", "", "", "", "", "", "", "Terminal"])
assert.equal(first.field, 0)
assert.equal(second.field, 1)
assert.equal(first.score - second.score, 5)
assert.equal(first.score - far.score, 50, "penalty caps at 50")
assert.equal(score("term", ["xterm thing", "Terminal"]).field, 1, "the best adjusted field wins")

// Case-insensitive, with a bonus for matching an uppercase query exactly.
assert.equal(score("GHOST", ["ghostty"]).score, 140)
assert.ok(score("OBS", ["OBS Studio"]).score > score("OBS", ["Obsidian"]).score)
assert.equal(score("obs", ["OBS Studio"]).score, score("obs", ["Obsidian"]).score, "lowercase queries get no case bonus")

// Acronyms for terms of 5 chars or fewer.
const acronym = score("vsc", ["Visual Studio Code"])
assert.equal(acronym.acronym, true)
assert.equal(acronym.score, 88)
assert.equal(score("gc", ["Google Contacts"]).acronym, true)
assert.equal(score("vmm", ["Virtual Machine Manager"]).acronym, true)
assert.equal(score("abcdef", ["Alpha Bravo Charlie Delta Echo Foxtrot"]).acronym, false, "6 chars is too long")
assert.equal(score("vsc", ["Visual Studio Code"], { acronym: false }).acronym, false)
assert.equal(Matcher.prepare("camelCaseWord x264 7zip").acronym, "ccwx27")

// Contact must not loosely match the calculator's text (Omarchy's case).
assert.equal(score("contact", ["Calculator", "", "calculation arithmetic scientific financial",
    "Perform arithmetic, scientific or financial calculations"]).score, 0)

// Non-ASCII text keeps positions aligned with the original string.
assert.deepEqual(score("über", ["Ein Über Ding"]).positions, [4, 5, 6, 7])
assert.equal(score("ÜBER", ["über"]).score > 0, true)

// Prepared inputs are reused and give the same answer as strings.
const prepared = Matcher.prepare("Visual Studio Code")
assert.equal(Matcher.prepare(prepared), prepared)
const query = Matcher.prepareQuery("vsc")
assert.equal(Matcher.prepareQuery(query), query)
assert.deepEqual(score(query, [prepared]), score("vsc", ["Visual Studio Code"]))

// Long inputs neither crash nor overflow.
assert.equal(score("needle", ["a".repeat(3000) + "needle"]).score, 1, "a late match floors at 1")
assert.equal(score("needle", ["a".repeat(5000) + "needle"]).score, 0, "fields are cut at 4096 chars")
assert.equal(score("x".repeat(200), ["x".repeat(300)]).score > 0, true)

// Repeated scoring with shared scratch buffers is deterministic.
const reference = JSON.stringify(score("studio", ["OBS Studio", "Streaming/Recording Software"]))
for (let index = 0; index < 50; index++) {
    score("zzzzzzzzzzzz", ["z a z b z c z d z e z f z g z h z i z j z k z l"])
    score("q", ["quick"])
    assert.equal(JSON.stringify(score("studio", ["OBS Studio", "Streaming/Recording Software"])), reference)
}

assert.equal(Matcher.strongThreshold(100), 75)

// Case folding is per code point: final sigma, dotted capital I, astral
// letters. Positions index the original string's UTF-16 units.
assert.deepEqual(score("σ", ["λόγος"]).positions, [4], "final sigma folds to σ")
assert.ok(score("ΛΟΓΟΣ", ["λογος"]).score > 0)
assert.ok(score("λογος", ["ΛΟΓΟΣ"]).score > 0)
assert.deepEqual(score("ist", ["İstanbul"]).positions, [0, 1, 2], "İ folds to i")
assert.deepEqual(score("\u{10428}", ["\u{10400}bc"]).positions, [0, 1], "astral uppercase folds as a pair")
assert.deepEqual(score("b", ["a\u{10400}b"]).positions, [3], "positions after an astral char stay UTF-16 indices")
assert.deepEqual(score("ab", ["AΣB"]).positions, [0, 2])
assert.equal(Matcher.prepare("ÉCOLE ΣΟΦΊΑ \u{10400}").lower, "école σοφία \u{10428}")
assert.equal(Matcher.prepare("İx").lower.length, 2, "folding keeps the length")

// Patterns longer than the alignment window still need every character.
const longPattern = "x".repeat(128) + "y"
assert.equal(score(longPattern, ["x".repeat(300)]).score, 0, "a missing suffix is no match")
assert.ok(score(longPattern, ["x".repeat(300) + "y"]).score > 0)
assert.equal(score("x".repeat(129), ["x".repeat(128)]).score, 0, "longer than the field")
assert.equal(score("a".repeat(5000), ["a".repeat(5000)]).score, 0, "longer than any prepared field")
assert.equal(Matcher.prepareQuery(longPattern).text, longPattern)

// opts.minScore only removes matches below it.
{
    const fields = require("./load.js").syntheticApps(300).map(app =>
        [app.name, app.genericName, app.keywords.join(" "), app.comment].map(Matcher.prepare))
    const queries = ["a", "s", "x", "z", "al", "st", "te", "ed", "vi", "ao", "alp", "stu", "brv", "Al", "xr", "zu"]
    let kept = 0
    for (const query of queries) {
        for (const item of fields) {
            const full = score(query, item)
            const bounded = score(query, item, { minScore: 30 })
            if (full.score >= 30) {
                assert.deepEqual(bounded, full, `${query} keeps ${JSON.stringify(full)}`)
                kept++
            } else {
                assert.equal(bounded.score, 0, `${query} drops ${full.score}`)
            }
        }
    }
    assert.ok(kept > 100)
}

// The two-character path matches the general DP exactly: same score, field,
// start and positions. Small alphabets with boundary characters exercise ties,
// consecutive runs and fzf's gap-over-match quirk.
{
    const fs = require("node:fs")
    const vm = require("node:vm")
    const source = fs.readFileSync(require("node:path").join(require("./load.js").modelDir, "Matcher.js"), "utf8")
    assert.match(source, /var TWO_CHAR_PATH = true/)
    const context = vm.createContext({})
    vm.runInContext(source.replace("var TWO_CHAR_PATH = true", "var TWO_CHAR_PATH = false"), context)
    const reference = context
    let seed = 7
    const next = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff)
    const same = (pattern, field, options) => assert.deepEqual(
        JSON.parse(JSON.stringify(Matcher.score(pattern, [field, field.toUpperCase()], options))),
        JSON.parse(JSON.stringify(reference.score(pattern, [field, field.toUpperCase()], options))),
        `${JSON.stringify(pattern)} in ${JSON.stringify(field)}`)
    // A gap-over-match column read by the traceback's tie-break.
    same("ab", "   bba    bbaabb bb baabab    babb  ")
    const alphabets = ["ab", "ab ", "a b-", "aAbB ", "abc ", "aAbB-_ /", "abcdefgh ", "aab.B c1/"]
    let compared = 0
    for (let iteration = 0; iteration < 60000; iteration++) {
        const alphabet = alphabets[iteration % alphabets.length]
        const length = 2 + next() % (iteration % 7 === 0 ? 90 : 42)
        let field = ""
        for (let index = 0; index < length; index++) field += alphabet.charAt(next() % alphabet.length)
        const pattern = alphabet.charAt(next() % alphabet.length) + alphabet.charAt(next() % alphabet.length)
        if (pattern.trim().length < 2) continue
        const options = [undefined, { acronym: false }, { minScore: 30 }, { startPenalty: false }][iteration % 4]
        same(pattern, field, options)
        if (Matcher.score(pattern, [field]).score > 0) compared++
    }
    assert.ok(compared > 30000, `${compared} matches compared`)
}

// A field whose first character is whitespace keeps its full ceiling under minScore.
for (const query of [" a", "\ta"]) {
    const gated = score(query, [query], { minScore: 50 })
    assert.equal(gated.score, 62, JSON.stringify(query))
    assert.deepEqual(gated.positions, [0, 1])
    assert.equal(gated.score, score(query, [query]).score)
}

console.log("matcher: ok")
