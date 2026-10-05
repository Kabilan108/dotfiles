const assert = require("node:assert/strict")
const Model = require("../../plugins/builtin/clipboard/ClipboardModel.js")

const HOUR = 3600 * 1000
const T0 = Date.UTC(2030, 0, 1)
const sha = n => n.toString(16).padStart(64, "0")
// The collector's sha256 prefix of the offered type list.
const SHAPE = "0123456789abcdef"
const OTHER_SHAPE = "fedcba9876543210"
const text = (n, extra) => Object.assign(
    { kind: "text", sha: sha(n), mime: "text/plain;charset=utf-8", bytes: 3, preview: "t" + n, shape: SHAPE },
    extra || {})
const clear = { kind: "clear", shape: SHAPE }
const image = n => ({ kind: "image", sha: sha(n), mime: "image/png", bytes: 10, preview: "" })
const opts = Model.options({})

function apply(state, event, now, options) {
    return Model.applyEvent(state, event, now, options || opts)
}

function feed(events, options) {
    let state = Model.emptyState()
    for (const [event, at] of events)
        state = apply(state, event, at, options).state
    return state
}

// options: defaults, clamping, QVariantList-like lists
{
    assert.equal(opts.maxItems, 200)
    assert.equal(opts.ttlMs, 72 * HOUR)
    assert.equal(opts.purgeWindowMs, 330 * 1000)
    assert.equal(opts.unattributedFirefox, "skip")
    assert.equal(opts.maxTextBytes, 1024 * 1024)
    assert.equal(opts.maxImageBytes, 20 * 1024 * 1024)
    assert.equal(opts.gcGraceSec, 120)
    assert.deepEqual(opts.secretSourcePrefixes, Model.DEFAULT_SECRET_SOURCE_PREFIXES)
    const listLike = { length: 2, 0: "https://a/", 1: "" }
    assert.deepEqual(Model.options({ secretSourcePrefixes: listLike }).secretSourcePrefixes, ["https://a/"])
    assert.deepEqual(Model.options({ secretSourcePrefixes: [] }).secretSourcePrefixes, [])
    assert.equal(Model.options({ maxItems: "abc" }).maxItems, 200)
    assert.equal(Model.options({ maxItems: 0 }).maxItems, 1)
    assert.equal(Model.options({ unattributedFirefox: "record" }).unattributedFirefox, "record")
    assert.equal(Model.options({ unattributedFirefox: "quarantine" }).unattributedFirefox, "skip")
    assert.equal(opts.geckoAppIds, Model.DEFAULT_GECKO_APP_IDS)
    assert.ok(new RegExp(opts.geckoAppIds).test("zen-beta") && !new RegExp(opts.geckoAppIds).test("zenity"))
    assert.equal(Model.options({ geckoAppIds: "^x$" }).geckoAppIds, "^x$")
}

// parseEvent validates shape and drops unknown fields
{
    assert.equal(Model.parseEvent("not json"), null)
    assert.equal(Model.parseEvent(JSON.stringify({ kind: "text", sha: "xyz", mime: "text/plain", bytes: 1 })), null)
    assert.equal(Model.parseEvent(JSON.stringify({ kind: "text", sha: sha(1), mime: "--evil", bytes: 1 })), null)
    assert.equal(Model.parseEvent(JSON.stringify({ kind: "bogus" })), null)
    assert.deepEqual(Model.parseEvent('{"kind":"clear"}'), { kind: "clear", shape: "" })
    assert.deepEqual(Model.parseEvent(JSON.stringify(clear)), clear)
    assert.deepEqual(Model.parseEvent('{"kind":"clear","shape":"../x"}'), { kind: "clear", shape: "" })
    assert.equal(Model.parseEvent(JSON.stringify(text(1, { shape: "XYZ" }))).shape, "")
    assert.deepEqual(Model.parseEvent('{"kind":"skipped","reason":"hint"}'), { kind: "skipped", reason: "hint" })
    const parsed = Model.parseEvent(JSON.stringify(Object.assign(text(1), { quarantined: true, extra: "x" })))
    assert.deepEqual(Object.keys(parsed).sort(), ["bytes", "kind", "mime", "preview", "sha", "shape"])
    assert.ok(Model.parseEvent(JSON.stringify(text(1, { mime: "UTF8_STRING" }))))
}

