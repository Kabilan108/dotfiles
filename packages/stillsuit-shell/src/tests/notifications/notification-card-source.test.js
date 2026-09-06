const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const cardPath = path.join(
    __dirname,
    "../../plugins/builtin/notifications/NotificationCard.qml"
)
const cardSource = fs.readFileSync(cardPath, "utf8")
const servicePath = path.join(__dirname, "../../services/NotificationService.qml")
const serviceSource = fs.readFileSync(servicePath, "utf8")
const centerPath = path.join(
    __dirname,
    "../../plugins/builtin/notifications/NotificationCenter.qml"
)
const centerSource = fs.readFileSync(centerPath, "utf8")
const widgetPath = path.join(
    __dirname,
    "../../plugins/builtin/notifications/Widget.qml"
)
const widgetSource = fs.readFileSync(widgetPath, "utf8")

assert.match(
    cardSource,
    /textFormat:\s*Text\.PlainText/,
    "sender-controlled notification bodies render as plain text"
)
assert.match(cardSource, /import "\.\.\/\.\.\/\.\.\/ui" as Ui/)
assert.match(cardSource, /Ui\.ShellSurface/)
assert.match(cardSource, /Ui\.ShellButton/)
assert.match(cardSource, /text:\s*"Actions expired"/)
assert.match(cardSource, /^\s*theme:\s*context\.theme\s*$/m)
assert.doesNotMatch(cardSource, /readonly property var theme/)
assert.doesNotMatch(cardSource, /theme\.colors|theme\.controls|#[0-9a-fA-F]{3,8}/)
assert.match(centerSource, /Ui\.ShellToggle/)
assert.match(centerSource, /onToggled:\s*requestedChecked\s*=>\s*root\.service\.setDnd/)
assert.doesNotMatch(centerSource, /theme\.colors|theme\.controls|#[0-9a-fA-F]{3,8}/)
assert.match(widgetSource, /iconName:\s*"notifications"/)
assert.match(widgetSource, /unreadBadgeText/)
assert.doesNotMatch(
    cardSource,
    /textFormat:\s*Text\.StyledText/,
    "notification bodies must not enable StyledText"
)
assert.match(
    serviceSource,
    /bodyMarkupSupported:\s*false/,
    "the notification server does not advertise markup that the card will not render"
)

console.log("notification-card-source: ok")
