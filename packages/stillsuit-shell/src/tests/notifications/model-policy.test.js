const assert = require("node:assert/strict")
const Model = require("../../services/NotificationModel.js")
const Policy = require("../../services/NotificationPolicy.js")

const notification = {
    id: 42,
    appName: "fixture",
    appIcon: "fixture",
    summary: "before",
    body: "body",
    urgency: 1,
    expireTimeout: 1234,
    resident: true,
    actions: [
        { identifier: "default", text: "Open" },
        { identifier: "reply", text: "Reply" }
    ],
    hints: {
        "untrusted-command": "touch /tmp/this-must-never-run",
        transient: false,
        value: 62,
        "x-dunst-stack-tag": "volume"
    }
}

const first = Model.snapshotOf(notification, {
    key: "generation-42",
    timestamp: 100,
    outputId: "DP-1"
})
assert.equal(first.expireTimeout, 1234, "requested timeout stays in milliseconds")
assert.deepEqual(first.actions.map(action => action.identifier), ["default", "reply"])
assert.equal(first.hints["untrusted-command"], undefined, "unknown hints are discarded")
assert.equal(first.resident, true)
assert.equal(first.read, undefined, "snapshots carry no read state")
assert.equal(Policy.viewState(first), "info")
assert.equal(Model.progressOf(first), 0.62, "the value hint is a 0-100 progress")
assert.equal(Model.progressOf({ hints: {} }), -1)
assert.equal(Model.progressOf({ hints: { value: 250 } }), 1, "progress clamps")
assert.equal(Model.stackTagOf(first), "volume")
assert.equal(Model.stackTagOf({ hints: { "x-canonical-private-synchronous": "brightness" } }), "brightness")
assert(Model.sameStack(first, { ...first, key: "next" }), "same app and tag continue one card")
assert(!Model.sameStack(first, { ...first, appName: "other" }), "a tag is scoped to its app")
assert(!Model.sameStack({ ...first, hints: {} }, { ...first, hints: {} }), "untagged rows never stack")

const replaced = Model.replacementSnapshot({ ...notification, summary: "after", expireTimeout: 2500 }, first)
assert.equal(replaced.key, first.key, "replacement preserves identity")
assert.equal(replaced.timestamp, first.timestamp, "replacement preserves arrival")
assert.equal(replaced.outputId, first.outputId, "replacement stays on its arrival output")
assert(Model.snapshotChanged(first, replaced), "replacement-only content is detected")
assert.equal(Policy.durationFor(replaced, {}), 2500, "replacement timeout remains milliseconds")

const defaults = Policy.notificationsPolicy({})
assert.equal(defaults.popupLimit, 5)
assert.equal(defaults.deckRowLimit, 8)
assert.equal(defaults.heldLimit, 50)
assert.equal(defaults.hoverGraceMs, 1200)
assert.equal(
    Policy.notificationsPolicy({ notifications: { popupLimit: "invalid" } }).popupLimit,
    5,
    "malformed numeric settings fall back safely"
)

// Cards with buttons stay long enough to reach them; an explicit timeout wins.
const plain = { urgency: 1, expireTimeout: 0, actions: [] }
assert.equal(Policy.durationFor(plain, {}), 5000)
assert.equal(Policy.durationFor({ ...plain, actions: [{ identifier: "default", text: "Open" }] }, {}), 5000,
    "a default action alone is a click, not a button")
assert.equal(Policy.durationFor({ ...plain, actions: [{ identifier: "settings", text: "Settings" }] }, {}), 5000,
    "Chromium's settings button does not count")
assert.equal(Policy.durationFor({ ...plain, actions: [{ identifier: "reply", text: "Reply" }] }, {}), 10000)
assert.equal(Policy.durationFor({ ...plain, expireTimeout: 3000, actions: [{ identifier: "reply", text: "Reply" }] }, {}), 3000)
assert.equal(Policy.durationFor({ ...plain, urgency: 2, actions: [{ identifier: "reply", text: "Reply" }] }, {}), 0)
assert.deepEqual(Policy.buttonActions(notification.actions).map(action => action.identifier), ["reply"])

// Hover resumes with what was left, and at least the grace period.
assert.equal(Policy.resumedDeadline(1100, 1000, 5000, {}), 6200, "100 ms left becomes the 1.2 s grace")
assert.equal(Policy.resumedDeadline(4000, 1000, 5000, {}), 8000, "3 s left stays 3 s")
assert.equal(Policy.resumedDeadline(0, 1000, 5000, {}), 0, "sticky rows stay sticky")

assert.equal(Policy.quietClass({ ...first, urgency: 2 }, true, {}), "bypass")
assert.equal(Policy.quietClass({ ...first, hints: {} }, true, {}), "silenced-retained")
assert.equal(Policy.quietClass({ ...first, hints: { transient: true } }, true, {}), "silenced-ephemeral")
assert.equal(Policy.quietClass(first, true, {}), "silenced-ephemeral", "stacked status cards are not replayed")
assert.equal(Policy.quietClass(first, false, {}), "visible")

assert.equal(Policy.viewState({ ...first, urgency: 2 }), "danger")
assert.equal(Policy.viewState({ ...first, urgency: 0 }), "muted")
assert.equal(Policy.viewState({ ...first, hints: { "x-stillsuit-state": "success" } }), "success")
assert.equal(Policy.viewState({ ...first, hints: { "x-stillsuit-state": "warning" } }), "warning")