// dedupe: a repeat moves to the top, keeps `created`, refreshes lastUsed
{
    const state = feed([[text(1), T0], [text(2), T0 + 1000], [text(1, { preview: "new" }), T0 + 2000]])
    assert.deepEqual(state.entries.map(e => e.id), [sha(1), sha(2)])
    assert.equal(state.entries[0].created, T0)
    assert.equal(state.entries[0].lastUsed, T0 + 2000)
    assert.equal(state.entries[0].preview, "new")
    assert.equal(state.lastRecorded, sha(1))
}

// cap: oldest entries are evicted and reported for blob cleanup
{
    const small = Model.options({ maxItems: 3 })
    let state = Model.emptyState()
    let removed = []
    for (let n = 1; n <= 5; n++) {
        const result = apply(state, text(n), T0 + n, small)
        state = result.state
        removed = removed.concat(result.removed)
    }
    assert.deepEqual(state.entries.map(e => e.id), [sha(5), sha(4), sha(3)])
    assert.deepEqual(removed, [sha(1), sha(2)])
    const defaultCap = feed(Array.from({ length: 205 }, (_, n) => [text(n + 1), T0 + n]))
    assert.equal(defaultCap.entries.length, 200)
}

// TTL: expiry at exactly ttl, prune on insert, items hide expired entries
{
    const state = feed([[text(1), T0], [text(2), T0 + HOUR]])
    const before = Model.prune(state.entries, T0 + 72 * HOUR - 1, opts)
    assert.equal(before.entries.length, 2)
    const at = Model.prune(state.entries, T0 + 72 * HOUR, opts)
    assert.deepEqual(at.removed, [sha(1)])
    assert.deepEqual(Model.publicItems(state.entries, T0 + 72 * HOUR, opts, "/b").map(i => i.id), [sha(2)])
    const inserted = apply(state, text(3), T0 + 73 * HOUR)
    assert.deepEqual(inserted.state.entries.map(e => e.id), [sha(3)])
    assert.deepEqual(inserted.removed.sort(), [sha(1), sha(2)].sort())
}

// purge window: strict boundary, only the newest entry, only text
{
    const window = opts.purgeWindowMs
    const base = feed([[text(1), T0], [text(2), T0 + 1000]])
    const inside = apply(base, clear, T0 + 1000 + window - 1)
    assert.equal(inside.changed, true)
    assert.deepEqual(inside.removed, [sha(2)])
    assert.deepEqual(inside.state.entries.map(e => e.id), [sha(1)], "older entry survives")
    const boundary = apply(base, clear, T0 + 1000 + window)
    assert.equal(boundary.changed, false)
    assert.equal(boundary.state.entries.length, 2)

    const second = apply(inside.state, clear, T0 + 1000 + window - 1)
    assert.equal(second.changed, false, "a second clear does not walk down the history")

    const imageNewest = feed([[text(1), T0], [image(2), T0 + 1000]])
    assert.equal(apply(imageNewest, clear, T0 + 2000).changed, false)

    const afterSkip = apply(base, { kind: "skipped", reason: "source" }, T0 + 2000).state
    assert.equal(apply(afterSkip, clear, T0 + 3000).changed, false,
        "a clear after a skipped secret leaves the earlier copy alone")

    const unknown = { entries: base.entries, lastRecorded: null }
    assert.equal(apply(unknown, clear, T0 + 2000).changed, true, "startup purges conservatively")
    const reloaded = Model.parseHistory(Model.serialize(base.entries), T0 + 1500, opts).entries
    assert.equal(reloaded[0].shape, SHAPE, "the capture's shape is persisted")
    assert.equal(apply({ entries: reloaded, lastRecorded: null }, clear, T0 + 2000).changed, true)
    const legacy = JSON.parse(Model.serialize(base.entries))
    delete legacy.entries[0].shape
    const legacyEntries = Model.parseHistory(JSON.stringify(legacy) + "\n", T0 + 1500, opts).entries
    assert.equal(apply({ entries: legacyEntries, lastRecorded: null }, clear, T0 + 2000).changed, false,
        "an entry from before shapes were recorded is never purged")

    const zero = Model.options({ clearPurgeWindowSec: 0 })
    assert.equal(apply(base, clear, T0 + 1000, zero).changed, false)

    const otherOffer = apply(base, { kind: "clear", shape: OTHER_SHAPE }, T0 + 2000)
    assert.equal(otherOffer.changed, false, "an empty read of another offer's types does not purge")
    assert.equal(otherOffer.state.lastRecorded, "", "and it detaches later clears")
    assert.equal(apply(base, { kind: "clear", shape: "" }, T0 + 2000).changed, false,
        "a clear without a shape does not purge")
    const unshaped = feed([[text(1), T0], [text(2, { shape: "" }), T0 + 1000]])
    assert.equal(apply(unshaped, clear, T0 + 2000).changed, false, "an entry captured without a shape is not purged")

    const touched = Model.touch(base, sha(1), T0 + 5000).state
    assert.equal(touched.entries[0].id, sha(1))
    assert.equal(apply(touched, clear, T0 + 6000).changed, false,
        "a history copy does not make an old entry purgeable before it is captured")
}

