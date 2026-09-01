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
    actions: [
        { identifier: "default", text: "Open" },
        { identifier: "reply", text: "Reply" }
    ],
    hints: {
        "omarchy-exec": "touch /tmp/this-must-never-run",
        transient: false
    }
}

const first = Model.snapshotOf(notification, {
    key: "generation-42",
    timestamp: 100,
    outputId: "DP-1"
})
assert.equal(first.expireTimeout, 1234, "requested timeout stays in milliseconds")
assert.deepEqual(first.actions.map(action => action.identifier), ["default", "reply"])
assert.equal(first.hints["omarchy-exec"], "touch /tmp/this-must-never-run")
assert.equal(first.read, false, "new notifications start unread")
assert.equal(Policy.viewState(first), "unread")

const replaced = Model.replacementSnapshot({ ...notification, summary: "after", expireTimeout: 2500 }, first)
assert.equal(replaced.key, first.key, "replacement preserves identity")
assert.equal(replaced.timestamp, first.timestamp, "replacement preserves arrival")
assert.equal(replaced.outputId, first.outputId, "replacement stays on its arrival output")
assert(Model.snapshotChanged(first, replaced), "replacement-only content is detected")
assert.equal(Policy.durationFor(replaced, {}), 2500, "replacement timeout remains milliseconds")
assert.equal(
    Policy.notificationsPolicy({ notifications: { historyLimit: 500 } }).historyLimit,
    100,
    "settings cannot raise the persistent history cap above 100"
)
assert.equal(
    Policy.notificationsPolicy({ notifications: { popupLimit: "invalid" } }).popupLimit,
    5,
    "malformed numeric settings fall back safely"
)

assert.equal(Policy.dndClass({ ...first, urgency: 2 }, true, {}), "bypass")
assert.equal(Policy.dndClass(first, true, {}), "silenced-retained")
assert.equal(Policy.dndClass({ ...first, hints: { transient: true } }, true, {}), "silenced-ephemeral")
assert.equal(Policy.dndClass(first, false, {}), "visible")

assert.equal(Policy.presentationOutput(first, ["DP-1", "DP-2"], "DP-2"), "DP-1")
assert(Policy.shouldPresentOn(first, "DP-1", ["DP-1", "DP-2"], "DP-2"))
assert(!Policy.shouldPresentOn(first, "DP-2", ["DP-1", "DP-2"], "DP-2"))
assert.equal(Policy.presentationOutput(first, ["DP-2"], "DP-2"), "DP-2")

const good = { ...first, key: "good" }
const parsed = Model.parseState(JSON.stringify({
    dnd: true,
    popups: [good, null, "bad"],
    history: [{ ...good, key: "history" }, { summary: "missing identity" }]
}), 5, 100, 100)
assert.equal(parsed.dnd, true)
assert.equal(parsed.popups.length, 1, "malformed popup records are isolated")
assert.equal(parsed.history.length, 1, "malformed history records are isolated")
assert.equal(parsed.corrupt, true)
assert.equal(Model.parseState("{broken", 5, 100).corrupt, true)

const readAtOpen = Model.markRead([first], [first.key], 150)
const arrivedAfterOpen = { ...first, key: "after-open", timestamp: 151 }
assert.equal(readAtOpen[0].read, true)
assert.equal(readAtOpen[0].readAt, 150)
assert.equal(
    Model.unreadCount([], [arrivedAfterOpen, ...readAtOpen], 100),
    1,
    "an arrival after the center-open snapshot remains unread"
)
assert.equal(Policy.viewState(readAtOpen[0]), "info")
assert.equal(Policy.viewState({ ...readAtOpen[0], urgency: 2 }), "danger")
assert.equal(Policy.viewState({ ...readAtOpen[0], urgency: 0 }), "muted")
assert.equal(Policy.viewState({
    ...readAtOpen[0],
    hints: { "x-stillsuit-state": "success" }
}), "success")
assert.equal(Policy.viewState({
    ...readAtOpen[0],
    hints: { "x-stillsuit-state": "warning" }
}), "warning")

let history = []
for (let index = 0; index < 150; index++)
    history = Model.boundedHistory(history, { ...good, key: String(index), timestamp: index }, 100)
assert.equal(history.length, 100, "history remains bounded during a burst")
assert.equal(history[0].key, "149")
assert.equal(history[99].key, "50")

const day = 24 * 60 * 60 * 1000
const pruningNow = 2 * day
const agePruned = Model.pruneHistory([
    { ...good, key: "inside", timestamp: pruningNow - day },
    { ...good, key: "outside", timestamp: pruningNow - day - 1 }
], pruningNow, day, 100)
assert.deepEqual(agePruned.map(row => row.key), ["inside"], "history prunes after 24 hours")

const popupRows = Array.from({ length: 5 }, (_, index) => ({
    ...good,
    key: `popup-${index}`,
    timestamp: 1000 - index
}))
const historyRows = Array.from({ length: 100 }, (_, index) => ({
    ...good,
    key: `history-${index}`,
    timestamp: 900 - index
}))
assert.equal(
    Model.retainedHistory(popupRows, historyRows, 100, 1000, day).length,
    95,
    "live popups and persistent history share the 100-item cap"
)

const previousHistory = [
    { ...good, key: "newer", timestamp: 2 },
    { ...good, key: "oldest", timestamp: 1 }
]
const nextHistory = Model.boundedHistory(
    previousHistory,
    { ...good, key: "newest", timestamp: 3 },
    2
)
assert.deepEqual(
    Model.historyKeysRemoved(previousHistory, nextHistory),
    ["oldest"],
    "bounded history reports the key whose final row was evicted"
)

const persisted = JSON.stringify({ dnd: false, popups: [], history: [first] })
const restarted = Model.parseState(persisted, 5, 100, 100)
assert.equal(restarted.history[0].hints["omarchy-exec"], notification.hints["omarchy-exec"])
assert.equal(typeof restarted.history[0].hints["omarchy-exec"], "string")

console.log("model-policy: ok")
