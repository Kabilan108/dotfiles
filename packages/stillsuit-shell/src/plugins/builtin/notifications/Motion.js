// Springs described by perceptual duration and bounce, sampled in closed form
// so a retarget starts from the exact position and velocity. The math and the
// tokens follow Rune's rune-motion (crates/rune-motion/src/{spring,layer,
// tokens}.rs at e5a6431), the motion system Hokum's cards are drawn with.

// Hokum's card restack spring, and Rune's SETTLE pair for presence.
var LAYOUT = { duration: 0.38, bounce: 0.12 }
var ENTER = { duration: 0.30, bounce: 0 }
var EXIT = { duration: 0.24, bounce: 0 }
var SNAP = { duration: 0.25, bounce: 0 }

// Hokum's slide entrance: 48 pt in from the screen edge, faded, at 0.97.
var ENTER_OFFSET = 48
var ENTER_SCALE = 0.97

// ω = 2π / duration; ζ = 1 − bounce, or 1 / (1 + bounce) when overdamped.
function omega(spring) {
    return 2 * Math.PI / Math.max(0.001, Number(spring.duration))
}

function zeta(spring) {
    var bounce = Number(spring.bounce || 0)
    return bounce >= 0 ? 1 - bounce : 1 / (1 + bounce)
}

// Coefficients for leaving `offset` (position − target) with velocity `v0`.
function solve(spring, offset, v0) {
    var w = omega(spring)
    var z = zeta(spring)
    var a = offset
    if (offset === 0 && v0 === 0) return { kind: "rest" }
    if (Math.abs(z - 1) < 1e-4) {
        var b = v0 + w * a
        return { kind: "critical", c: [a, b, b - w * a, -w * b, w] }
    }
    if (z < 1) {
        var sigma = z * w
        var wd = w * Math.sqrt(1 - z * z)
        var bu = (v0 + sigma * a) / wd
        return { kind: "under", c: [a, bu, bu * wd - sigma * a, -a * wd - sigma * bu, sigma, wd] }
    }
    var root = Math.sqrt(z * z - 1)
    var r1 = -w * (z - root)
    var r2 = -w * (z + root)
    var c1 = (v0 - r2 * a) / (r1 - r2)
    return { kind: "over", c: [c1, a - c1, r1, r2] }
}

// [offset, velocity] at `tau` seconds into the solved segment.
function sample(solved, tau) {
    var c = solved.c
    var t = Math.max(0, tau)
    if (solved.kind === "critical") {
        var ec = Math.exp(-c[4] * t)
        return [(c[0] + c[1] * t) * ec, (c[2] + c[3] * t) * ec]
    }
    if (solved.kind === "under") {
        var eu = Math.exp(-c[4] * t)
        var s = Math.sin(c[5] * t)
        var co = Math.cos(c[5] * t)
        return [eu * (c[0] * co + c[1] * s), eu * (c[2] * co + c[3] * s)]
    }
    if (solved.kind === "over") {
        var e1 = Math.exp(c[2] * t)
        var e2 = Math.exp(c[3] * t)
        return [c[0] * e1 + c[1] * e2, c[0] * c[2] * e1 + c[1] * c[3] * e2]
    }
    return [0, 0]
}

// Presence: the rendered list keeps a removed key, flagged as exiting, at its
// old place until its exit animation ends and the view drops it. A key that
// comes back before then is live again in the same delegate.
function merge(rendered, keys) {
    var previous = Array.isArray(rendered) ? rendered : []
    var current = Array.isArray(keys) ? keys.map(String) : []
    var live = {}
    for (var index = 0; index < current.length; index++) live[current[index]] = true

    var result = current.map(function(key) { return { key: key, exiting: false } })
    var placed = {}
    for (var resultIndex = 0; resultIndex < result.length; resultIndex++)
        placed[result[resultIndex].key] = true

    // Each departed key goes after the nearest earlier neighbour it had.
    var anchor = -1
    for (var previousIndex = 0; previousIndex < previous.length; previousIndex++) {
        var entry = previous[previousIndex] || {}
        var key = String(entry.key || "")
        if (!key) continue
        if (placed[key]) {
            anchor = indexOfKey(result, key)
            continue
        }
        result.splice(anchor + 1, 0, { key: key, exiting: true })
        placed[key] = true
        anchor += 1
    }
    return result
}

function drop(rendered, key) {
    return (Array.isArray(rendered) ? rendered : []).filter(function(entry) {
        return !(entry && entry.key === key && entry.exiting)
    })
}

function indexOfKey(rows, key) {
    for (var index = 0; index < rows.length; index++)
        if (rows[index].key === key) return index
    return -1
}

function sameEntries(left, right) {
    if (left.length !== right.length) return false
    for (var index = 0; index < left.length; index++)
        if (left[index].key !== right[index].key || left[index].exiting !== right[index].exiting)
            return false
    return true
}

if (typeof module !== "undefined") module.exports = {
    LAYOUT: LAYOUT,
    ENTER: ENTER,
    EXIT: EXIT,
    SNAP: SNAP,
    ENTER_OFFSET: ENTER_OFFSET,
    ENTER_SCALE: ENTER_SCALE,
    omega: omega,
    zeta: zeta,
    solve: solve,
    sample: sample,
    merge: merge,
    drop: drop,
    sameEntries: sameEntries
}
