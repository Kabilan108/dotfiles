const assert = require("node:assert/strict")
const L = require("./load.js")

// Node's JIT is far faster than QML's V4; qml-load-fixture.qml asserts the
// real budgets. These limits only catch gross regressions.
const BUDGET_MS = 8

// Typing sequences: every prefix of each word, one keystroke at a time.
function typingInputs(words, count) {
    const inputs = []
    for (let sequence = 0; inputs.length < count; sequence++) {
        const word = words[sequence % words.length]
        for (let length = 1; length <= word.length && inputs.length < count; length++) {
            inputs.push(word.slice(0, length))
        }
    }
    return inputs
}

function percentile(sorted, fraction) {
    return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * fraction))]
}

function measure(appCount) {
    const apps = L.syntheticApps(appCount)
    const history = L.History.create(null)
    for (let index = 0; index < 400; index++) {
        history.record("al", "apps:synthetic-" + (index * 7 % appCount), L.NOW - (index % 12) * L.DAY)
    }
    const env = { apps, windows: L.WINDOWS, history, settings: { maxResults: 100 }, now: L.NOW }
    const engine = L.createEngine()
    const prepareStart = process.hrtime.bigint()
    engine.prepare(env)
    const prepareMs = Number(process.hrtime.bigint() - prepareStart) / 1e6

    const words = ["alpha", "studio", "brv", "terminal", "xray", "monitor", "zulu ed", "vic", "charlie 4", "sas"]
    const inputs = typingInputs(words, 400)
    const sequences = new Set(inputs.filter(input => input.length === 1)).size
    for (let warm = 0; warm < 40; warm++) engine.run(inputs[warm], "combi", env)

    const all = []
    const short = []
    let rows = 0
    for (let round = 0; round < 3; round++) {
        for (const input of inputs) {
            const start = process.hrtime.bigint()
            const result = engine.run(input, "combi", env)
            const elapsed = Number(process.hrtime.bigint() - start) / 1e6
            all.push(elapsed)
            if (input.length <= 2) short.push(elapsed)
            rows += result.rows.length
        }
    }
    all.sort((a, b) => a - b)
    short.sort((a, b) => a - b)

    const emptyStart = process.hrtime.bigint()
    engine.run("", "combi", env)
    const emptyMs = Number(process.hrtime.bigint() - emptyStart) / 1e6

    const stats = {
        median: percentile(all, 0.5),
        p95: percentile(all, 0.95),
        max: all[all.length - 1],
        shortP95: percentile(short, 0.95)
    }
    console.log(`perf: ${appCount} apps, ${all.length} keystrokes over ${sequences} first letters: `
        + `median ${stats.median.toFixed(3)} ms, p95 ${stats.p95.toFixed(3)} ms, max ${stats.max.toFixed(3)} ms, `
        + `1-2 char p95 ${stats.shortP95.toFixed(3)} ms; prepare ${prepareMs.toFixed(1)} ms; `
        + `empty query ${emptyMs.toFixed(3)} ms; ${rows} rows`)
    assert.ok(rows > 0)
    assert.equal(sequences, new Set(words.map(word => word.charAt(0))).size, "every sequence is typed")
    return stats
}

// The sequence picker must not depend on how many keystrokes came before.
assert.deepEqual(typingInputs(["ab", "c", "de"], 7), ["a", "ab", "c", "d", "de", "a", "ab"])

for (const appCount of [400, 1500]) {
    const stats = measure(appCount)
    assert.ok(stats.median < BUDGET_MS, `median ${stats.median} ms exceeds ${BUDGET_MS} ms`)
    assert.ok(stats.p95 < 2 * BUDGET_MS, `p95 ${stats.p95} ms exceeds ${2 * BUDGET_MS} ms`)
}