// clear correlation across the browsers' transient events: a nil
// announcement ("empty" skip) neither purges nor detaches the following clear
{
    const record = Model.options({ unattributedFirefox: "record" })
    const empty = { kind: "skipped", reason: "empty" }
    // Firefox in record mode, as probed: copy, nil, duplicate data, nil, then
    // the extension's zero-byte clear.
    const copied = feed([[text(1), T0], [text(2), T0 + 1000], [empty, T0 + 1100], [text(2), T0 + 1200]], record)
    const announced = apply(copied, empty, T0 + 10000, record)
    assert.equal(announced.changed, false, "a nil event changes nothing")
    assert.equal(announced.state.lastRecorded, sha(2), "a nil event keeps the clear attached")
    const cleared = apply(announced.state, clear, T0 + 10100, record)
    assert.deepEqual([cleared.changed, cleared.removed], [true, [sha(2)]])
    assert.deepEqual(cleared.state.entries.map(e => e.id), [sha(1)])

    // Skip mode: the copy and its clear are both skipped as unattributed.
    const skipped = feed([[text(1), T0], [{ kind: "skipped", reason: "unattributed" }, T0 + 1000],
        [empty, T0 + 1100]])
    assert.equal(skipped.lastRecorded, "", "an unattributed skip detaches later clears")
    assert.equal(apply(skipped, clear, T0 + 2000).changed, false)
    const atStartup = apply(Model.emptyState(), empty, T0)
    assert.equal(atStartup.state.lastRecorded, null, "the startup event leaves the last capture unknown")
}

// clock skew: future timestamps clamp on load; a clear never purges an entry
// captured "after" it
{
    const future = T0 + 5 * HOUR
    const raw = JSON.stringify({ schemaVersion: 1, entries: [
        { sha: sha(1), kind: "text", mime: "text/plain", bytes: 1, preview: "a",
            created: future, lastUsed: future, captured: future, shape: SHAPE }
    ] })
    const loaded = Model.parseHistory(raw, T0, opts).entries[0]
    assert.deepEqual([loaded.created, loaded.lastUsed, loaded.captured], [T0, T0, T0])
    assert.equal(Model.parseHistory(raw, T0, opts).dirty, true, "a clamped history is written back")
    assert.equal(Model.isExpired(loaded, T0 + 72 * HOUR, opts), true, "a clamped entry still expires on time")

    const ahead = { entries: [Object.assign({}, loaded, { captured: T0 + 1000 })], lastRecorded: sha(1) }
    assert.equal(apply(ahead, clear, T0, opts).changed, false, "negative age is not purge-eligible")
    assert.equal(apply(ahead, clear, T0 + 1000, opts).changed, true, "zero age is")
}

