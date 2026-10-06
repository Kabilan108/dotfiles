const assert = require("node:assert/strict")
const { History, DAY, NOW } = require("./load.js")

// Boost: max((10 - days) * count, 1) / (1 + |stored length - query length|).
{
    const history = History.create(null)
    assert.equal(history.boost("obs", "apps:obsidian", NOW), 0, "unknown items get nothing")
    history.record("obs", "apps:obsidian", NOW)
    history.record("obs", "apps:obsidian", NOW)
    assert.equal(history.boost("obs", "apps:obsidian", NOW), 20)
    assert.equal(history.boost("OBS ", "apps:obsidian", NOW), 20, "queries are normalised")
    assert.equal(history.boost("ob", "apps:obsidian", NOW), 10, "length difference of 1 halves it")
    assert.equal(history.boost("obsid", "apps:obsidian", NOW), 20 / 3)
    assert.equal(history.boost("xyz", "apps:obsidian", NOW), 0, "unrelated queries get nothing")
    assert.equal(history.boost("", "apps:obsidian", NOW), 0)
}

// Decay over days, floor of 1, count capped at 10.
{
    const history = History.create(null)
    history.record("fi", "apps:firefox", NOW)
    history.record("fi", "apps:firefox", NOW)
    history.record("fi", "apps:firefox", NOW)
    assert.equal(history.boost("fi", "apps:firefox", NOW), 30)
    assert.equal(history.boost("fi", "apps:firefox", NOW + 1 * DAY), 27)
    assert.equal(history.boost("fi", "apps:firefox", NOW + 5 * DAY + 3600000), 15, "partial days round down")
    assert.equal(history.boost("fi", "apps:firefox", NOW + 9 * DAY), 3)
    assert.equal(history.boost("fi", "apps:firefox", NOW + 10 * DAY), 1, "never below 1")
    assert.equal(history.boost("fi", "apps:firefox", NOW + 400 * DAY), 1)
    assert.equal(history.boost("fi", "apps:firefox", NOW - 2 * DAY), 30, "clock skew counts as today")
    for (let index = 0; index < 20; index++) history.record("fi", "apps:firefox", NOW)
    assert.equal(history.boost("fi", "apps:firefox", NOW), 100, "count caps at 10")
    assert.equal(history.toJSON().records[0].count, 10)
}

// Empty-query rank: frequency across queries, decayed by the latest use.
{
    const history = History.create(null)
    history.record("a", "apps:a", NOW - 3 * DAY)
    history.record("b", "apps:a", NOW - 1 * DAY)
    history.record("c", "apps:b", NOW)
    history.record("x", "apps:old", NOW - 40 * DAY)
    const rank = key => history.emptyQueryRank(key, NOW)
    assert.ok(rank("apps:a") > rank("apps:b"), "two uses a day ago beat one today")
    assert.ok(rank("apps:b") > rank("apps:old"))
    assert.ok(rank("apps:old") > 0)
    assert.equal(rank("apps:never"), 0)
    history.record("d", "apps:b", NOW)
    assert.ok(rank("apps:b") > rank("apps:a"), "tables refresh after a record")
}

// Serialisation round trip.
{
    const history = History.create(null)
    history.record("obs", "apps:obsidian", NOW)
    history.record("gh", "apps:ghostty", NOW - DAY)
    const json = JSON.parse(JSON.stringify(history))
    assert.equal(json.version, 1)
    assert.deepEqual(json.records, [
        { query: "obs", key: "apps:obsidian", count: 1, lastUsed: NOW },
        { query: "gh", key: "apps:ghostty", count: 1, lastUsed: NOW - DAY }
    ])
    const restored = History.create(json, NOW)
    assert.deepEqual(restored.toJSON(), json)
    assert.deepEqual(History.create(JSON.stringify(json), NOW).toJSON(), json, "accepts the file text too")
    assert.equal(History.create(history), history, "an instance passes through")
}

