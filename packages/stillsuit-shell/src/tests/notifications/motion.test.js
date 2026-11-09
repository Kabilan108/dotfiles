const assert = require("node:assert/strict")
const Motion = require("../../plugins/builtin/notifications/Motion.js")

const close = (actual, expected, tolerance, message) =>
    assert(Math.abs(actual - expected) <= tolerance, `${message}: ${actual} vs ${expected}`)

// Rune's mapping: ω = 2π / duration, ζ = 1 − bounce (bounce ≥ 0).
close(Motion.omega({ duration: 0.5 }), 4 * Math.PI, 1e-9, "omega")
close(Motion.zeta({ bounce: 0.12 }), 0.88, 1e-9, "underdamped zeta")
close(Motion.zeta({ bounce: -0.5 }), 2, 1e-9, "overdamped zeta")

for (const spring of [Motion.LAYOUT, Motion.ENTER, Motion.EXIT, { duration: 0.4, bounce: -0.4 }]) {
    const solved = Motion.solve(spring, -100, 250)
    const [x0, v0] = Motion.sample(solved, 0)
    close(x0, -100, 1e-6, "starts at its offset")
    close(v0, 250, 1e-6, "starts at its velocity")
    const [late] = Motion.sample(solved, spring.duration * 4)
    close(late, 0, 0.5, "settles onto the target")

    // The sampled velocity is the derivative of the sampled position.
    const t = spring.duration / 3
    const h = 1e-5
    const slope = (Motion.sample(solved, t + h)[0] - Motion.sample(solved, t - h)[0]) / (2 * h)
    close(Motion.sample(solved, t)[1], slope, 0.05, "velocity matches position")
}

// A bouncy spring overshoots; a critically damped one from rest does not.
const bouncy = Motion.solve({ duration: 0.4, bounce: 0.3 }, -1, 0)
const peak = Math.max(...Array.from({ length: 200 }, (_, i) => Motion.sample(bouncy, i / 200)[0]))
assert(peak > 0.01, "a bouncy spring overshoots")
const settle = Motion.solve(Motion.ENTER, -1, 0)
const settlePeak = Math.max(...Array.from({ length: 200 }, (_, i) => Motion.sample(settle, i / 200)[0]))
assert(settlePeak <= 1e-9, "the critically damped enter spring never overshoots")

assert.deepEqual(Motion.sample(Motion.solve(Motion.LAYOUT, 0, 0), 0.1), [0, 0], "rest stays at rest")

// Rune's numbers: Hokum's card spring and the SETTLE presence pair.
assert.deepEqual(Motion.LAYOUT, { duration: 0.38, bounce: 0.12 })
assert.deepEqual(Motion.ENTER, { duration: 0.30, bounce: 0 })
assert.deepEqual(Motion.EXIT, { duration: 0.24, bounce: 0 })
assert.equal(Motion.ENTER_OFFSET, 48)
assert.equal(Motion.ENTER_SCALE, 0.97)

// Presence keeps a removed key in place, flagged, until the view drops it.
const live = keys => keys.map(key => ({ key, exiting: false }))
assert.deepEqual(Motion.merge([], ["a", "b"]), live(["a", "b"]))
assert.deepEqual(Motion.merge(live(["a", "b", "c"]), ["a", "c"]), [
    { key: "a", exiting: false },
    { key: "b", exiting: true },
    { key: "c", exiting: false }
], "a removed middle key stays between its neighbours")
assert.deepEqual(Motion.merge(live(["a", "b"]), ["new", "a", "b"]).map(entry => entry.key),
    ["new", "a", "b"], "arrivals take their place in the live order")
assert.deepEqual(Motion.merge(live(["a", "b"]), []), [
    { key: "a", exiting: true },
    { key: "b", exiting: true }
], "everything leaving keeps its order")
const leaving = Motion.merge(live(["a", "b"]), ["b"])
assert.deepEqual(Motion.merge(leaving, ["a", "b"]), live(["a", "b"]), "a key that returns is live again")
assert.deepEqual(Motion.merge(leaving, ["c", "b"]), [
    { key: "a", exiting: true },
    { key: "c", exiting: false },
    { key: "b", exiting: false }
], "a leaving key keeps its slot ahead of later arrivals")
assert.deepEqual(Motion.drop(leaving, "a"), live(["b"]))
assert.deepEqual(Motion.drop(leaving, "b"), leaving, "drop never removes a live key")
assert(Motion.sameEntries(leaving, Motion.merge(leaving, ["b"])))

console.log("motion: ok")