// expiry: isExpired gates copy; touch is a separate step the service takes
// only after the copy succeeded
{
    const state = feed([[text(1), T0], [text(2), T0 + 1000]])
    assert.equal(Model.isExpired(state.entries[1], T0 + 72 * HOUR - 1, opts), false)
    assert.equal(Model.isExpired(state.entries[1], T0 + 72 * HOUR, opts), true)
    const touched = Model.touch(state, sha(1), T0 + 2000)
    assert.equal(touched.entry.lastUsed, T0 + 2000)
    assert.equal(state.entries[1].lastUsed, T0, "touch does not mutate its input")
}

// timers: TTL wakes at most every 10 minutes
{
    assert.equal(Model.MIN_TIMER_MS, 10 * 60 * 1000)
    assert.equal(Model.nextExpiryAt([], opts), 0)
    const state = feed([[text(1), T0], [text(2), T0 + 1000]])
    assert.equal(Model.nextExpiryAt(state.entries, opts), T0 + 72 * HOUR)
    assert.equal(Model.timerDelay(T0 + 1000, T0, 0), Model.MIN_TIMER_MS, "an imminent expiry waits for the batch")
    assert.equal(Model.timerDelay(T0 + 9 * 60 * 1000, T0, 0), Model.MIN_TIMER_MS)
    assert.equal(Model.timerDelay(T0 - 5000, T0, 0), Model.MIN_TIMER_MS)
    assert.equal(Model.timerDelay(T0 + 72 * HOUR, T0, 0), Model.MAX_TIMER_MS)
    assert.equal(Model.timerDelay(T0 + 30 * 60 * 1000, T0, 0), 30 * 60 * 1000)
    const jittered = Model.timerDelay(T0 + 10 * 60 * 1000, T0, 1)
    assert.ok(jittered > 10 * 60 * 1000 && jittered <= 10 * 60 * 1000 + 5000)
}

// history round trip and corrupt-file recovery
{
    const state = feed([[text(1), T0], [image(2), T0 + 1000]])
    const raw = Model.serialize(state.entries)
    const parsed = Model.parseHistory(raw, T0 + 2000, opts)
    assert.equal(parsed.corrupt, false)
    assert.equal(parsed.dirty, false, "an unchanged history is not rewritten")
    assert.deepEqual(parsed.entries, state.entries)
    assert.equal(Model.parseHistory('{"schemaVersion":1,"entries":[]}\n', T0, opts).dirty, false,
        "the collector's initial history is already normal")
    const legacy = JSON.parse(raw)
    legacy.entries[0].unattributed = true
    assert.equal(Model.parseHistory(JSON.stringify(legacy) + "\n", T0 + 2000, opts).dirty, true,
        "fields this version drops are written away")

    for (const bad of ["{not json", "[]", '{"schemaVersion":2,"entries":[]}', '{"schemaVersion":1}', "null"]) {
        const result = Model.parseHistory(bad, T0, opts)
        assert.equal(result.corrupt, true, bad)
        assert.deepEqual(result.entries, [], bad)
    }
    assert.deepEqual(Model.parseHistory("", T0, opts),
        { entries: [], removed: [], pendingRemovals: [], corrupt: false, dirty: false })

    const mixed = JSON.stringify({ schemaVersion: 1, entries: [
        { sha: sha(1), kind: "text", mime: "text/plain", bytes: 1, preview: "a", lastUsed: T0 },
        { sha: "../../etc/passwd", kind: "text", mime: "text/plain", bytes: 1, lastUsed: T0 },
        { sha: sha(3), kind: "text", mime: "text/plain", bytes: 1, lastUsed: T0 + 5 },
        { sha: sha(1), kind: "text", mime: "text/plain", bytes: 1, lastUsed: T0 - 5 },
        { sha: sha(4), kind: "video", mime: "video/mp4", bytes: 1, lastUsed: T0 },
        { sha: sha(5), kind: "text", mime: "text/plain", bytes: 1, lastUsed: T0 - 80 * HOUR }
    ] })
    const recovered = Model.parseHistory(mixed, T0 + 10, opts)
    assert.equal(recovered.corrupt, true)
    assert.equal(recovered.dirty, true)
    assert.deepEqual(recovered.entries.map(e => e.id), [sha(3), sha(1)])
    assert.deepEqual(recovered.removed, [sha(5)])
}

