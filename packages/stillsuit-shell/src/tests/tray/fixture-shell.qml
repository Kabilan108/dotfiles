import QtQuick
import Quickshell
import "FixtureTheme.js" as FixtureTheme
import "plugins/tray" as Tray

ShellRoot {
    id: root

    property int failures: 0
    property var events: []
    property int panelCloses: 0
    property int panelOpens: 0

    function check(condition, label) {
        if (condition) return
        failures += 1
        console.log("TRAY_FIXTURE_FAIL " + label)
    }

    function makeItem(spec) {
        return itemComponent.createObject(root, spec)
    }

    Component {
        id: itemComponent
        QtObject {
            property string id: ""
            property string title: ""
            property string tooltipTitle: ""
            property string status: "active"
            property string icon: ""
            property bool hasMenu: false
            property bool onlyMenu: false
            property var menu: null
            function activate() { root.events.push("activate:" + id) }
            function secondaryActivate() { root.events.push("secondary:" + id) }
            function scroll(delta, horizontal) { root.events.push("scroll:" + id + ":" + delta + ":" + horizontal) }
        }
    }

    property var slack: makeItem({ id: "Slack_status_icon_1", title: "Slack", status: "active", hasMenu: true })
    property var telegram: makeItem({ id: "org.telegram.desktop", title: "Telegram", status: "active" })
    property var steam: makeItem({ id: "steam", title: "Steam", status: "active" })
    property var shortKey: makeItem({ id: "s", title: "", status: "active" })
    property var chatgpt: makeItem({ id: "chatgpt", title: "", tooltipTitle: "ChatGPT", status: "attention" })
    property var spotify: makeItem({ id: "spotify", title: "Spotify", status: "active", hasMenu: true, onlyMenu: true })
    property var passive: makeItem({ id: "passive", title: "Idle helper", status: "passive" })

    property var model: QtObject {
        property var items: [root.spotify, root.passive, root.chatgpt, root.slack, root.telegram]
    }

    property var focusRequests: []

    property var context: QtObject {
        property var theme: FixtureTheme.create()
        property var compositor: QtObject {
            property var workspaces: [
                { id: 7, idx: 2, name: "", output: "FIX-1", is_active: true },
                { id: 9, idx: 4, name: "chat", output: "FIX-1", is_active: false }
            ]
            property var windows: [
                { id: 41, app_id: "slack", title: "General - Slack", workspace_id: 7, is_focused: false },
                { id: 42, app_id: "slack", title: "Huddle", workspace_id: 9, is_focused: true },
                { id: 43, app_id: "org.telegram.desktop", title: "Telegram", workspace_id: 7, is_focused: false },
                { id: 44, app_id: "discord", title: "Discord", workspace_id: 9, is_focused: false },
                { id: 45, app_id: "steam_app_123", title: "Game", workspace_id: 7, is_focused: false },
                { id: 46, app_id: "steam", title: "Steam", workspace_id: 9, is_focused: false }
            ]
            property string focusedOutputId: "FIX-1"
        }
        property var panels: QtObject {
            property string selectedId: ""
            property string selectedOutputId: ""
        }
        property var settings: QtObject {
            property var values: ({})
        }
        property var logger: QtObject {
            function warn(message) { console.log("warn: " + message) }
            function info(message) {}
            function debug(message) {}
            function error(message) { console.log("error: " + message) }
        }
        property var actions: QtObject {
            function surfaceOpen(id, payload) { root.panelOpens += 1; root.events.push("open:" + id + ":" + payload); return "ok" }
            function surfaceClose(id) { root.panelCloses += 1; return "ok" }
            function surfaceToggle(id, payload) { return "ok" }
            function windowFocus(windowId) { root.focusRequests.push(Number(windowId)); return "ok" }
        }
    }

    Tray.Service {
        id: service
        context: root.context
        model: root.model
    }

    Tray.Widget {
        id: widget
        context: root.context
        service: service
        outputId: "FIX-1"
    }

    Tray.Panel {
        id: panel
        context: root.context
        service: service
        screen: null
        outputId: "FIX-1"
    }

    Timer {
        interval: 200
        running: true
        onTriggered: {
            root.check(service.count === 4, "passive items are filtered: " + service.count)
            root.check(service.items[0].id === "chatgpt" && service.items[2].id === "Slack_status_icon_1" && service.items[3].id === "spotify",
                "items sort by id")
            root.check(service.attention === true, "attention propagates")
            root.check(service.statusOf(root.passive) === "passive", "string status is read")
            root.check(service.tooltipFor(root.chatgpt) === "ChatGPT", "tooltip prefers tooltipTitle")
            root.check(service.itemById("Slack_status_icon_1") === root.slack, "itemById resolves")
            root.check(service.itemById("passive") === null, "itemById skips hidden items")

            root.check(widget.visible === true, "widget shows with items")
            root.check(widget.implicitWidth > 0 && widget.implicitWidth === widget.slotExtent * 4,
                "widget width is one slot per visible item: " + widget.implicitWidth)
            root.check(widget.accessibleName === "System tray, 4 items", "accessible name counts")

            root.check(service.appKey(root.slack) === "slack", "app key strips the status-icon suffix: " + service.appKey(root.slack))
            root.check(service.appKey(root.telegram) === "org.telegram.desktop", "app key keeps reverse-dns ids")
            root.check(service.windowsFor(root.slack).length === 2, "slack matches both slack windows")
            root.check(service.windowsFor(root.telegram).length === 1 && service.windowsFor(root.telegram)[0].id === 43,
                "reverse-dns id matches its window")
            root.check(service.windowsFor(root.chatgpt).length === 0, "no window means no match")
            var steamWindows = service.windowsFor(root.steam)
            root.check(steamWindows.length === 1 && steamWindows[0].id === 46,
                "exact key does not claim prefixed app ids: " + JSON.stringify(steamWindows.map(function(w) { return w.id })))
            root.check(service.windowsFor(root.shortKey).length === 0, "single-character keys never match")
            root.check(service.preferredWindow(root.slack).id === 42, "preferred window is the focused one")
            root.context.compositor.windows = root.context.compositor.windows.map(function(window) {
                var next = JSON.parse(JSON.stringify(window)); next.is_focused = next.id === 43; return next
            })
            root.check(service.preferredWindow(root.slack).id === 41,
                "without a focused match, prefer the active workspace on the focused output")
            root.check(service.preferredWindow(root.steam).id === 46, "single match is returned regardless of workspace")

            widget.primaryAction(root.slack)
            root.check(root.focusRequests.length === 1 && root.focusRequests[0] === 41,
                "primary action focuses the visible window instead of activating: " + JSON.stringify(root.focusRequests))
            root.check(root.events.indexOf("activate:Slack_status_icon_1") < 0, "activate is not sent when a window was focused")
            widget.primaryAction(root.chatgpt)
            root.check(root.events.indexOf("activate:chatgpt") >= 0, "primary action activates when no window exists")
            widget.primaryAction(root.spotify)
            root.check(root.panelOpens === 1 && root.events[root.events.length - 1].indexOf('"itemId":"spotify"') >= 0,
                "onlyMenu items open the panel: " + JSON.stringify(root.events))
            service.secondaryActivate(root.chatgpt)
            root.check(root.events.indexOf("secondary:chatgpt") >= 0, "secondary activate")
            service.scroll(root.chatgpt, 120, false)
            root.check(root.events.indexOf("scroll:chatgpt:120:false") >= 0, "scroll forwards delta")

            panel.open(JSON.stringify({ outputId: "FIX-1", itemId: "Slack_status_icon_1" }))
            root.check(panel.activeItem === root.slack, "panel resolves item from payload")
            root.check(panel.activeWindows.length === 2, "panel lists the item's windows")
            root.check(panel.workspaceLabel(panel.activeWindows[1]) === "chat", "named workspace label")
            root.check(panel.workspaceLabel(panel.activeWindows[0]) === "2", "unnamed workspace falls back to index")
            panel.raise(panel.activeWindows[0])
            root.check(root.focusRequests[root.focusRequests.length - 1] === 41 && root.panelCloses >= 1,
                "raising a window focuses it and closes the panel")
            root.check(panel.hasMenu === false, "fixture item without menu handle reports no menu")
            root.check(panel.activeTitle === "Slack", "panel header uses item title")
            var titleEntry = { text: "Slack", enabled: false, hasChildren: false, isSeparator: false }
            var separator = { isSeparator: true, enabled: true }
            var plain = { text: "Preferences", enabled: true, isSeparator: false, hasChildren: false, triggered: function() { root.events.push("triggered:prefs") } }
            root.check(panel.rowHidden(titleEntry, 0) === true, "disabled app-name title row is hidden at the root")
            root.check(panel.rowHidden(separator, 1) === false, "separator after a visible first row stays")
            root.check(panel.rowHidden(separator, 0) === true, "leading separator is hidden at the root")
            root.check(panel.rowHidden(plain, 0) === false, "ordinary first row shows")
            root.check(panel.rowHidden(null, 3) === true, "missing entry is hidden")
            var closesBefore = root.panelCloses
            panel.trigger(plain)
            root.check(root.events.indexOf("triggered:prefs") >= 0 && root.panelCloses === closesBefore + 1,
                "trigger fires the entry and closes the panel")
            panel.settle()
            root.check(panel.clickAllowed() === false, "clicks are refused right after a level change")
            panel.settleUntil = Date.now() - 1
            root.check(panel.clickAllowed() === true, "clicks resume once the settle window passes")
            panel.resetMenu()
            root.check(panel.clickAllowed() === true && panel.submenuDepth === 0, "reset clears the settle window")

            panel.open("not json")
            root.check(panel.activeItem === null, "malformed payload leaves no active item")
            panel.open(JSON.stringify({ itemId: "Slack_status_icon_1" }))
            panel.close()
            root.check(panel.activeItem === null && panel.submenuDepth === 0, "close clears state")

            root.model.items = [root.passive]
            root.check(service.count === 0 && widget.visible === false && widget.implicitWidth === 0,
                "empty tray collapses the widget")

            if (root.failures === 0) console.log("TRAY_FIXTURE_OK")
            Qt.quit()
        }
    }
}
