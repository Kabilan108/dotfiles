const path = require("node:path")
const { syntheticApps } = require("./synthetic-apps.js")

const modelDir = path.join(__dirname, "../../plugins/builtin/launcher/model")
const providerNames = ["apps", "calc", "web", "windows", "power", "profiles", "files", "clipboard", "remmina"]

const Matcher = require(path.join(modelDir, "Matcher.js"))
const History = require(path.join(modelDir, "History.js"))
const Query = require(path.join(modelDir, "Query.js"))
const Engine = require(path.join(modelDir, "Engine.js"))
const providers = {}
for (const name of providerNames) providers[name] = require(path.join(modelDir, "providers", name + ".js"))

function createEngine() {
    return Engine.create({
        Matcher,
        History,
        Query,
        providers: providerNames.map(name => providers[name])
    })
}

function app(id, name, extra) {
    return Object.assign({
        id,
        name,
        genericName: "",
        comment: "",
        keywords: [],
        icon: id,
        categories: [],
        actions: [],
        runInTerminal: false
    }, extra || {})
}

const APPS = [
    app("com.mitchellh.ghostty", "Ghostty", {
        genericName: "Terminal",
        comment: "A terminal emulator",
        keywords: ["shell", "prompt", "command", "commandline"],
        actions: [{ id: "new-window", name: "New Window", icon: "" }]
    }),
    app("org.gnome.Extensions", "Extensions", { comment: "Manage GNOME Shell extensions" }),
    app("obsidian", "Obsidian", { comment: "Knowledge base", keywords: ["notes"] }),
    app("com.obsproject.Studio", "OBS Studio", {
        genericName: "Streaming/Recording Software",
        keywords: ["streaming", "recording", "capture"]
    }),
    app("code", "Visual Studio Code", {
        genericName: "Text Editor",
        comment: "Code Editing. Redefined.",
        keywords: ["vscode"],
        actions: [{ id: "new-empty-window", name: "New Empty Window", icon: "" }]
    }),
    app("org.gnome.Calculator", "Calculator", {
        comment: "Perform arithmetic, scientific or financial calculations",
        keywords: ["calculation", "arithmetic", "scientific", "financial"]
    }),
    app("helium", "Helium", { genericName: "Web Browser", keywords: ["browser", "web"] }),
    app("zen", "Zen Browser", { genericName: "Web Browser" }),
    app("org.gnome.Nautilus", "Files", { genericName: "File Manager", keywords: ["folder", "manager", "explore"] }),
    app("vesktop", "Vesktop", { comment: "Discord client", keywords: ["discord", "chat"] }),
    app("virt-manager", "Virtual Machine Manager", { comment: "Manage virtual machines" }),
    app("btop", "btop++", { comment: "Resource monitor", runInTerminal: true }),
    app("2048", "2048", { comment: "Puzzle game" }),
    app("7zip", "7-Zip", { comment: "Archiver" })
]

function windowOf(id, title, appId, secs, extra) {
    return Object.assign({
        id,
        title,
        app_id: appId,
        pid: 1000 + id,
        workspace_id: 1,
        is_focused: false,
        focus_timestamp: secs === null ? null : { secs, nanos: 0 },
        workspaceName: "1",
        outputName: "DP-1"
    }, extra || {})
}

const WINDOWS = [
    windowOf(1, "GitHub - Helium", "helium", 100),
    windowOf(2, "~/shell — Ghostty", "com.mitchellh.ghostty", 400, { is_focused: true }),
    windowOf(3, "Docs - Helium", "helium", 300),
    windowOf(4, "Never focused - Helium", "helium", null),
    windowOf(5, "Notes - Obsidian", "obsidian", 200)
]

const DAY = 24 * 60 * 60 * 1000
const NOW = Date.UTC(2026, 9, 5, 12, 0, 0)

module.exports = {
    Matcher,
    History,
    Query,
    Engine,
    providers,
    providerNames,
    modelDir,
    createEngine,
    app,
    APPS,
    WINDOWS,
    windowOf,
    DAY,
    NOW,
    syntheticApps
}