// pending removals survive in the history until `rm` succeeds
{
    const state = feed([[text(1), T0]])
    const pending = [{ shas: [sha(7), sha(8)], before: T0 - 50 }, { shas: [sha(9)], before: T0 }]
    const raw = Model.serialize(state.entries, pending)
    const parsed = Model.parseHistory(raw, T0 + 10, opts)
    assert.deepEqual(parsed.pendingRemovals, pending)
    assert.equal(parsed.dirty, false)
    assert.equal(JSON.parse(Model.serialize(state.entries, [])).pendingRemovals, undefined)

    const messy = Model.normalizeRemovals([
        { shas: [sha(7), "../x", sha(7)], before: T0 + HOUR },
        { shas: [], before: T0 },
        { shas: [sha(8)], before: "soon" },
        null,
        { shas: { length: 1, 0: sha(9) }, before: T0 - 1 }
    ], T0)
    assert.deepEqual(messy, [{ shas: [sha(7)], before: T0 }, { shas: [sha(9)], before: T0 - 1 }],
        "invalid shas and batches are dropped; a future decision time is clamped to now")
    const doc = JSON.parse(raw)
    doc.pendingRemovals[0].before = T0 + HOUR
    assert.equal(Model.parseHistory(JSON.stringify(doc) + "\n", T0 + 10, opts).dirty, true)
}

// pending removals are merged, never dropped: each sha stays queued once,
// under its latest decision time
{
    const many = []
    for (let n = 0; n < 100; n++)
        many.push({ shas: [sha(1000 + n)], before: T0 - 1000 + n })
    const loaded = Model.normalizeRemovals(many, T0)
    assert.equal([].concat(...loaded.map(b => b.shas)).length, 100, "batches beyond 64 survive a restart")

    const overlapping = Model.normalizeRemovals([
        { shas: [sha(1), sha(2)], before: T0 - 30 },
        { shas: [sha(2), sha(3)], before: T0 - 10 },
        { shas: [sha(3)], before: T0 - 20 }
    ], T0)
    assert.deepEqual(overlapping, [{ shas: [sha(1)], before: T0 - 30 }, { shas: [sha(2), sha(3)], before: T0 - 10 }])

    let queue = []
    for (let n = 0; n < 300; n++)
        queue = Model.enqueueRemoval(queue, [sha(n % 50)], T0 + n)
    assert.equal(queue.length, 50, "repeated removals of the same blobs do not grow the queue")
    assert.deepEqual(queue[49], { shas: [sha(49)], before: T0 + 299 })
    queue = Model.enqueueRemoval([{ shas: [sha(1)], before: T0 }], [sha(2), sha(2), "bad"], T0)
    assert.deepEqual(queue, [{ shas: [sha(1), sha(2)], before: T0 }], "same decision time merges")
}

// a history read back from disk is checked by shas and decision times
{
    const state = feed([[text(1), T0], [text(2), T0 + 1]])
    const pending = [{ shas: [sha(7)], before: T0 }]
    const raw = Model.serialize(state.entries, pending)
    assert.equal(Model.historyMatches(raw, state.entries, pending), true)
    assert.equal(Model.historyMatches(raw.replace('"t2"', '"\\ufffd"'), state.entries, pending), true)
    assert.equal(Model.historyMatches(raw, state.entries.slice(1), pending), false, "a removed entry is still on disk")
    assert.equal(Model.historyMatches(raw, state.entries, []), false, "the removal intent is not on disk")
    assert.equal(Model.historyMatches(Model.serialize(state.entries, []), state.entries, pending), false)
    assert.equal(Model.historyMatches("", state.entries, pending), false)
    assert.equal(Model.historyMatches("{truncated", state.entries, pending), false)
}

