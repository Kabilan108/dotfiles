.pragma library
// SPDX-License-Identifier: MIT

var MISSING = 0
var USABLE = 1
var UNCHECKED = -1

var _verdicts = {}
var lookups = 0

function known(name) {
    return Object.prototype.hasOwnProperty.call(_verdicts, name) ? _verdicts[name] : UNCHECKED
}

function resolve(name, check) {
    var verdict = known(name)
    if (verdict !== UNCHECKED)
        return verdict
    lookups++
    verdict = check(name) !== "" ? USABLE : MISSING
    _verdicts[name] = verdict
    return verdict
}
