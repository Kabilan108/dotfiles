const assert = require("node:assert/strict")
const L = require("./load.js")

const Calc = L.providers.calc
const Web = L.providers.web

// Calc gating
const mathPositives = [
    "2+2*3", "2 + 2", "1/3", "2^10", "(1+2)*3", "-5 + 3", "10 mod 3", "5!", "50%", "15% of 80",
    "sqrt(2)", "sqrt 2", "sin(pi/2)", "log10(1000)", "2*pi", "1,000 * 3", "3.5e3 / 7", "7 × 6", "8 ÷ 2",
    "5 km to mi", "5km to mi", "100 usd in eur", "32 °F to °C", "1 GB in MB", "3 days in hours",
    "2 light years to km", "sqrt(2", "(4)",
    "sin(pi)", "sqrt(pi)", "pi+e", "2pi", "2 pi", "2π", "e^2", "pi * 2", "cos(tau/4)"
]
const mathNegatives = [
    "", "   ", "2048", "7zip", "7-Zip", "0ad", "2fa", "1password", "x264", "mp3", "4k video downloader",
    "3d", "1.5", "-5", "+1", "192.168.1.1", "2024-10-05", "2+", "*5", "2 2", "nix flake", "f1 2024",
    "4 in a row", "2 to 4", "9to5mac", "e", "pi", "1 & 2", "1; rm -rf /", "$(id)", "log", "ghost",
    "x".repeat(300) + "1+1", "π", "tau", "pie", "ee", "e e", "pi pi", "e2", "sin", "sqrt", "2pi3", "pi2",
    "phi 2", "exit", "2026-01-31", "10.0.0.1"
]
for (const input of mathPositives) assert.equal(Calc.looksLikeMath(input), true, `math: ${input}`)
for (const input of mathNegatives) assert.equal(Calc.looksLikeMath(input), false, `not math: ${input}`)

// URL detection
const urls = [
    ["example.com", "https://example.com"],
    ["github.com/foo/bar?x=1#y", "https://github.com/foo/bar?x=1#y"],
    ["news.ycombinator.com", "https://news.ycombinator.com"],
    ["sole-pierce.ts.net:8443/x", "https://sole-pierce.ts.net:8443/x"],
    ["x.com", "https://x.com"],
    ["http://localhost:5173", "http://localhost:5173"],
    ["https://example.com/a b".split(" ")[0], "https://example.com/a"],
    ["HTTPS://EXAMPLE.COM", "HTTPS://EXAMPLE.COM"]
]
for (const [input, expected] of urls) assert.equal(Web.detectUrl(input), expected, `url: ${input}`)
const notUrls = [
    "", "ghost", "org.gnome.Nautilus", "com.obsproject.Studio", "notes.txt", "foo.", ".com", "a..com",
    "javascript:alert(1)", "file:///etc/passwd", "ftp://example.com", "mailto:a@b.com",
    "https://bank.com@evil.example", "https://", "http:// spaced.com", "example.com/a b", "192.168.1.1",
    "-bad.com", "bad-.com", "https://" + "a".repeat(9000) + ".com",
    "obsidian.md", "README.md", "main.go", "setup.py", "lib.rs", "install.sh", "app.js", "index.ts",
    "script.pl", "model.ai", "flake.nix", "notes.txt", "Cargo.lock", "a.zip", "clip.mov", "song.mp3",
    "report.pdf", "shot.png", "x.json", "config.yaml", "query.sql", "Main.java", "gem.rb", "lib.so",
    "src/main.rs", "docs.md/x"
]
for (const input of notUrls) assert.equal(Web.detectUrl(input), "", `not url: ${input}`)

// Web search template encoding
assert.equal(Web.searchUrl("https://unduck.link?q=%TERM%", "c++ & rust"), "https://unduck.link?q=c%2B%2B%20%26%20rust")
assert.equal(Web.searchUrl("https://x.test/%TERM%/%TERM%", "a b"), "https://x.test/a%20b/a%20b")