// remove, touch and public item shape
{
    const state = feed([[text(1), T0], [image(2), T0 + 1000]])
    const removed = Model.remove(state, sha(1))
    assert.deepEqual(removed.removed, [sha(1)])
    assert.deepEqual(Model.clearAll(state).removed, [sha(2), sha(1)])
    assert.equal(Model.remove(state, "missing").changed, false)
    assert.equal(Model.touch(state, "missing", T0).entry, null)
    const items = Model.publicItems(state.entries, T0 + 2000, opts, "/state/clipboard/blobs")
    assert.deepEqual(Object.keys(items[0]).sort(),
        ["bytes", "created", "id", "kind", "lastUsed", "mime", "path", "preview"])
    assert.equal(items[0].path, "/state/clipboard/blobs/" + sha(2))
    assert.equal(items[1].path, "", "text items do not expose a blob path")
    assert.equal(Model.find(state, sha(2)).kind, "image")
}

// workbench fixture items are coerced to the public shape
{
    const items = Model.modelItems([{ id: "a", kind: "text", preview: "hello", bytes: "5" }, { kind: "image", path: "/p" }])
    assert.deepEqual(items[0], { id: "a", kind: "text", mime: "text/plain;charset=utf-8", bytes: 5,
        preview: "hello", created: 0, lastUsed: 0, path: "" })
    assert.equal(items[1].path, "/p")
    assert.deepEqual(Model.modelItems(null), [])
}

// focus settle option for the GTK3 attribution rule
{
    assert.equal(opts.focusSettleMs, 2000)
    assert.equal(Model.options({ focusSettleMs: 500 }).focusSettleMs, 500)
    assert.equal(Model.options({ focusSettleMs: -1 }).focusSettleMs, 0)
    assert.equal(Model.options({ focusSettleMs: "soon" }).focusSettleMs, 2000)
    assert.equal(Model.options({ focusSettleMs: 1e9 }).focusSettleMs, 60000)
}

// gc follow-up: at the earliest eligibility, at most one per ten minutes
{
    const MIN = 60 * 1000
    const at = (reply, now, last) => Model.gcFollowUpAt(reply, now, last || 0, 120)
    assert.equal(at({ ok: true, removed: 3, deferred: 0 }, T0), 0)
    assert.equal(at(null, T0), 0)
    assert.equal(at({ deferred: 1, nextEligibleMs: T0 + 10 * MIN }, T0), T0 + 10 * MIN + 1000,
        "a staging file 10 minutes from eligible is swept then, not after the 120 s grace")
    assert.equal(at({ deferred: 1, nextEligibleMs: T0 + 30000 }, T0), T0 + 31000)
    assert.equal(at({ deferred: 1, nextEligibleMs: T0 - 5000 }, T0), T0 + 1000, "already eligible: soon")
    assert.equal(at({ deferred: 2 }, T0), T0 + 121000, "without nextEligibleMs: after the grace")
    assert.equal(at({ deferred: 1, nextEligibleMs: T0 + 500 * HOUR }, T0), T0 + Model.MAX_TIMER_MS)
    assert.equal(at({ deferred: 1, nextEligibleMs: T0 + 2000 }, T0, T0 - 30000), T0 - 30000 + Model.GC_FOLLOW_UP_GAP_MS,
        "the next follow-up waits ten minutes after the previous one")
    // A file that never ages (its mtime keeps moving) wakes the sweep at
    // most once per ten minutes.
    let now = T0
    let last = 0
    const wakes = []
    for (let run = 0; run < 6; run++) {
        const wake = at({ deferred: 1, nextEligibleMs: now + 1500 }, now, last)
        wakes.push(wake)
        last = wake
        now = wake
    }
    for (let index = 1; index < wakes.length; index++)
        assert.ok(wakes[index] - wakes[index - 1] >= Model.GC_FOLLOW_UP_GAP_MS, "follow-ups " + index)
}

// gc keeps the union of the live and the durable shas
{
    assert.deepEqual(Model.union([sha(1), sha(2)], [sha(2), sha(3)]), [sha(1), sha(2), sha(3)])
    assert.deepEqual(Model.union([], []), [])
}

console.log("clipboard model tests ok")
