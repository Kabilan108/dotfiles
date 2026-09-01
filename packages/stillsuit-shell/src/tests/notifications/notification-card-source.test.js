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

assert.match(
    cardSource,
    /textFormat:\s*Text\.PlainText/,
    "sender-controlled notification bodies render as plain text"
)
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
