import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "core"
import "ui" as Ui
import "tests/FixtureTheme.js" as FixtureTheme

ShellRoot {
    id: root
    property var theme: FixtureTheme.create()
    property var testScreens: Quickshell.screens
    property int checks: 0
    property string phase: "loading"
    readonly property string iconPng: Quickshell.env("FIXTURE_ICON_PNG")
    // The latest fake component handed to the router, by plugin ID.
    property var loads: ({})
    property string reopenOnClose: ""
    // Content that closes its own route when the host reparents it.
    property string closeOnParent: ""
    // Keys the menu field saw, in order.
    property var menuKeys: []

    QtObject {
        id: testCompositor
        property string focusedOutputId: Quickshell.screens[0].name
    }

    QtObject {
        id: testCatalog
        property bool loaded: true
        property var entries: ({
            panel: entry("panel", "panel", "per-output", true),
            menu: entry("menu", "menu", "global", true),
            other: entry("other", "menu", "global", false),
            perout: entry("perout", "menu", "per-output", true),
            closer: entry("closer", "menu", "global", true),
            reopener: entry("reopener", "menu", "global", false),
            slowmenu: entry("slowmenu", "menu", "global", true),
            slowcloser: entry("slowcloser", "menu", "global", false)
        })
        function entry(id, kind, scope, keepLoaded) {
            var scopes = {}
            scopes[kind] = scope
            return { manifest: { id: id, keepLoaded: keepLoaded, kinds: [kind], scope: scopes, dependencies: [] } }
        }
        function has(id) { return entries[id] !== undefined }
        function get(id) { return entries[id] }
        function isEnabled(id) { return has(id) }
        function hasKind(id, kind) { return has(id) && entries[id].manifest.kinds.indexOf(kind) !== -1 }
        function primarySurfaceKind(id) { return has(id) ? entries[id].manifest.kinds[0] : "" }
        function entryPointUrl(entry, kind) { return entry.manifest.id }
    }

    // Stands in for a component from Qt.createComponent, which the router
    // destroys on unload; the declared components below must survive that.
    // IDs starting with "slow" stay Loading until a step sets status, as an
    // asynchronous compile would. Instances learn their plugin ID as routeId.
    Component {
        id: fakeComponentType
        QtObject {
            property int status: Component.Ready
            property string routeId: ""
            property Component inner: null
            function createObject(parent, properties) {
                var merged = { routeId: routeId }
                for (var key in properties) merged[key] = properties[key]
                return inner.createObject(parent, merged)
            }
            function errorString() { return "fixture component failed" }
        }
    }

    Component {
        id: panelComponent
        Item {
            id: panel
            required property var context
            required property var screen
            required property string outputId
            property string routeId: ""
            readonly property bool hostedPanel: true
            property bool opened: false
            implicitWidth: 380
            implicitHeight: 200
            visible: false
            function open(payloadJson) {
                var payload = payloadJson ? JSON.parse(payloadJson) : {}
                opened = true
                if (payload.closeDuringOpen) testRouter.close("panel")
            }
            function close() { opened = false }
            onParentChanged: root.closeIfAsked(panel)
        }
    }

    Component {
        id: menuComponent
        FocusScope {
            id: menu
            property var context: null
            property var screen: null
            property string outputId: ""
            property string routeId: ""
            readonly property bool hostedMenu: true
            property bool opened: false
            property string mode: ""
            property int openCount: 0
            property int closeCount: 0
            property int downCount: 0
            property int ctrlKCount: 0
            property int acceptCount: 0
            readonly property alias field: searchField
            readonly property alias themeIcon: missingThemeIcon
            readonly property alias fileIcon: pngIcon
            readonly property alias missingFileIcon: missingPathIcon
            implicitWidth: 640
            implicitHeight: 300
            visible: false
            function open(payloadJson) {
                var payload = payloadJson ? JSON.parse(payloadJson) : {}
                mode = payload.mode || "combi"
                opened = true
                openCount++
                if (payload.closeDuringOpen) testRouter.close(routeId)
            }
            function close() {
                opened = false
                closeCount++
                if (root.reopenOnClose !== "" && root.reopenOnClose === routeId) {
                    root.reopenOnClose = ""
                    testRouter.open(routeId, "")
                }
            }
            onParentChanged: root.closeIfAsked(menu)
            function keepOpenOnToggle(payloadJson) {
                var payload = payloadJson ? JSON.parse(payloadJson) : {}
                if (payload.closeDuringToggle) {
                    testRouter.close(routeId)
                    return true
                }
                return (payload.mode || "combi") !== mode
            }
            Ui.ShellTextField {
                id: searchField
                theme: root.theme
                focus: true
                width: parent.width
                placeholderText: "Search"
                iconName: "search"
                onKeyPressed: event => {
                    root.recordMenuKey(event)
                    if (event.key === Qt.Key_Down) {
                        menu.downCount++
                        event.accepted = true
                    } else if (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier)) {
                        menu.ctrlKCount++
                        event.accepted = true
                    }
                }
                onAccepted: menu.acceptCount++
            }
            Row {
                y: 80
                spacing: 8
                Ui.ShellAppIcon {
                    id: missingThemeIcon
                    theme: root.theme
                    icon: "stillsuit-fixture-icon-that-does-not-exist"
                }
                Ui.ShellAppIcon {
                    id: pngIcon
                    theme: root.theme
                    icon: root.iconPng
                    sizeRole: "medium"
                }
                Ui.ShellAppIcon {
                    id: missingPathIcon
                    theme: root.theme
                    icon: "/nonexistent/zed #1.png"
                    fallbackLabel: "zed"
                }
            }
        }
    }

    SurfaceRouter {
        id: testRouter
        catalog: testCatalog
        compositor: testCompositor
        screens: root.testScreens
        componentFactory: function(url, mode) {
            var fake = fakeComponentType.createObject(root, {
                routeId: url,
                inner: url === "panel" ? panelComponent : menuComponent,
                status: url.indexOf("slow") === 0 ? Component.Loading : Component.Ready
            })
            root.loads[url] = fake
            return fake
        }
    }

    PanelHosts {
        router: testRouter
        theme: root.theme
        screens: root.testScreens
    }

    // An ordinary toplevel that should hold keyboard focus whenever no menu
    // is shown.
    FloatingWindow {
        id: probeWindow
        title: "menu-host-probe"
        implicitWidth: 400
        implicitHeight: 300
        color: "#202020"
        TextInput {
            id: probeInput
            anchors.fill: parent
            focus: true
            color: "white"
        }
    }

    function closeIfAsked(item) {
        if (!item.parent || closeOnParent === "" || closeOnParent !== item.routeId) return
        closeOnParent = ""
        testRouter.close(item.routeId)
    }

    function recordMenuKey(event) {
        menuKeys = menuKeys.concat([event.text !== "" ? event.text : "key:" + event.key])
    }

    function stageOf(host) { return named(host.contentItem, "menu-host-stage") }

    // When the host last presented, and the window it presented in.
    property real presentedAt: 0
    property var presentWindow: null
    function openTimed() {
        var host = menuHost(focusedId())
        remapWatch.target = stageOf(host).Window
        presentWindow = stageOf(host).Window.window
        presentedAt = Date.now()
        return testRouter.open("menu", JSON.stringify({ mode: "combi" }))
    }
    property real remappedAt: 0
    Connections {
        id: remapWatch
        target: null
        function onWindowChanged() {
            if (root.presentedAt > 0 && root.remappedAt === 0) root.remappedAt = Date.now()
        }
    }

    function verify(value, message) {
        checks++
        if (!value) throw new Error(message)
    }

    function named(item, name) {
        if (item.objectName === name) return item
        var children = item.children || []
        for (var index = 0; index < children.length; index++) {
            var result = named(children[index], name)
            if (result) return result
        }
        return null
    }

    function focusedId() { return testCompositor.focusedOutputId }
    function otherId() { return Quickshell.screens[1].name }
    function menuHost(outputId) { return testRouter.menuHosts[outputId] }

    function verifyParked(host, label) {
        verify(!host.shown && host.menuContent === null, label + ": no content")
        verify(host.WlrLayershell.layer === WlrLayer.Bottom, label + ": parked on the bottom layer")
        verify(host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None, label + ": takes no keyboard focus")
        verify(host.mask !== null && host.mask === host.emptyRegion, label + ": empty input mask")
        verify(host.implicitWidth === 1 && host.implicitHeight === 1, label + ": 1x1")
        verify(named(host.contentItem, "menu-host-stage").opacity === 0, label + ": paints nothing")
        verify(host.visible, label + ": surface stays mapped")
    }

    function verifyShown(host, label) {
        verify(host.shown && host.menuContent !== null, label + ": has content")
        verify(host.WlrLayershell.layer === WlrLayer.Overlay, label + ": overlay layer")
        verify(host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.Exclusive, label + ": exclusive keyboard focus")
        verify(host.mask === null, label + ": whole surface takes input")
        verify(host.exclusionMode === ExclusionMode.Ignore, label + ": ignores exclusive zones")
    }

    function stateJson() {
        var host = menuHost(focusedId())
        var content = host ? host.menuContent : null
        return JSON.stringify({
            phase: phase,
            probeText: probeInput.text,
            probeFocus: probeInput.activeFocus,
            menuOpen: testRouter.isOpen("menu"),
            presentedMenuId: testRouter.presentedMenuId,
            drawn: host ? host.drawn : false,
            hostSize: host ? [host.width, host.height, host.implicitWidth, host.implicitHeight] : [],
            hostLayer: host ? [host.WlrLayershell.layer, host.WlrLayershell.keyboardFocus, host.visible,
                host.screen ? host.screen.name : "", named(host.contentItem, "menu-host-stage").opacity,
                host.shown] : [],
            fieldFocus: content ? content.field.inputItem.activeFocus : false,
            menuText: content ? content.field.text : "",
            downCount: content ? content.downCount : -1,
            ctrlKCount: content ? content.ctrlKCount : -1,
            acceptCount: content ? content.acceptCount : -1,
            themeIconChecked: content ? content.themeIcon._verdict !== -1 : false,
            menuKeys: menuKeys
        })
    }

    // The headless seat has no pointer, so presses go through the scrim's
    // press handler at points inside and outside the content.
    function checkPresses() {
        var host = menuHost(focusedId())
        var scrim = named(host.contentItem, "menu-host-scrim")
        var area = named(host.contentItem, "menu-host-content")
        verify(scrim !== null, "scrim located")
        scrim.handlePress(area.x + area.width / 2, area.y + area.height / 2)
        verify(testRouter.isOpen("menu"), "a press inside the content keeps the menu")
        scrim.handlePress(area.x + area.width - 1, area.y + area.height - 1)
        verify(testRouter.isOpen("menu"), "a press on the content's last pixel keeps the menu")
        scrim.handlePress(area.x + area.width / 2, area.y + area.height)
        verify(!testRouter.isOpen("menu") && host.menuContent === null,
            "a press just below the content closes the menu")
    }

    function checkOpenGeometry() {
        var host = menuHost(focusedId())
        verifyShown(host, "focused host")
        verifyParked(menuHost(otherId()), "other host")
        verify(host.drawn && named(host.contentItem, "menu-host-stage").opacity === 1,
            "content is painted once the surface grows")
        verify(host.width === host.screen.width && host.height === host.screen.height,
            "shown host covers the output")
        var area = named(host.contentItem, "menu-host-content")
        verify(area.objectName === "menu-host-content", "content area located")
        verify(Math.abs(area.x - (host.width - area.width) / 2) <= 1, "content is horizontally centered")
        verify(area.y === Math.round(host.height * 0.22), "content top sits at 22% of the output height")
        verify(area.width === 640 && area.height === 300, "content uses its implicit size")
        var menu = host.menuContent
        verify(menu.parent === area && menu.visible, "menu content is reparented into the host")
        verify(menu.field.inputItem.activeFocus, "the search field holds active focus")
        verify(!probeInput.activeFocus, "the toplevel lost keyboard focus to the menu")
    }

    function checkKeys() {
        var menu = menuHost(focusedId()).menuContent
        verify(menu.field.text === "b", "typed text reaches the field: " + menu.field.text)
        verify(menu.downCount === 1, "Down reaches the parent through keyPressed")
        verify(menu.ctrlKCount === 1, "Ctrl+K reaches the parent before the field edits text")
        verify(menu.acceptCount === 1, "Enter emits accepted")
        verify(probeInput.text === "a", "the toplevel saw no keys while the menu was shown")
    }

    function checkBannerAndPanels() {
        var menu = menuHost(focusedId()).menuContent
        testRouter.interruptForBanner(focusedId())
        verify(testRouter.isOpen("menu") && menuHost(focusedId()).menuContent === menu,
            "a banner on the menu's output leaves the menu open")
        testRouter.dismissPanels()
        verify(testRouter.isOpen("menu") && menu.opened, "dismissPanels leaves menus open")
    }

    function checkIcons() {
        var menu = testRouter.contributionInstances("menu", "menu")[0]
        verify(menu.themeIcon._verdict === 0 && menu.themeIcon.resolvedSource.toString() === ""
            && !menu.themeIcon.ready, "a missing theme icon resolves to nothing once checked")
        verify(!menu.themeIcon.children[0].visible && menu.themeIcon.children[2].visible,
            "a missing theme icon shows the catalog glyph")
        verify(menu.fileIcon.ready, "an absolute icon path loads")
        verify(menu.fileIcon.children[0].asynchronous, "icons load asynchronously")
        verify(menu.fileIcon.children[0].sourceSize.width === Math.ceil(menu.fileIcon.width),
            "icons decode at display size")
        var fileUrl = menu.missingFileIcon.resolvedSource.toString()
        verify(fileUrl.indexOf("file:///nonexistent/zed") === 0 && fileUrl.indexOf("%231.png") !== -1,
            "absolute paths become file URLs with reserved characters encoded: " + fileUrl)
        verify(!menu.missingFileIcon.ready && menu.missingFileIcon.children[1].visible,
            "a missing file shows the monogram fallback")
        verify(menu.missingFileIcon.children[1].children[0].text === "Z", "monogram uses the first letter")
        iconLookups = menu.themeIcon._lookupCount()
        menu.themeIcon.themeCheckAllowed = false
        menu.themeIcon.icon = "stillsuit-fixture-second-missing-icon"
        verify(menu.themeIcon._verdict === -1 && menu.themeIcon._lookupCount() === iconLookups,
            "assigning an unchecked name does not ask the theme")
        verify(menu.themeIcon.resolvedSource.toString() === "image://icon/stillsuit-fixture-second-missing-icon"
            && !menu.themeIcon.ready && !menu.themeIcon.children[0].visible,
            "an unchecked name loads in the background behind the fallback")
        verify(!menu.themeIcon.children[0].cache && menu.fileIcon.children[0].cache,
            "an unchecked name skips the pixmap cache; checked icons use it")
        menu.themeIcon.Window.window.update()
    }

    property int iconLookups: 0

    function checkIconsGated() {
        var menu = testRouter.contributionInstances("menu", "menu")[0]
        verify(menu.themeIcon._verdict === -1 && menu.themeIcon._lookupCount() === iconLookups,
            "frames swapped while lookups are not allowed do not ask the theme")
        menu.themeIcon.themeCheckAllowed = true
    }

    function checkIconsAfterFrame() {
        var menu = testRouter.contributionInstances("menu", "menu")[0]
        verify(menu.themeIcon._verdict === 0 && menu.themeIcon._lookupCount() === iconLookups + 1,
            "the name is looked up once, after a frame")
        menu.themeIcon.icon = "stillsuit-fixture-icon-that-does-not-exist"
        verify(menu.themeIcon._verdict === 0 && menu.themeIcon._lookupCount() === iconLookups + 1,
            "a checked name answers from the shared verdicts")
        verify(menu.fileIcon._verdict === 1, "path icons need no theme check")
    }

    function checkRouter() {
        var focused = focusedId()
        var other = otherId()
        var host = menuHost(focused)
        var otherHost = menuHost(other)
        var panelHost = testRouter.panelHosts[focused]
        verify(!testRouter.isOpen("menu"), "menu starts closed")
        verifyParked(host, "focused host after close")

        verify(testRouter.open("panel", "") === "ok" && panelHost.visible, "panel opens")
        verify(testRouter.open("menu", JSON.stringify({ mode: "combi" })) === "ok", "menu opens over a panel")
        var menu = host.menuContent
        verify(menu && menu.opened && testRouter.presentedMenuId === "menu", "menu presented")
        verify(!testRouter.isOpen("panel") && !panelHost.visible && testRouter.presentedId === "",
            "opening a menu dismisses the open panel")
        verify(testRouter.activeId === "menu", "menu is the active route")

        var opens = menu.openCount
        verify(testRouter.toggle("menu", JSON.stringify({ mode: "windows" })) === "ok"
            && testRouter.isOpen("menu") && menu.mode === "windows" && menu.openCount === opens + 1,
            "toggle into another mode re-opens instead of closing")
        verify(host.menuContent === menu, "mode switch keeps the same instance")
        verify(testRouter.toggle("menu", JSON.stringify({ mode: "windows" })) === "ok"
            && !testRouter.isOpen("menu") && !menu.opened, "toggle in the same mode closes")
        verifyParked(host, "host after toggle close")
        verify(menu.parent === null && !menu.visible, "closed menu leaves the host tree")
        verify(testRouter.contributionState("menu", "menu") === "loaded", "keepLoaded menu stays cached")

        testRouter.open("menu", "")
        verify(testRouter.open("panel", "") === "ok", "panel opens over a menu")
        verify(!testRouter.isOpen("menu") && !menu.opened && testRouter.presentedMenuId === "",
            "opening a panel closes the open menu")
        verifyParked(host, "host after panel open")
        verify(panelHost.visible && testRouter.isOpen("panel"), "panel shows")
        testRouter.dismissPanels()

        testRouter.open("menu", "")
        verify(testRouter.open("other", "") === "ok", "second menu opens")
        var second = host.menuContent
        verify(second !== menu && second.opened && testRouter.presentedMenuId === "other",
            "second menu replaces the first in the host")
        verify(!testRouter.isOpen("menu") && !menu.opened && menu.parent === null,
            "opening another menu closes the open menu")
        verify(testRouter.close("other") === "ok", "second menu closes")
        verify(testRouter.contributionState("other", "menu") === "unloaded",
            "menu without keepLoaded unloads on close")
        verifyParked(host, "host after close")

        testRouter.open("menu", "")
        testRouter.unload("menu")
        verify(testRouter.presentedMenuId === "" && host.menuContent === null,
            "unload dismisses the menu from its host")
        verify(testRouter.contributionState("menu", "menu") === "unloaded", "unload destroys the menu")
        verifyParked(host, "host after unload")

        testRouter.open("menu", "")
        menu = host.menuContent
        verify(menu !== null, "menu reloads on open")
        testRouter.dismissMenus()
        verify(!testRouter.isOpen("menu") && host.menuContent === null, "dismissMenus closes the menu")

        testRouter.open("menu", "")
        testCompositor.focusedOutputId = other
        verify(!testRouter.isOpen("menu") && host.menuContent === null,
            "a focused-output change closes the menu")
        testCompositor.focusedOutputId = focused

        testRouter.open("menu", JSON.stringify({ outputId: other }))
        verify(otherHost.menuContent === menu && !host.shown, "menu opens on the requested output")
        verify(menu.outputId === other, "global menu learns its placement")
        verifyShown(otherHost, "other host while presenting")
        testRouter.toggle("menu", JSON.stringify({ outputId: focused }))
        verify(host.menuContent === menu && otherHost.menuContent === null,
            "toggle from another output moves the menu between hosts")
        verifyParked(otherHost, "previous host after a move")
        testRouter.close("menu")

        testRouter.open("perout", JSON.stringify({ outputId: other }))
        var otherInstance = otherHost.menuContent
        verify(otherInstance && otherInstance.outputId === other, "per-output menu uses that output's instance")
        testRouter.toggle("perout", JSON.stringify({ outputId: focused }))
        var focusedInstance = host.menuContent
        verify(focusedInstance && focusedInstance !== otherInstance && focusedInstance.outputId === focused,
            "per-output menu switches to the focused output's instance")
        verify(otherHost.menuContent === null && !otherInstance.opened,
            "the previous output's instance is dismissed and closed")
        testRouter.close("perout")
        verifyParked(host, "host after per-output close")
        verifyParked(otherHost, "other host after per-output close")
    }

    // Content callbacks that close or reopen their own route re-entrantly.
    // The router treats that as a cancellation, never as a failure.
    function checkReentrantRoutes() {
        var host = menuHost(focusedId())
        var panelHost = testRouter.panelHosts[focusedId()]

        verify(testRouter.open("closer", "") === "ok" && host.menuContent !== null
            && host.menuContent.routeId === "closer", "closer menu opens")
        testRouter.close("closer")
        verify(testRouter.open("closer", JSON.stringify({ closeDuringOpen: true })) === "ok",
            "closing from a loaded menu's open() returns ok")
        verify(!testRouter.isOpen("closer") && testRouter.presentedMenuId === ""
            && host.menuContent === null, "the menu that closed itself during open() stays closed")
        verify(testRouter.contributionState("closer", "menu") === "loaded"
            && testRouter.contributionError("closer", "menu") === "",
            "closing during open() leaves the keepLoaded menu loaded, without an error: "
            + testRouter.contributionState("closer", "menu") + " "
            + testRouter.contributionError("closer", "menu"))
        verifyParked(host, "host after a close during open()")

        verify(testRouter.open("closer", "") === "ok" && testRouter.presentedMenuId === "closer",
            "closer reopens")
        verify(testRouter.toggle("closer", JSON.stringify({ closeDuringToggle: true })) === "ok",
            "closing from keepOpenOnToggle returns ok")
        verify(!testRouter.isOpen("closer") && host.menuContent === null,
            "a menu that closed itself from keepOpenOnToggle is not reopened")
        verify(testRouter.contributionState("closer", "menu") === "loaded",
            "closing during keepOpenOnToggle is not an error")

        verify(testRouter.open("slowcloser", JSON.stringify({ closeDuringOpen: true })) === "ok"
            && testRouter.contributionState("slowcloser", "menu") === "loading",
            "slow menu starts loading")
        root.loads.slowcloser.status = Component.Ready
        verify(!testRouter.isOpen("slowcloser") && testRouter.presentedMenuId === ""
            && host.menuContent === null, "an async-loaded menu that closes during open() stays closed")
        verify(testRouter.contributionState("slowcloser", "menu") === "unloaded"
            && testRouter.contributionError("slowcloser", "menu") === "",
            "closing during the async open() unloads without an error: "
            + testRouter.contributionState("slowcloser", "menu") + " "
            + testRouter.contributionError("slowcloser", "menu"))
        verifyParked(host, "host after an async close during open()")

        verify(testRouter.open("reopener", "") === "ok", "reopener opens")
        var reopener = host.menuContent
        root.reopenOnClose = "reopener"
        verify(testRouter.close("reopener") === "ok", "close returns ok when close() reopens")
        verify(testRouter.isOpen("reopener") && host.menuContent === reopener
            && testRouter.presentedMenuId === "reopener",
            "a close() that reopens the menu leaves it presented")
        verify(testRouter.contributionState("reopener", "menu") === "loaded"
            && testRouter.contributionInstances("reopener", "menu")[0] === reopener,
            "the reopened menu without keepLoaded is not unloaded underneath its host")
        verify(testRouter.close("reopener") === "ok"
            && testRouter.contributionState("reopener", "menu") === "unloaded",
            "an ordinary close then unloads it")
        verifyParked(host, "host after the reopener closes")

        verify(testRouter.open("panel", JSON.stringify({ closeDuringOpen: true })) === "ok",
            "closing from a hosted panel's open() returns ok")
        verify(!testRouter.isOpen("panel") && testRouter.presentedId === "" && !panelHost.visible,
            "the panel that closed itself during open() stays closed")
        verify(testRouter.contributionState("panel", "panel") === "loaded"
            && testRouter.contributionError("panel", "panel") === "",
            "closing during a panel's open() is not an error")

        verify(testRouter.open("panel", "") === "ok" && testRouter.presentedId === "panel", "panel reopens")
        root.closeOnParent = "closer"
        verify(testRouter.open("closer", "") === "ok",
            "closing from the menu's parent handler during present returns ok")
        verify(!testRouter.isOpen("closer") && testRouter.presentedMenuId === ""
            && host.menuContent === null,
            "a menu that closed itself while presenting leaves no presented menu: "
            + testRouter.presentedMenuId)
        verifyParked(host, "host after a close during present")
        verify(testRouter.isOpen("panel") && testRouter.presentedId === "panel" && panelHost.visible,
            "a menu that closed itself while presenting leaves the open panel alone")
        testRouter.dismissPanels()

        root.closeOnParent = "panel"
        verify(testRouter.open("panel", "") === "ok",
            "closing from the panel's parent handler during present returns ok")
        verify(!testRouter.isOpen("panel") && testRouter.presentedId === "" && !panelHost.visible
            && panelHost.panelContent === null,
            "a panel that closed itself while presenting leaves no presented panel: "
            + testRouter.presentedId)
        verify(root.closeOnParent === "", "both re-entrant closes ran")
    }

    // The compositor can focus the shown surface, and send keys, before the
    // surface grows. The content must hold focus from present on, unpainted.
    function checkPresentBeforeGrowth() {
        var host = menuHost(focusedId())
        verify(testRouter.open("menu", JSON.stringify({ mode: "combi" })) === "ok", "menu opens")
        var menu = host.menuContent
        verify(!host.drawn && host.width === 1, "the surface has not grown yet")
        verify(stageOf(host).opacity === 0, "nothing is painted before the surface grows")
        verify(host.color.a === 0, "the 1x1 frame is transparent")
        verify(menu.visible && menu.field.inputItem.visible,
            "the content is visible before the surface grows, so it can hold focus")
        verify(menu.field.inputItem.focus && menu.focus, "focus is assigned to the field on present")
    }

    // Keys typed right after opening reach the field in order.
    function checkImmediateKeys() {
        var host = menuHost(focusedId())
        var menu = host.menuContent
        verify(JSON.stringify(menuKeys) === JSON.stringify(["t", "e", "r", "m", "key:" + Qt.Key_Down]),
            "every key reached the field in order: " + JSON.stringify(menuKeys))
        verify(menu.field.text === "term" && menu.downCount === 1,
            "text and navigation keys took effect: " + menu.field.text)
        verify(probeInput.text === "acd", "the toplevel saw none of the keys: " + probeInput.text)
        verify(remappedAt === 0, "an unstalled surface is not remapped")
    }

    // A parked surface that last committed under a window gets no frame
    // callbacks, so Qt stops rendering it. The host remaps it well before the
    // compositor would have sent several keys elsewhere.
    function checkStalledOpen() {
        var host = menuHost(focusedId())
        verify(host.drawn && stageOf(host).opacity === 1, "the stalled menu shows")
        verify(remappedAt > 0, "a stalled surface is remapped")
        verify(remappedAt - presentedAt < 100,
            "the stall is caught within 100 ms: " + (remappedAt - presentedAt) + " ms")
        verify(stageOf(host).Window.window !== presentWindow, "the menu shows on a fresh surface")
        verify(host.menuContent.field.inputItem.activeFocus, "the field holds focus after a remap")
    }

    // A menu still loading when focus moves to another output is cancelled,
    // including when a panel on the old output is dismissed by the same move.
    function checkQueuedMenuFocusChange() {
        var focused = focusedId()
        var other = otherId()
        var host = menuHost(focused)
        var otherHost = menuHost(other)
        verify(testRouter.open("panel", "") === "ok" && testRouter.presentedId === "panel",
            "panel opens on the focused output")
        verify(testRouter.open("slowmenu", "") === "ok" && testRouter.pendingCount("slowmenu") === 1
            && testRouter.contributionState("slowmenu", "menu") === "loading",
            "slow menu is queued while it loads")
        testCompositor.focusedOutputId = other
        verify(!testRouter.isOpen("slowmenu") && testRouter.pendingCount("slowmenu") === 0
            && testRouter.placementOutputId("slowmenu") === "",
            "a focused-output change cancels the queued menu")
        verify(!testRouter.isOpen("panel"), "the panel on the old output is dismissed")
        root.loads.slowmenu.status = Component.Ready
        verify(testRouter.contributionState("slowmenu", "menu") === "loaded",
            "the keepLoaded menu still finishes loading")
        verify(testRouter.presentedMenuId === "" && host.menuContent === null
            && otherHost.menuContent === null, "the cancelled menu never presents")
        verifyParked(host, "previously focused host after a cancelled menu")
        verifyParked(otherHost, "newly focused host after a cancelled menu")
        testCompositor.focusedOutputId = focused
    }

    // Content destroyed by something other than the router.
    function startDestroyedMenu() {
        verify(testRouter.open("menu", "") === "ok" && menuHost(focusedId()).menuContent !== null,
            "menu shown before its content is destroyed")
        menuHost(focusedId()).menuContent.destroy()
    }

    function checkDestroyedMenu() {
        var host = menuHost(focusedId())
        verify(!testRouter.isOpen("menu") && testRouter.presentedMenuId === ""
            && testRouter.activeId === "", "destroyed menu content ends its route")
        verify(testRouter.contributionState("menu", "menu") === "unloaded"
            && testRouter.contributionInstances("menu", "menu").length === 0,
            "destroyed keepLoaded content is not cached as loaded: "
            + testRouter.contributionState("menu", "menu"))
        verifyParked(host, "host after its content was destroyed")
        verify(testRouter.open("menu", "") === "ok" && host.menuContent !== null
            && host.menuContent.opened, "the next open constructs a fresh menu")
        verify(testRouter.close("menu") === "ok", "fresh menu closes")

        var panelHost = testRouter.panelHosts[focusedId()]
        verify(testRouter.open("panel", "") === "ok" && panelHost.panelContent !== null,
            "panel shown before its content is destroyed")
        panelHost.panelContent.destroy()
    }

    function checkDestroyedPanel() {
        var panelHost = testRouter.panelHosts[focusedId()]
        verify(!testRouter.isOpen("panel") && testRouter.presentedId === "" && !panelHost.visible,
            "destroyed panel content ends its route")
        verify(testRouter.contributionState("panel", "panel") === "unloaded"
            && testRouter.contributionInstances("panel", "panel").length === 0,
            "destroyed per-output panel content unloads the contribution")
        verify(testRouter.open("panel", "") === "ok" && panelHost.visible
            && panelHost.panelContent.opened, "the next open constructs fresh panels")
        testRouter.dismissPanels()
    }

    function startScreenRemoval() {
        testRouter.open("menu", JSON.stringify({ outputId: otherId() }))
        verify(menuHost(otherId()).menuContent !== null, "menu shown on the second output")
        root.testScreens = [Quickshell.screens[0]]
    }

    function checkScreenRemoval() {
        verify(Object.keys(testRouter.menuHosts).length === 1, "removed output releases its menu host")
        verify(!testRouter.isOpen("menu") && testRouter.presentedMenuId === "",
            "removing the menu's output closes the menu")
        verify(testRouter.contributionInstances("menu", "menu")[0].parent === null,
            "the cached menu leaves the destroyed host")
        verifyParked(menuHost(focusedId()), "surviving host")
    }

    Timer {
        interval: 200
        running: true
        onTriggered: {
            try {
                root.verify(Object.keys(testRouter.menuHosts).length === 2, "one menu host per output")
                root.verify(Object.keys(testRouter.panelHosts).length === 2, "panel hosts still created")
                root.verifyParked(root.menuHost(root.focusedId()), "first host at startup")
                root.verifyParked(root.menuHost(root.otherId()), "second host at startup")
                root.phase = "ready"
            } catch (error) {
                console.error("MENU_HOST_FAIL", error, error.stack)
                Qt.exit(1)
            }
        }
    }

    IpcHandler {
        target: "menu-host-test"
        function phase(): string { return root.phase }
        function state(): string { return root.stateJson() }
        function open(payload: string): string { return testRouter.open("menu", payload) }
        function openTimed(): string { return root.openTimed() }
        function close(): string { return testRouter.close("menu") }
        function run(step: string): string {
            try {
                if (step === "openGeometry") root.checkOpenGeometry()
                else if (step === "keys") root.checkKeys()
                else if (step === "presentBeforeGrowth") root.checkPresentBeforeGrowth()
                else if (step === "immediateKeys") root.checkImmediateKeys()
                else if (step === "stalledOpen") root.checkStalledOpen()
                else if (step === "resetKeys") {
                    var cached = testRouter.contributionInstances("menu", "menu")[0]
                    cached.field.text = ""
                    cached.downCount = 0
                    root.menuKeys = []
                    root.presentedAt = 0
                    root.remappedAt = 0
                }
                else if (step === "bannerAndPanels") root.checkBannerAndPanels()
                else if (step === "presses") root.checkPresses()
                else if (step === "icons") root.checkIcons()
                else if (step === "iconsGated") root.checkIconsGated()
                else if (step === "iconsAfterFrame") root.checkIconsAfterFrame()
                else if (step === "router") root.checkRouter()
                else if (step === "reentrant") root.checkReentrantRoutes()
                else if (step === "queuedFocus") root.checkQueuedMenuFocusChange()
                else if (step === "startDestroyedMenu") root.startDestroyedMenu()
                else if (step === "destroyedMenu") root.checkDestroyedMenu()
                else if (step === "destroyedPanel") root.checkDestroyedPanel()
                else if (step === "startScreenRemoval") root.startScreenRemoval()
                else if (step === "screenRemoval") root.checkScreenRemoval()
                else if (step === "parked") root.verifyParked(root.menuHost(root.focusedId()), "host after close")
                else if (step === "finish") {
                    console.log("MENU_HOST_OK", root.checks)
                    Qt.callLater(Qt.quit)
                } else throw new Error("unknown step " + step)
                return "ok"
            } catch (error) {
                console.error("MENU_HOST_FAIL", step, error, error.stack)
                return "fail: " + error
            }
        }
    }
}
