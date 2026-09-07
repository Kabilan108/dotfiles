const assert = require("node:assert/strict")
const Source = require("../../services/NotificationSource.js")
const Links = require("../../services/NotificationLinks.js")
const Layout = require("../../services/NotificationLayout.js")

const chrome = Source.identify({
    appName: "Google Chrome",
    body: '<a href="https://calendar.google.com/">calendar.google.com</a> Standup moved'
})
assert.equal(chrome.key, "web:calendar.google.com")
assert.equal(chrome.label, "calendar.google.com")
assert.equal(chrome.body, "Standup moved")

const native = Source.identify({
    appName: "",
    appIcon: "fallback-icon",
    hints: { "desktop-entry": "org.signal.Signal.desktop" }
})
assert.equal(native.key, "app:org-signal-signal")
assert.equal(native.label, "org.signal.Signal")

assert.equal(Source.hostOf("https://paypal.com@evil.example/path"), "evil.example")
assert.equal(Source.hostname("127.0.0.1"), "")

const meeting = Links.primary(
    "Call",
    "Details https://example.com/doc then https://meet.google.com/abc-defg-hij",
    "calendar.google.com"
)
assert.equal(meeting.label, "Join meeting")
assert.equal(meeting.url, "https://meet.google.com/abc-defg-hij")
assert.equal(Links.primary("Origin", "https://calendar.google.com", "calendar.google.com"), null)
assert.equal(Links.primary("Unsafe", "https://friendly.example@evil.example/path", ""), null)

const decks = Layout.group([
    { key: "1", sourceKey: "app:signal", sourceLabel: "Signal" },
    { key: "2", sourceKey: "app:signal", sourceLabel: "Signal" },
    { key: "3", sourceKey: "app:ghostty", sourceLabel: "Ghostty" }
])
assert.deepEqual(decks.map(deck => [deck.key, deck.rows.length]), [
    ["app:signal", 2],
    ["app:ghostty", 1]
])
const closed = Layout.placements(decks[0].rows, "", { cardHeight: 100 })
assert.equal(closed.placements["2"].y, 10)
assert.equal(closed.height, 110)

console.log("source-links-layout: ok")
