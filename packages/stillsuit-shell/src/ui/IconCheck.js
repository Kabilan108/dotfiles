.pragma library
// SPDX-License-Identifier: MIT

// Whether the icon theme can draw a name, shared by every ShellAppIcon in the
// engine. A theme lookup is synchronous and can take most of a second while
// the theme is cold, so each name is looked up once; an icon installed later
// shows after the shell restarts.
var MISSING = 0
var USABLE = 1
var UNCHECKED = -1

var _verdicts = {}
var lookups = 0

function known(name) {
    return Object.prototype.hasOwnProperty.call(_verdicts, name) ? _verdicts[name] : UNCHECKED
}

// `check` is Quickshell.iconPath(name, true): it keeps QIcon::fromTheme's
// fallbacks, such as "foo" standing in for "foo-bar".
function resolve(name, check) {
    var verdict = known(name)
    if (verdict !== UNCHECKED)
        return verdict
    lookups++
    verdict = check(name) !== "" ? USABLE : MISSING
    _verdicts[name] = verdict
    return verdict
}