// Corrupt or foreign input starts empty; bad records are dropped one by one.
{
    const corrupt = [
        undefined, null, "", "{", "null", "[]", "42", "\"text\"", { version: 2, records: [] },
        { version: "1", records: [] }, { records: [] }, { version: 1 }, { version: 1, records: {} },
        Buffer.from([0x0e, 0xff, 0x81]).toString("latin1")
    ]
    for (const input of corrupt) {
        const history = History.create(input)
        assert.equal(history.size(), 0, `starts empty for ${JSON.stringify(input)}`)
        assert.equal(history.boost("a", "b", NOW), 0)
        assert.deepEqual(history.toJSON(), { version: 1, records: [] })
    }
    const mixed = History.create({
        version: 1,
        records: [
            { query: "ok", key: "apps:ok", count: 4, lastUsed: NOW },
            { query: "ok", key: "", count: 1, lastUsed: NOW },
            { query: 5, key: "apps:x", count: 1, lastUsed: NOW },
            { query: "x", key: "apps:x", count: "lots", lastUsed: NOW },
            { query: "x", key: "apps:x", count: 1, lastUsed: -5 },
            { query: "x", key: "apps:x", count: 0, lastUsed: NOW },
            { query: "big", key: "apps:big", count: 999, lastUsed: NOW },
            null,
            "string"
        ]
    }, NOW)
    assert.equal(mixed.size(), 2)
    assert.equal(mixed.boost("ok", "apps:ok", NOW), 40)
    assert.equal(mixed.boost("big", "apps:big", NOW), 100, "counts are clamped on load")
}

// Bounded to 2,000 records, oldest evicted.
{
    const history = History.create(null)
    for (let index = 0; index < History.MAX_RECORDS + 25; index++) {
        history.record("q" + index, "apps:item" + index, NOW + index)
    }
    assert.equal(history.size(), History.MAX_RECORDS)
    assert.equal(history.boost("q0", "apps:item0", NOW + 3000), 0, "the oldest record is gone")
    assert.ok(history.boost("q2024", "apps:item2024", NOW + 3000) > 0)

    const records = []
    for (let index = 0; index < 2600; index++) records.push({ query: "q" + index, key: "k" + index, count: 1, lastUsed: NOW + index })
    const loaded = History.create({ version: 1, records }, NOW)
    assert.equal(loaded.size(), History.MAX_RECORDS, "loading a larger file keeps the newest")
    assert.equal(loaded.boost("q2599", "k2599", NOW + 3000) > 0, true)
    assert.equal(loaded.boost("q0", "k0", NOW + 3000), 0)
}

// Remove, clear and revision tracking.
{
    const history = History.create(null)
    const start = history.revision
    history.record("a", "apps:a", NOW)
    history.record("ab", "apps:a", NOW)
    history.record("a", "apps:b", NOW)
    assert.equal(history.revision, start + 3)
    assert.equal(history.remove("apps:a"), true)
    assert.equal(history.size(), 1)
    assert.equal(history.boost("a", "apps:a", NOW), 0)
    assert.equal(history.remove("apps:missing"), false)
    history.clear()
    assert.equal(history.size(), 0)
    assert.equal(history.record("a", "", NOW), false, "empty keys are refused")
    assert.equal(history.record("a", "__proto__", NOW), true, "prototype-ish keys are plain data")
    assert.equal(history.boost("a", "__proto__", NOW), 10)
}

// Timestamps: non-finite, non-positive and far-future stamps are dropped on
// load; near-future ones rank as now.
{
    const stamps = [NaN, "soon", -1, 0, NOW + 2 * DAY, NOW + 3600000, NOW - DAY]
    const records = stamps.map((lastUsed, index) => ({ query: "q", key: "apps:k" + index, count: 1, lastUsed }))
    const loaded = History.create({ version: 1, records }, NOW)
    assert.deepEqual(loaded.toJSON().records.map(record => record.key).sort(), ["apps:k5", "apps:k6"])
    assert.equal(loaded.boost("q", "apps:k5", NOW), 10, "a near-future stamp counts as now")
    assert.equal(loaded.boost("q", "apps:k6", NOW), 9)
}

// The empty-query recency tie-breaker never outweighs frequency.
{
    const history = History.create(null)
    history.record("a", "apps:frequent", NOW - DAY)
    history.record("a", "apps:frequent", NOW - DAY)
    history.record("b", "apps:future", NOW + 1e20)
    history.record("c", "apps:recent", NOW)
    const rank = key => history.emptyQueryRank(key, NOW)
    assert.ok(rank("apps:frequent") > rank("apps:future"), `${rank("apps:frequent")} > ${rank("apps:future")}`)
    assert.ok(rank("apps:future") - 10 <= 0.5, "a future stamp ranks as now")
    assert.ok(rank("apps:recent") > 10 && rank("apps:recent") <= 10.5)
    history.record("d", "apps:older", NOW - 3600000)
    assert.ok(rank("apps:recent") > rank("apps:older"), "recency still breaks ties")
}

console.log("history: ok")