assert.match(Policy.sourceTint("app:slack"), /^#[0-9a-f]{6}$/)
assert.equal(Policy.sourceTint("app:slack"), Policy.sourceTint("app:slack"), "a source keeps its colour")
assert.notEqual(Policy.sourceTint("app:slack"), Policy.sourceTint("app:firefox"))
assert.equal(Policy.oklchHex(1, 0, 0), "#ffffff")
assert.equal(Policy.oklchHex(0, 0, 0), "#000000")

assert.equal(Policy.presentationOutput(first, ["DP-1", "DP-2"], "DP-2"), "DP-1")
assert(Policy.shouldPresentOn(first, "DP-1", ["DP-1", "DP-2"], "DP-2"))
assert(!Policy.shouldPresentOn(first, "DP-2", ["DP-1", "DP-2"], "DP-2"))
assert.equal(Policy.presentationOutput(first, ["DP-2"], "DP-2"), "DP-2")

const unsaved = { ...first, outputId: "" }
assert.equal(Policy.presentationOutput(unsaved, ["DP-1", "DP-2"], "DP-2", ["DP-2"]), "DP-1",
    "an avoided focused output yields to the remaining one")
assert.equal(Policy.presentationOutput(first, ["DP-1", "DP-2"], "DP-2", ["DP-1"]), "DP-2",
    "a saved output that is avoided does not pin the banner there")
assert.equal(Policy.presentationOutput(unsaved, ["DP-2"], "DP-2", ["DP-2"]), "DP-2",
    "avoiding the only output changes nothing")
assert.deepEqual(Policy.notificationsPolicy({ notifications: { avoidOutputs: ["DP-4", 7] } }).avoidOutputs,
    ["DP-4", "7"], "avoidOutputs is normalized to strings")
assert.deepEqual(Policy.notificationsPolicy({}).avoidOutputs, [], "avoidOutputs defaults empty")
const variantList = { length: 2, 0: "DP-4", 1: "eDP-1" }
assert.deepEqual(Policy.listValue(variantList), ["DP-4", "eDP-1"], "array-like settings lists are accepted")
assert.deepEqual(Policy.notificationsPolicy({ notifications: { avoidOutputs: variantList } }).avoidOutputs,
    ["DP-4", "eDP-1"], "avoidOutputs survives a QVariantList-shaped value")
assert.deepEqual(Policy.notificationsPolicy({ notifications: { quietBypass: { appNames: { length: 1, 0: "Slack" } } } }).quietBypass.appNames,
    ["Slack"], "quietBypass lists survive a QVariantList-shaped value")
assert.equal(Policy.listValue("DP-4"), null, "strings are not lists")
assert.equal(Policy.listValue({ a: 1 }), null, "plain objects are not lists")

// State: quiet is one indefinite switch; held rows survive a restart.
const day = 24 * 60 * 60 * 1000
const now = 10 * day
const good = { ...first, key: "good", timestamp: now - 1000 }
const limits = { popupRows: 40, held: 50, maxAgeMs: day }
const parsed = Model.parseState(JSON.stringify({
    schemaVersion: 3,
    quiet: true,
    quietSince: now - 5000,
    mutes: { "app:slack": { until: now + 1000, startedAt: now } },
    popups: [good, null, "bad"],
    held: [{ ...good, key: "held" }, { summary: "missing identity" }]
}), limits, now)
assert.equal(parsed.quiet, true)
assert.equal(parsed.quietSince, now - 5000)
assert.equal(parsed.mutes, undefined, "per-source mutes from early schema 3 files are dropped")
assert.equal(parsed.popups.length, 1, "malformed popup records are isolated")
assert.equal(parsed.held.length, 1, "malformed held records are isolated")
assert.equal(parsed.corrupt, true)
assert.equal(Model.parseState("{broken", limits, now).corrupt, true)

// Version 2 files: history and every snooze go.
const migrated = Model.parseState(JSON.stringify({
    schemaVersion: 2,
    snoozes: { "*": { until: now + 1000 }, "app:signal": { until: now + 1000, startedAt: now } },
    popups: [good],
    history: [{ ...good, key: "old-history" }]
}), limits, now)
assert.equal(migrated.quiet, false, "a finite v2 snooze does not become indefinite quiet")
assert.equal(migrated.mutes, undefined)
assert.equal(migrated.held.length, 0, "v2 history is not replayed")
assert.equal(migrated.popups.length, 1)
assert.equal(migrated.corrupt, false)
assert.equal(Model.parseState(JSON.stringify({ dnd: true }), limits, now).quiet, true, "v1 DND carries over")

const old = Model.parseState(JSON.stringify({
    held: [{ ...good, key: "stale", timestamp: now - day - 1 }]
}), limits, now)
assert.equal(old.held.length, 0, "held rows older than a day are dropped")
assert.equal(old.corrupt, false, "age pruning is not state corruption")

const serialized = JSON.parse(Model.serializeState({ quiet: true, quietSince: 5, popups: [first], held: [] }))
assert.equal(serialized.schemaVersion, 3)
assert.equal(serialized.quiet, true)
assert.equal(serialized.history, undefined)
assert.equal(serialized.mutes, undefined)
const restarted = Model.parseState(Model.serializeState({ popups: [], held: [first] }), limits, 200)
assert.equal(restarted.held[0].hints["untrusted-command"], undefined)
assert.equal(restarted.held[0].hints.value, 62)

assert.deepEqual(Model.keysRemoved([{ key: "a" }, { key: "b" }], [{ key: "b" }]), ["a"])

console.log("model-policy: ok")
