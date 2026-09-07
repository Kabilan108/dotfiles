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
const buttonPath = path.join(__dirname, "../../ui/ShellButton.qml")
const buttonSource = fs.readFileSync(buttonPath, "utf8")
const toastsPath = path.join(
    __dirname,
    "../../plugins/builtin/notifications/NotificationToasts.qml"
)
const toastsSource = fs.readFileSync(toastsPath, "utf8")
const deckPath = path.join(
    __dirname,
    "../../plugins/builtin/notifications/NotificationDeck.qml"
)
const deckSource = fs.readFileSync(deckPath, "utf8")
const stormPath = path.join(__dirname, "../../../design-lab/fixtures/notification-storm.json")
const storm = JSON.parse(fs.readFileSync(stormPath, "utf8"))
const emptyPath = path.join(__dirname, "../../../design-lab/fixtures/notification-empty.json")
const empty = JSON.parse(fs.readFileSync(emptyPath, "utf8"))

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
assert.doesNotMatch(centerSource, /Do not disturb|setDnd|ShellToggle/)
assert.match(centerSource, /root\.service\.snooze\("\*", modelData\.preset\)/)
assert.match(centerSource, /name:\s*"notifications-off"[\s\S]*accessibleName:\s*"Quiet notifications"/)
assert.match(centerSource, /root\.service\.wake\("\*"\)/)
assert.match(centerSource, /root\.service\.snooze\(sourceSection\.modelData\.key, "1h"\)/)
assert.match(centerSource, /label:\s*sourceSection\.sourceSnoozed \? "Wake" : "1h"/)
assert.match(centerSource, /iconName:\s*sourceSection\.sourceSnoozed[\s\S]*"notifications-off"/)
assert.doesNotMatch(centerSource, /active:\s*sourceSection\.sourceSnoozed/)
assert.match(centerSource, /label:\s*sourceSection\.modelData\.label \+ " · "\s*\+ String\(sourceSection\.modelData\.rows\.length\)/)
assert.match(centerSource, /id:\s*globalQuietRow[\s\S]*name:\s*"notifications-off"/)
assert.match(centerSource, /text:\s*root\.service && root\.service\.quietActive[\s\S]*"Quiet until "/)
assert.match(centerSource, /model:\s*root\.service && root\.service\.quietActive \? \[\] : \[/)
assert.match(centerSource, /visible:\s*root\.service && root\.service\.quietActive[\s\S]*label:\s*"Wake"[\s\S]*iconName:\s*"notifications"[\s\S]*foregroundColor:\s*root\.theme\.semantic\.status\.warning/)
assert.doesNotMatch(centerSource, /color:\s*root\.theme\.component\.panel\.section/)
assert.match(centerSource, /foregroundColor:\s*sourceSection\.sourceSnoozed[\s\S]*root\.theme\.semantic\.status\.warning/)
assert.match(centerSource, /function toggleSourceCollapsed\(key\)/)
assert.match(centerSource, /Ui\.ShellButton \{[\s\S]*id:\s*groupToggle[\s\S]*onClicked:\s*root\.toggleSourceCollapsed/)
assert.match(centerSource, /iconName:\s*sourceSection\.collapsed \? "expand-more" : "expand-less"/)
assert.match(centerSource, /model:\s*sourceSection\.collapsed \? \[\] : modelData\.rows/)
assert.match(centerSource, /label:\s*""[\s\S]*iconName:\s*"delete"[\s\S]*destructive:\s*true[\s\S]*root\.service\.clearSource\(sourceSection\.modelData\.key\)/)
assert.match(serviceSource, /function clearSource\(sourceKey\)/)
assert.match(centerSource, /Ui\.ShellEmptyRow \{[\s\S]*text:\s*"No notifications"/)
assert.match(centerSource, /iconSizeRole:\s*"medium"/)
assert.match(centerSource, /textSizeRole:\s*"label"/)
assert.doesNotMatch(centerSource, /title:\s*"No notifications"/)
assert.doesNotMatch(centerSource, /theme\.colors|theme\.controls|#[0-9a-fA-F]{3,8}/)
assert.match(widgetSource, /iconName:\s*service && service\.quietActive \? "notifications-off" : "notifications"/)
assert.match(widgetSource, /unreadBadgeText/)
assert.doesNotMatch(widgetSource, /badgeIconName/)
assert.match(buttonSource, /property color foregroundColor:\s*"transparent"/)
assert.match(buttonSource, /if \(foregroundColor\.a > 0\)\s*return foregroundColor/)
assert.match(toastsSource, /aboveWindows:\s*true/)
assert.match(toastsSource, /WlrLayershell\.layer:\s*WlrLayer\.Overlay/)
assert.match(toastsSource, /WlrLayershell\.namespace:\s*"stillsuit\.notifications"/)
assert.match(deckSource, /readonly property var rows:\s*deck && deck\.rows \? deck\.rows : \[\]/)
assert.doesNotMatch(deckSource, /Array\.isArray\(deck\.rows\)/)
assert.equal(
    storm.notifications.slice(-5).filter(notification => notification.appName === "Slack").length,
    3,
    "the retained popup window includes a three-card Slack deck"
)
assert.deepEqual(empty.notifications, [], "the workbench has a stable empty notification state")
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
assert.match(serviceSource, /target:\s*"stillsuit-notifications"/)
assert.match(cardSource, /dismissThreshold:\s*Math\.min\(width \* 0\.25, 80\)/)
assert.match(cardSource, /flickVelocity:\s*420/)
assert.match(cardSource, /Math\.abs\(dx\) > 6/)
assert.match(cardSource, /Math\.abs\(dx\) > Math\.abs\(dy\) \* 1\.2/)
assert.match(cardSource, /preventStealing:\s*dragging/)
assert.match(
    cardSource,
    /readonly property bool hovered:\s*hoverMouse\.containsMouse/,
)
assert.match(cardSource, /id:\s*gestureMouse[\s\S]*hoverEnabled:\s*true/)
assert.match(deckSource, /model:\s*root\.rows\.slice\(1\)/)
assert.match(cardSource, /duration:\s*root\.dismissMotionDuration/)
assert.match(cardSource, /easing\.type:\s*Easing\.OutCubic/)
assert.match(deckSource, /property bool entered:\s*false/)
assert.match(deckSource, /Component\.onCompleted:\s*Qt\.callLater/)
assert.match(deckSource, /duration:\s*root\.motionDuration/)
assert.match(deckSource, /opacity:\s*root\.expanded \? 1 : 0/)
assert.match(deckSource, /id:\s*expandedColumn[\s\S]*visible:\s*true/)
assert.match(deckSource, /function syncHovered\(\)/)
assert.match(deckSource, /service\.setDeckHovered\(deck\.key, hovered\)/)
assert.doesNotMatch(serviceSource, /function\s+(dismiss|snooze|wake|clearHistory)\s*\([^)]*\):\s*string/,
    "production notification IPC exposes no mutation methods")

console.log("notification-card-source: ok")