// Clipboard
{
    const engine = L.createEngine()
    const items = [
        { id: "old", kind: "text", preview: "ssh-ed25519 AAAA key", mime: "text/plain", bytes: 20, createdAt: 10, lastUsed: 10 },
        { id: "img", kind: "image", preview: "", mime: "image/png", bytes: 34816, createdAt: 30, lastUsed: 30, path: "/state/clipboard/blobs/abc" },
        { id: "new", kind: "text", preview: "  line one\n\n  line two  ", mime: "text/plain", bytes: 24, createdAt: 20, lastUsed: 50 },
        { id: "token", kind: "text", preview: "ghp_tokenvalue", mime: "text/plain", bytes: 14, createdAt: 40, lastUsed: 40 },
        { id: "new", kind: "text", preview: "duplicate id", mime: "text/plain", bytes: 1, createdAt: 1, lastUsed: 1 },
        { kind: "text", preview: "no id" }
    ]
    const env = { clipboardItems: items, now: L.NOW }
    const all = engine.run("", "clipboard", env).rows
    assert.deepEqual(all.map(row => row.itemId), ["new", "token", "img", "old"], "newest lastUsed first")
    assert.equal(all[0].text, "line one line two")
    assert.deepEqual(all[0].preview, { kind: "text", text: "  line one\n\n  line two  " })
    assert.deepEqual(all[2].preview, { kind: "image", path: "/state/clipboard/blobs/abc" })
    assert.equal(all[2].subtext, "image/png · 34 KB")
    assert.deepEqual(all[0].actions.map(action => action.id), ["copy", "remove", "clear"])
    assert.deepEqual(engine.activate(all[0], ""), { type: "clipboard.copy", id: "new" })
    assert.deepEqual(engine.activate(all[0], "remove"), { type: "clipboard.remove", id: "new", keepOpen: true })
    assert.deepEqual(engine.activate(all[3], "clear"), { type: "clipboard.clear" })
    assert.equal(engine.activate(all[0], "paste"), null)

    assert.deepEqual(engine.run(":image", "combi", env).rows.map(row => row.itemId), ["img"])
    assert.deepEqual(engine.run(":png", "combi", env).rows.map(row => row.itemId), ["img"])
    assert.deepEqual(engine.run(":line two", "combi", env).rows.map(row => row.itemId), ["new"])
    assert.equal(engine.run(":key", "combi", env).rows[0].itemId, "old", "matches late in the text still rank")
    assert.equal(engine.run(":zzz", "combi", env).rows.length, 0)
}

// Calc and files providers ignore results for other text, also when called directly
{
    const engine = L.createEngine()
    const ctx = engine.context({ calcResult: { text: "1+1", value: "2" } }, "1+2", "combi")
    assert.deepEqual(Calc.query("1+2", ctx), [])
    assert.equal(Calc.pending("1+2", ctx), "1+2")
    const files = L.providers.files
    const fctx = engine.context({ filesResult: { text: "a", paths: ["/a"] } }, "/b", "combi")
    assert.deepEqual(files.query("b", fctx), [])
    assert.equal(files.pending("b", fctx), "b")
    assert.equal(files.pending("", fctx), "")
}

