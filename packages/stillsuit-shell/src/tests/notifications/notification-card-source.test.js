const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const pluginDir = path.join(__dirname, "../../plugins/builtin/notifications")
const read = file => fs.readFileSync(path.join(pluginDir, file), "utf8")
const cardSource = read("NotificationCard.qml")
const deckSource = read("NotificationDeck.qml")
const toastsSource = read("NotificationToasts.qml")
const widgetSource = read("Widget.qml")
const springSource = read("SpringValue.qml")
const manifest = JSON.parse(read("manifest.json"))
const serviceSource = fs.readFileSync(path.join(__dirname, "../../services/NotificationService.qml"), "utf8")
const stormPath = path.join(__dirname, "../../../design-lab/fixtures/notification-storm.json")
const storm = JSON.parse(fs.readFileSync(stormPath, "utf8"))
const emptyPath = path.join(__dirname, "../../../design-lab/fixtures/notification-empty.json")
const empty = JSON.parse(fs.readFileSync(emptyPath, "utf8"))

// The center is gone; the bell toggles quiet mode.
assert(!fs.existsSync(path.join(pluginDir, "NotificationCenter.qml")))
assert.deepEqual(manifest.kinds, ["service", "bar-widget", "overlay"])
assert.equal(manifest.entryPoints.panel, undefined)
assert.equal(manifest.stateSchemaVersion, 3)
assert.match(widgetSource, /onClicked:\s*if \(service\) service\.toggleQuiet\(\)/)
assert.match(widgetSource, /iconName:\s*quiet \? "notifications-off" : "notifications"/)
assert.match(widgetSource, /label:\s*service \? service\.heldBadgeText : ""/)
assert.doesNotMatch(widgetSource, /surfaceToggle|unread/)
assert.doesNotMatch(serviceSource, /history|unread|markRead|openCenter|centerRows/i)

// Sender text renders as plain text, styled only through theme roles.
assert.match(cardSource, /textFormat:\s*Text\.PlainText/)
assert.doesNotMatch(cardSource, /textFormat:\s*Text\.StyledText/)
assert.match(serviceSource, /bodyMarkupSupported:\s*false/)
assert.match(cardSource, /import "\.\.\/\.\.\/\.\.\/ui" as Ui/)
assert.match(cardSource, /Ui\.ShellSurface/)
assert.match(cardSource, /text:\s*"Actions expired"/)
assert.match(cardSource, /^\s*theme:\s*context\.theme\s*$/m)
assert.doesNotMatch(cardSource + deckSource + toastsSource, /theme\.colors|theme\.controls|#[0-9a-fA-F]{3,8}/)

// A click opens the sender, or dismisses a card that has nothing to open.
assert.match(cardSource, /if \(root\.canActivate\) root\.service\.invokeAction\(root\.snapshot\.key, "default"\)\s*else root\.service\.dismiss\(root\.snapshot\.key\)/)
assert.doesNotMatch(cardSource + serviceSource, /mute(Source|s\b)|showOverflow|"more"/,
    "no per-source mutes and no overflow menu")
assert.match(cardSource, /Flow \{[\s\S]*model:\s*root\.actionState === "available" \? root\.buttonActions : \[\]/,
    "every button shows inline, wrapping when needed")
assert.match(cardSource, /dismissThreshold:\s*Math\.min\(width \* 0\.25, 80\)/)
assert.match(cardSource, /flickVelocity:\s*420/)
assert.match(cardSource, /Math\.abs\(dx\) > Math\.abs\(dy\) \* 1\.2/)
assert.match(cardSource, /preventStealing:\s*dragging/)
assert.match(cardSource, /readonly property bool hovered:\s*hoverMouse\.containsMouse/)

// Every card and deck keeps its delegate by key, including while it leaves.
assert.match(toastsSource, /Motion\.merge\(rendered, decks\.map/)
assert.match(toastsSource, /model:\s*deckKeys/)
assert.match(toastsSource, /overlayVisible:\s*rendered\.length > 0/,
    "the overlay stays mapped until the last exit finishes")
assert.match(toastsSource, /visible:\s*root\.overlayVisible/)
assert.match(toastsSource, /function onFrameSwapped\(\) \{ root\.surfaceReady = true \}/,
    "entrances wait for the overlay's first presented frame")
assert.match(toastsSource, /aboveWindows:\s*true/)
assert.match(toastsSource, /WlrLayershell\.layer:\s*WlrLayer\.Overlay/)
assert.match(toastsSource, /WlrLayershell\.namespace:\s*"stillsuit\.notifications"/)
assert.match(toastsSource, /mask:\s*Region \{ item: inputArea \}/)
assert.match(deckSource, /Motion\.merge\(rendered, rows\.map/)
assert.match(deckSource, /model:\s*renderedKeys/)
assert.match(deckSource, /onSettled:\s*if \(slot\.exiting && value === 0\) root\.dropRow\(slot\.rowKey\)/)
assert.match(deckSource, /function syncHovered\(\)/)
assert.match(deckSource, /service\.setDeckHovered\(deckKey, hovered\)/)

// Motion runs on the springs and honours reduced motion everywhere.
assert.match(springSource, /FrameAnimation/)
assert.match(springSource, /Motion\.solve\(spring, offset, velocity\)/)
assert.doesNotMatch(deckSource + toastsSource, /NumberAnimation|Easing\.OutCubic/)
for (const match of deckSource.matchAll(/SpringValue \{[\s\S]*?\n {0,16}\}/g))
    assert.match(match[0], /instant:\s*root\.reducedMotion/, "every deck spring honours reduced motion")

for (const name of ["closeRow", "invokeAction"]) {
    const body = serviceSource.split(`function ${name}(`)[1].split(/\n    function /)[0]
    assert.doesNotMatch(body, /flushState\(\)/, `${name} goes through the persist() debounce`)
    assert.match(body, /persist\(\)/)
}

// The production IPC reads status and switches quiet mode; nothing else.
const ipc = serviceSource.split("IpcHandler {")[1]
assert.deepEqual([...ipc.matchAll(/function (\w+)\(/g)].map(match => match[1]), ["status", "toggleQuiet", "setQuiet"])

assert.equal(
    storm.notifications.slice(-5).filter(notification => notification.appName === "Slack").length,
    3,
    "the storm fixture ends with a three-card Slack deck"
)
assert.deepEqual(empty.notifications, [], "the workbench has a stable empty notification state")

console.log("notification-card-source: ok")
