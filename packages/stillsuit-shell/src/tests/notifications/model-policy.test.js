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

const replaced = Model.replacementSnapshot({ ...notification, summary: "after", expireTimeout: 2500 }, first)
assert.equal(replaced.key, first.key, "replacement preserves identity")
assert.equal(replaced.timestamp, first.timestamp, "replacement preserves arrival")
assert.equal(replaced.outputId, first.outputId, "replacement stays on its arrival output")
assert(Model.snapshotChanged(first, replaced), "replacement-only content is detected")
assert.equal(Policy.durationFor(replaced, {}), 2500, "replacement timeout remains milliseconds")

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
}), 5, 100)
assert.equal(parsed.dnd, true)
assert.equal(parsed.popups.length, 1, "malformed popup records are isolated")
assert.equal(parsed.history.length, 1, "malformed history records are isolated")
assert.equal(parsed.corrupt, true)
assert.equal(Model.parseState("{broken", 5, 100).corrupt, true)

let history = []
for (let index = 0; index < 150; index++)
    history = Model.boundedHistory(history, { ...good, key: String(index), timestamp: index }, 100)
assert.equal(history.length, 100, "history remains bounded during a burst")
assert.equal(history[0].key, "149")
assert.equal(history[99].key, "50")

const persisted = JSON.stringify({ dnd: false, popups: [], history: [first] })
const restarted = Model.parseState(persisted, 5, 100)
assert.equal(restarted.history[0].hints["omarchy-exec"], notification.hints["omarchy-exec"])
assert.equal(typeof restarted.history[0].hints["omarchy-exec"], "string")

console.log("model-policy: ok")