// Intents: only the declared types and fields, never a command line
{
    const engine = L.createEngine()
    const env = {
        apps: L.APPS,
        windows: L.WINDOWS,
        profiles: { active: "a", available: [{ id: "a", name: "A", description: "" }, { id: "b", name: "B", description: "" }] },
        clipboardItems: [{ id: "c", kind: "text", preview: "x", mime: "text/plain", bytes: 1, createdAt: 1, lastUsed: 1 }],
        filesResult: { text: "notes", paths: ["/home/t/notes.md"] },
        calcResult: { text: "1+1", value: "2", error: "" },
        settings: { searchRoot: "/home/t" },
        now: L.NOW
    }
    const runs = [
        ["", "combi"], ["e", "combi"], ["1+1", "combi"], ["example.com", "combi"], ["@q", "combi"],
        ["$", "combi"], [":", "combi"], ["/notes", "combi"], ["", "power"], ["", "profiles"], ["", "windows"]
    ]
    const forbidden = /^(command|cmd|argv|args|exec|line|shell|script|program)$/i
    let checked = 0
    const typesSeen = new Set()
    for (const [input, mode] of runs) {
        for (const row of engine.run(input, mode, env).rows) {
            for (const action of row.actions) {
                const direct = L.providers[row.provider].activate(row, action.id)
                assert.ok(L.Engine.validIntent(direct), `${row.key} ${action.id} -> ${JSON.stringify(direct)}`)
                assert.deepEqual(engine.activate(row, action.id), direct)
                for (const key of Object.keys(direct)) assert.equal(forbidden.test(key), false, `${key} in ${direct.type}`)
                typesSeen.add(direct.type)
                checked++
            }
            assert.ok(L.Engine.validIntent(engine.activate(row, "")), `${row.key} default action`)
        }
    }
    assert.ok(checked > 40)
    assert.deepEqual([...typesSeen].sort(), Object.keys(L.Engine.INTENT_FIELDS).sort(), "every intent type is produced")

    const invalid = [
        null, {}, { type: "command.run", line: "rm -rf ~" }, { type: "app.launch", desktopId: "x", command: "sh" },
        { type: "url.open", url: "javascript:alert(1)" }, { type: "url.open", url: "file:///etc/passwd" },
        { type: "path.open", path: "relative" }, { type: "session", action: "rm" },
        { type: "text.copy", text: ["a"] }, { type: "clipboard.remove", id: "x", keepOpen: "yes" },
        { type: "window.focus" }, { type: "__proto__" }, { type: "toString" },
        { type: "window.focus", id: "3" }, { type: "window.focus", id: 0 }, { type: "window.focus", id: -2 },
        { type: "window.focus", id: 1.5 }, { type: "window.focus", id: 2 ** 53 }, { type: "window.focus", id: NaN },
        { type: "window.focus", id: Infinity }, { type: "app.launch", desktopId: 5 }, { type: "app.launch", desktopId: "" },
        { type: "app.launch", desktopId: "a\u0000b" }, { type: "app.launch", desktopId: "a", actionId: 5 },
        { type: "app.launch", desktopId: "a", actionId: "" }, { type: "app.launch", desktopId: "a", actionId: null },
        { type: "text.copy", text: 5 }, { type: "text.copy" }, { type: "clipboard.copy", id: 7 },
        { type: "clipboard.remove", id: "" }, { type: "profile.activate", id: {} }, { type: "profile.activate", id: 1 },
        { type: "url.open", url: 5 }, { type: "url.open", url: "https://a b" }, { type: "url.open", url: "https://" },
        { type: "url.open", url: "https://x.test/" + "a".repeat(9000) }, { type: "path.open", path: "/a\u0000b" },
        { type: "path.reveal", path: 5 }, { type: "path.open", path: "" }, { type: "session", action: 1 },
        { type: "clipboard.clear", id: "x" }, { type: "text.copy", text: "x", extra: 1 }, [], "url.open", 5,
        Object.assign(Object.create({ text: "inherited" }), { type: "text.copy" })
    ]
    for (const intent of invalid) assert.equal(L.Engine.validIntent(intent), false, JSON.stringify(intent))

    const hostile = [
        { type: "text.copy", get text() { throw new Error("getter") } },
        new Proxy({}, { ownKeys() { throw new Error("ownKeys") }, get() { throw new Error("get") } }),
        new Proxy({ type: "text.copy", text: "x" }, { getOwnPropertyDescriptor() { throw new Error("descriptor") } })
    ]
    for (const intent of hostile) assert.equal(L.Engine.validIntent(intent), false)

    const valid = [
        { type: "window.focus", id: 3 }, { type: "window.focus", id: 2 ** 53 - 1 },
        { type: "app.launch", desktopId: "a" }, { type: "app.launch", desktopId: "a", actionId: "b" },
        { type: "text.copy", text: "" }, { type: "clipboard.remove", id: "x", keepOpen: true },
        { type: "clipboard.clear" }, { type: "path.reveal", path: "/" }, { type: "url.open", url: "http://localhost:5173" }
    ]
    for (const intent of valid) assert.equal(L.Engine.validIntent(intent), true, JSON.stringify(intent))
}

console.log("providers: ok")
