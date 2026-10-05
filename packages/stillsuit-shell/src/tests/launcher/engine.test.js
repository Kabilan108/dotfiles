const assert = require("node:assert/strict")
const L = require("./load.js")

function baseEnv(extra) {
    return Object.assign({
        apps: L.APPS,
        windows: L.WINDOWS,
        profiles: {
            active: "work",
            available: [
                { id: "default", name: "Default", description: "Base plugins" },
                { id: "work", name: "Work", description: "Work plugins" },
                { id: "gaming", name: "Gaming", description: "Fewer widgets" }
            ]
        },
        clipboardItems: [],
        history: L.History.create(null),
        settings: { webEngine: "https://unduck.link?q=%TERM%", maxResults: 100, searchRoot: "/home/tony" },
        now: L.NOW
    }, extra || {})
}

const texts = rows => rows.map(row => row.text)

// ghost -> Ghostty first
{
    const engine = L.createEngine()
    const result = engine.run("ghost", "combi", baseEnv())
    assert.equal(result.rows[0].text, "Ghostty")
    assert.deepEqual(result.rows[0].positions, [0, 1, 2, 3, 4])
    assert.deepEqual(result.providerIds, ["calc", "apps", "web"])
    const last = result.rows[result.rows.length - 1]
    assert.equal(last.key, "web:search", "web fallback is the trailing row")
    assert.equal(last.text, "Search the web for ghost")
}

// obs: OBS Studio and Obsidian tie on match score; three Obsidian launches
// from "obs" put Obsidian on top.
{
    const engine = L.createEngine()
    const env = baseEnv()
    const before = engine.run("obs", "combi", env).rows
    assert.equal(before[0].text, "OBS Studio", "ties sort by text")
    assert.equal(before[1].text, "Obsidian")
    const obsidian = before[1]
    for (let launch = 0; launch < 3; launch++) {
        assert.equal(engine.record(env.history, "obs", obsidian, L.NOW - 1000 * launch), true)
    }
    const after = engine.run("obs", "combi", env).rows
    assert.equal(after[0].text, "Obsidian")
    assert.equal(after[1].text, "OBS Studio")
    assert.equal(after[0].score - after[1].score, 30, "boost is (10 - 0 days) * 3")
    const prefixQuery = engine.run("obsi", "combi", env).rows
    assert.equal(prefixQuery[0].text, "Obsidian", "a longer related query is still boosted")
}

// vsc -> Visual Studio Code via acronym
{
    const engine = L.createEngine()
    const rows = engine.run("vsc", "combi", baseEnv()).rows
    assert.equal(rows[0].text, "Visual Studio Code")
    assert.deepEqual(rows[0].positions, [0, 7, 14])
}

// 2+2*3: calc row on top once the answer for this exact text arrives
{
    const engine = L.createEngine()
    const waiting = engine.run("2+2*3", "combi", baseEnv())
    assert.equal(waiting.pending.calc, "2+2*3")
    assert.equal(waiting.rows.some(row => row.provider === "calc"), false)

    const stale = engine.run("2+2*3", "combi", baseEnv({ calcResult: { text: "2+2*", value: "4", error: "" } }))
    assert.equal(stale.rows.some(row => row.provider === "calc"), false, "a stale answer never shows")
    assert.equal(stale.pending.calc, "2+2*3")

    const answered = engine.run("2+2*3", "combi", baseEnv({ calcResult: { text: "2+2*3", value: "8", error: "" } }))
    assert.equal(answered.rows[0].provider, "calc")
    assert.equal(answered.rows[0].text, "8")
    assert.equal(answered.pending.calc, undefined, "nothing left to compute")
    assert.deepEqual(engine.activate(answered.rows[0], ""), { type: "text.copy", text: "8" })

    const failed = engine.run("2+2*3", "combi", baseEnv({ calcResult: { text: "2+2*3", value: "", error: "parse error" } }))
    assert.equal(failed.rows.some(row => row.provider === "calc"), false, "errors show no row")

    const app = engine.run("2048", "combi", baseEnv({ calcResult: { text: "2048", value: "2048", error: "" } }))
    assert.equal(app.pending.calc, undefined, "app names that are numbers do not start qalc")
    assert.equal(app.rows[0].text, "2048")
}

// @nix flake -> web only, Unduck row
{
    const engine = L.createEngine()
    const result = engine.run("@nix flake", "combi", baseEnv())
    assert.deepEqual(result.providerIds, ["web"])
    assert.equal(result.prefix, "@")
    assert.equal(result.text, "nix flake")
    assert.deepEqual(result.rows.map(row => row.key), ["web:search"])
    assert.equal(result.rows[0].url, "https://unduck.link?q=nix%20flake")
    assert.deepEqual(engine.activate(result.rows[0], ""), { type: "url.open", url: "https://unduck.link?q=nix%20flake" })
    assert.equal(result.rows[0].trailing, false)

    const spaced = engine.run("@   nix   flake  ", "combi", baseEnv())
    assert.equal(spaced.text, "nix   flake")
    assert.equal(engine.run("@", "combi", baseEnv()).rows.length, 0, "@ alone has no rows")

    const encoded = engine.run("@a&b=c#d", "combi", baseEnv())
    assert.equal(encoded.rows[0].url, "https://unduck.link?q=a%26b%3Dc%23d")

    const custom = engine.run("@q", "combi", baseEnv({ settings: { webEngine: "https://duckduckgo.com/?q=%TERM%&ia=web" } }))
    assert.equal(custom.rows[0].url, "https://duckduckgo.com/?q=q&ia=web")
    const unsafe = engine.run("@q", "combi", baseEnv({ settings: { webEngine: "javascript:alert(%TERM%)" } }))
    assert.equal(unsafe.rows[0].url, "https://unduck.link?q=q", "a non-http engine falls back to the default")
}

// URL rows
{
    const engine = L.createEngine()
    const bare = engine.run("github.com/foo", "combi", baseEnv()).rows
    assert.equal(bare[0].key, "web:url")
    assert.equal(bare[0].text, "Open https://github.com/foo")
    assert.deepEqual(engine.activate(bare[0], ""), { type: "url.open", url: "https://github.com/foo" })
    assert.deepEqual(engine.activate(bare[0], "copy"), { type: "text.copy", text: "https://github.com/foo" })
    const prefixed = engine.run("@https://example.com", "combi", baseEnv()).rows
    assert.deepEqual(prefixed.map(row => row.key), ["web:url", "web:search"])
    assert.equal(prefixed[0].url, "https://example.com")
}

// The web fallback never outranks an app match and only takes a free slot
{
    const engine = L.createEngine()
    const many = L.syntheticApps(300)
    const full = engine.run("a", "combi", baseEnv({ apps: many, settings: { maxResults: 20 } }))
    assert.equal(full.rows.length, 20)
    assert.equal(full.rows.every(row => row.provider === "apps"), true, "a full list has no fallback row")
    const one = engine.run("ghost", "combi", baseEnv({ settings: { maxResults: 1 } }))
    assert.deepEqual(one.rows.map(row => row.key), ["apps:com.mitchellh.ghostty"])
    const two = engine.run("ghost", "combi", baseEnv({ settings: { maxResults: 2 } }))
    assert.deepEqual(two.rows.map(row => row.key), ["apps:com.mitchellh.ghostty", "web:search"])
    const none = engine.run("qqqq", "combi", baseEnv({ settings: { maxResults: 1 } }))
    assert.deepEqual(none.rows.map(row => row.key), ["web:search"])
    assert.equal(engine.run("", "combi", baseEnv()).rows.some(row => row.provider === "web"), false,
        "empty text has no web row")
}

// Inferred URLs rank below real matches; explicit ones stay on top
{
    const engine = L.createEngine()
    const apps = L.APPS.concat([L.app("xcom", "X.com Desktop")])
    const inferred = engine.run("x.com", "combi", baseEnv({ apps })).rows
    assert.deepEqual(inferred.map(row => row.key), ["apps:xcom", "web:url", "web:search"])
    assert.equal(inferred[1].score, L.providers.web.INFERRED_URL_SCORE)
    const explicit = engine.run("https://x.com", "combi", baseEnv({ apps })).rows
    assert.equal(explicit[0].key, "web:url")
    assert.equal(explicit[0].score, L.providers.web.URL_SCORE)
    const alone = engine.run("example.com", "combi", baseEnv()).rows
    assert.deepEqual(alone.map(row => row.key), ["web:url", "web:search"], "with no app match the URL row leads")
    assert.equal(engine.run("notes.md", "combi", baseEnv()).rows.some(row => row.key === "web:url"), false)
}

// $hel -> Helium windows, most recently focused first
{
    const engine = L.createEngine()
    const result = engine.run("$hel", "combi", baseEnv())
    assert.deepEqual(result.providerIds, ["windows"])
    assert.deepEqual(result.rows.map(row => row.windowId).slice(0, 3), [3, 1, 4])
    assert.equal(result.rows.every(row => row.provider === "windows"), true)
    assert.deepEqual(engine.activate(result.rows[0], ""), { type: "window.focus", id: 3 })

    const all = engine.run("$", "combi", baseEnv()).rows
    assert.deepEqual(all.map(row => row.windowId), [3, 5, 1, 4, 2], "focused window last, unfocused-never before it")
    assert.equal(all[4].current, true)
    assert.equal(all[0].subtext, "helium · workspace 1 · DP-1")
    assert.deepEqual(engine.run("", "windows", baseEnv()).rows.map(row => row.windowId), [3, 5, 1, 4, 2])
}

// With a query the focused window keeps its recency position
{
    const engine = L.createEngine()
    const windows = [
        L.windowOf(1, "Docs - Helium", "helium", 100),
        L.windowOf(2, "Mail - Helium", "helium", 300, { is_focused: true }),
        L.windowOf(3, "Chat - Helium", "helium", 200),
        L.windowOf(4, "Terminal", "ghostty", 400)
    ]
    const env = baseEnv({ windows })
    assert.deepEqual(engine.run("", "windows", env).rows.map(row => row.windowId), [4, 3, 1, 2])
    assert.deepEqual(engine.run("hel", "windows", env).rows.map(row => row.windowId), [2, 3, 1],
        "strict recency among good matches")
    assert.deepEqual(engine.run("$helium", "combi", env).rows.map(row => row.windowId), [2, 3, 1])
}

// Empty combi -> apps by usage, then alphabetical
{
    const engine = L.createEngine()
    const history = L.History.create(null)
    history.record("ze", "apps:zen", L.NOW - 2 * L.DAY)
    history.record("ze", "apps:zen", L.NOW - 2 * L.DAY)
    history.record("gh", "apps:com.mitchellh.ghostty", L.NOW - L.DAY)
    history.record("", "apps:helium", L.NOW - 30 * L.DAY)
    const result = engine.run("", "combi", baseEnv({ history }))
    assert.deepEqual(result.providerIds, ["calc", "apps", "web"])
    assert.deepEqual(texts(result.rows).slice(0, 4), ["Zen Browser", "Ghostty", "Helium", "2048"])
    assert.equal(result.rows.length, L.APPS.length)
    assert.deepEqual(result.pending, {})
}

// Power, profiles and clipboard modes
{
    const engine = L.createEngine()
    const power = engine.run("", "power", baseEnv()).rows
    assert.deepEqual(texts(power), ["Lock", "Suspend", "Logout", "Reboot", "Shutdown"])
    assert.deepEqual(power.map(row => row.icon), [
        "system-lock-screen", "system-suspend", "system-log-out", "system-reboot", "system-shutdown"])
    assert.deepEqual(power.map(row => engine.activate(row, "").action),
        ["lock", "suspend", "logout", "reboot", "poweroff"])
    assert.deepEqual(texts(engine.run("sleep", "power", baseEnv()).rows), ["Suspend", "Lock"])
    assert.deepEqual(texts(engine.run("restart", "power", baseEnv()).rows), ["Reboot"])
    assert.deepEqual(texts(engine.run("poweroff", "power", baseEnv()).rows), ["Shutdown"])

    const profiles = engine.run("", "profiles", baseEnv()).rows
    assert.deepEqual(texts(profiles), ["Work", "Default", "Gaming"])
    assert.equal(profiles[0].current, true)
    const searched = engine.run("de", "profiles", baseEnv()).rows
    assert.equal(searched[0].text, "Default", "the current profile is not pinned while searching")
    assert.deepEqual(engine.activate(searched[0], ""), { type: "profile.activate", id: "default" })
}

// Prefix parsing through the engine
{
    const engine = L.createEngine()
    const env = baseEnv({ clipboardItems: [{ id: "a", kind: "text", preview: "hello", mime: "text/plain", bytes: 5, createdAt: 1, lastUsed: 1 }] })
    const slash = engine.run("/", "combi", env)
    assert.deepEqual(slash.providerIds, ["files"])
    assert.equal(slash.text, "")
    assert.deepEqual(slash.pending, {}, "/ alone starts no fd run")
    assert.equal(slash.rows.length, 0)
    const colon = engine.run(":", "combi", env)
    assert.deepEqual(colon.providerIds, ["clipboard"])
    assert.equal(colon.rows.length, 1)
    const inside = engine.run("foo/bar", "combi", env)
    assert.deepEqual(inside.providerIds, ["calc", "apps", "web"], "a prefix char inside a query is literal")
    assert.equal(inside.pending.files, undefined)
    const override = engine.run("$hel", "clipboard", env)
    assert.deepEqual(override.providerIds, ["windows"], "a prefix overrides the mode")
    assert.equal(engine.run("x", "nonsense", env).mode, "combi")
}

// Files: rows only for the current text, relative display, three actions
{
    const engine = L.createEngine()
    const waiting = engine.run("/ notes ", "combi", baseEnv())
    assert.equal(waiting.pending.files, "notes")
    assert.equal(waiting.rows.length, 0)
    const stale = engine.run("/notes", "combi", baseEnv({ filesResult: { text: "note", paths: ["/home/tony/note.md"] } }))
    assert.equal(stale.rows.length, 0, "stale fd output is ignored")
    assert.equal(stale.pending.files, "notes")
    const fresh = engine.run("/notes", "combi", baseEnv({
        filesResult: {
            text: "notes",
            paths: ["/home/tony/work/notes.md", "/home/tony/notes/", "/etc/notes.conf", "relative/notes.txt",
                "/home/tony/work/notes.md", "bad\u0000path"]
        }
    }))
    assert.equal(fresh.pending.files, undefined)
    const byPath = {}
    for (const row of fresh.rows) byPath[row.path] = row
    assert.deepEqual(Object.keys(byPath).sort(), [
        "/etc/notes.conf", "/home/tony/notes/", "/home/tony/relative/notes.txt", "/home/tony/work/notes.md"])
    assert.equal(byPath["/home/tony/work/notes.md"].text, "work/notes.md")
    assert.deepEqual(byPath["/home/tony/work/notes.md"].positions, [5, 6, 7, 8, 9])
    assert.equal(byPath["/home/tony/notes/"].icon, "folder")
    assert.equal(byPath["/etc/notes.conf"].text, "/etc/notes.conf")
    const row = byPath["/home/tony/work/notes.md"]
    assert.deepEqual(row.actions.map(action => action.id), ["open", "reveal", "copy"])
    assert.deepEqual(engine.activate(row, ""), { type: "path.open", path: "/home/tony/work/notes.md" })
    assert.deepEqual(engine.activate(row, "reveal"), { type: "path.reveal", path: "/home/tony/work/notes.md" })
    assert.deepEqual(engine.activate(row, "copy"), { type: "text.copy", text: "/home/tony/work/notes.md" })
    assert.equal(engine.run("notes", "combi", baseEnv({ filesResult: { text: "notes", paths: ["/x/notes"] } }))
        .rows.some(r => r.provider === "files"), false, "files only under the / prefix")
}

// App actions and intent validation
{
    const engine = L.createEngine()
    const ghostty = engine.run("ghost", "combi", baseEnv()).rows[0]
    assert.deepEqual(ghostty.actions.map(action => action.id), ["launch", "action:new-window"])
    assert.deepEqual(engine.activate(ghostty, ""), { type: "app.launch", desktopId: "com.mitchellh.ghostty" })
    assert.deepEqual(engine.activate(ghostty, "action:new-window"),
        { type: "app.launch", desktopId: "com.mitchellh.ghostty", actionId: "new-window" })
    assert.equal(engine.activate(ghostty, "action:rm -rf"), null, "unknown actions are refused")
    assert.equal(engine.activate({ provider: "nope" }, ""), null)
    assert.equal(engine.activate(null, ""), null)
    const search = engine.run("@x", "combi", baseEnv()).rows[0]
    const forged = Object.assign({}, search, { url: "file:///etc/passwd" })
    assert.deepEqual(engine.activate(forged, ""), { type: "url.open", url: "https://unduck.link?q=x" },
        "a copy activates the engine's own row, not the edited fields")
    assert.equal(L.providers.web.activate(forged, ""), null, "non-http urls never become intents")
}

// Only rows from the most recent run activate
{
    const engine = L.createEngine()
    const env = baseEnv({
        clipboardItems: [{ id: "c", kind: "text", preview: "x", mime: "text/plain", bytes: 1, createdAt: 1, lastUsed: 1 }],
        filesResult: { text: "notes", paths: ["/home/tony/notes.md"] },
        calcResult: { text: "1+1", value: "2", error: "" }
    })
    const runs = [
        ["ghost", "combi"], ["1+1", "combi"], ["example.com", "combi"], ["@q", "combi"], ["$", "combi"],
        [":", "combi"], ["/notes", "combi"], ["", "power"], ["", "profiles"]
    ]
    const providersSeen = new Set()
    for (const [input, mode] of runs) {
        const first = engine.run(input, mode, env).rows
        assert.ok(first.length > 0, input)
        const firstIntent = engine.activate(first[0], "")
        assert.ok(L.Engine.validIntent(firstIntent), `${input} activates while current`)
        const second = engine.run(input, mode, env).rows
        assert.equal(engine.activate(first[0], ""), null, `${first[0].key}: a row from an older run is refused`)
        assert.equal(engine.activate(Object.assign({}, first[0]), ""), null, `${first[0].key}: and so is its copy`)
        assert.deepEqual(engine.activate(second[0], ""), firstIntent, `${second[0].key}: the current row works`)
        assert.deepEqual(engine.activate(Object.assign({}, second[0]), ""), firstIntent,
            `${second[0].key}: a copy of the current row works`)
        for (const row of first) providersSeen.add(row.provider)
    }
    assert.deepEqual([...providersSeen].sort(), L.providerNames.slice().sort(), "every provider is covered")

    const ghostty = engine.run("ghost", "combi", env).rows[0]
    engine.run("obs", "combi", env)
    assert.equal(engine.activate(ghostty, "action:new-window"), null, "a later keystroke invalidates the row")
    const other = L.createEngine()
    assert.equal(other.activate(engine.run("ghost", "combi", env).rows[0], ""), null, "rows belong to their engine")
    assert.equal(engine.activate({ key: "apps:obsidian", provider: "apps", desktopId: "obsidian" }, ""), null,
        "a hand-built row is refused")
    assert.equal(engine.activate(new Proxy({}, { get() { throw new Error("hostile") } }), ""), null)
}

// run() never throws: random UTF-16, lone surrogates, long input
{
    const engine = L.createEngine()
    const env = baseEnv({
        clipboardItems: [{ id: "c", kind: "text", preview: "x\uD800y", mime: "text/plain", bytes: 1, createdAt: 1, lastUsed: 1 }]
    })
    const edge = "@" + "x".repeat(1022) + "\u{1F600}"
    const edgeRows = engine.run(edge, "combi", env).rows
    assert.equal(edgeRows.length, 1)
    assert.equal(edgeRows[0].url, "https://unduck.link?q=" + "x".repeat(1022), "the cut pair is dropped whole")
    assert.equal(engine.run("@a\uD800b", "combi", env).rows[0].url, "https://unduck.link?q=a%EF%BF%BDb")
    assert.equal(engine.run("@\uDC00", "combi", env).rows[0].url, "https://unduck.link?q=%EF%BF%BD")

    let seed = 99
    const next = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff)
    const pools = [
        () => 0xD800 + next() % 0x800,
        () => 32 + next() % 95,
        () => next() % 0x10000,
        () => "/@$:+-*/^()%!.e".charCodeAt(next() % 15)
    ]
    const modes = ["combi", "windows", "power", "profiles", "clipboard"]
    for (let iteration = 0; iteration < 3000; iteration++) {
        const length = iteration % 50 === 0 ? 1000 + next() % 100 : next() % 24
        const units = []
        for (let index = 0; index < length; index++) units.push(pools[next() % pools.length]())
        const input = String.fromCharCode.apply(null, units)
        const mode = modes[next() % modes.length]
        let result
        try {
            result = engine.run(input, mode, env)
        } catch (error) {
            assert.fail(`run threw ${error} for ${JSON.stringify(input)} in ${mode}`)
        }
        for (const row of result.rows) {
            const intent = engine.activate(row, "")
            assert.ok(intent === null || L.Engine.validIntent(intent), JSON.stringify(input))
        }
    }
}

// Row keys are unique and stable
{
    const engine = L.createEngine()
    const duplicateApps = L.APPS.concat([L.APPS[0]])
    for (const [input, mode] of [["", "combi"], ["e", "combi"], ["$", "combi"], ["", "power"], ["", "profiles"]]) {
        const first = engine.run(input, mode, baseEnv({ apps: duplicateApps }))
        const keys = first.rows.map(row => row.key)
        assert.equal(new Set(keys).size, keys.length, `unique keys for ${mode} "${input}"`)
        const again = engine.run(input, mode, baseEnv({ apps: duplicateApps.slice() }))
        assert.deepEqual(again.rows.map(row => row.key), keys, `stable keys for ${mode} "${input}"`)
        for (const row of first.rows) assert.equal(row.key.indexOf(row.provider + ":"), 0)
    }
}

// Snapshot preparation is cached by identity or revision
{
    const engine = L.createEngine()
    const env = baseEnv()
    const first = engine.prepare(env).apps
    assert.equal(engine.prepare(env).apps, first, "same snapshot, same prepared list")
    assert.notEqual(engine.prepare(baseEnv({ apps: L.APPS.slice() })).apps, first)
    const revisioned = baseEnv({ revisions: { apps: 7 } })
    const byRevision = engine.prepare(revisioned).apps
    assert.equal(engine.prepare(baseEnv({ apps: L.APPS.slice(), revisions: { apps: 7 } })).apps, byRevision,
        "an unchanged revision skips re-preparing a fresh wrapper")
    assert.notEqual(engine.prepare(baseEnv({ revisions: { apps: 8 } })).apps, byRevision)
}

// Plain history data is accepted and wrapped once
{
    const engine = L.createEngine()
    const data = { version: 1, records: [{ query: "obs", key: "apps:obsidian", count: 3, lastUsed: L.NOW }] }
    const env = baseEnv({ history: data })
    assert.equal(engine.run("obs", "combi", env).rows[0].text, "Obsidian")
}

// leadingRows keeps exactly what a full sort puts first
{
    let seed = 3
    const next = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff)
    const words = ["alpha", "Bravo", "charlie", "delta", "Écho", "zulu", "ä", ""]
    for (let iteration = 0; iteration < 400; iteration++) {
        const count = 1 + next() % 600
        const limit = 1 + next() % 120
        const spread = [1, 3, 50, 100000][iteration % 4]
        const rows = []
        for (let index = 0; index < count; index++) {
            const text = words[next() % words.length] + (iteration % 2 === 0 ? " " + index : "")
            const row = { key: "k" + (iteration % 9 === 0 ? next() % (count + 5) : index), text, score: next() % spread + (iteration % 5 === 0 ? 0.5 : 0) }
            if (index % 3 === 0) row.sortKey = text.toLowerCase()
            rows.push(row)
        }
        const expected = rows.slice().sort(L.Engine.compareRows)
        const kept = L.Engine.leadingRows(rows.slice(), limit)
        const firstDistinct = list => {
            const seen = new Set()
            const result = []
            for (const row of list) {
                if (result.length === limit) break
                if (seen.has(row.key)) continue
                seen.add(row.key)
                result.push(row)
            }
            return result
        }
        assert.deepEqual(firstDistinct(kept), firstDistinct(expected), `count ${count} limit ${limit} spread ${spread}`)
    }
}

// Returned rows are frozen views; activation reads the engine's own snapshot
{
    const engine = L.createEngine()
    const env = baseEnv({ filesResult: { text: "notes", paths: ["/home/test/notes.md"] } })
    const row = engine.run("/notes", "combi", env).rows[0]
    assert.equal(row.path, "/home/test/notes.md")
    assert.equal(Object.isFrozen(row), true)
    assert.equal(Object.isFrozen(row.actions), true)
    assert.equal(Object.isFrozen(row.actions[0]), true)
    assert.equal(Object.isFrozen(row.positions), true)
    try { row.path = "/etc/shadow" } catch (error) {}
    assert.equal(row.path, "/home/test/notes.md")
    assert.deepEqual(engine.activate(row, ""), { type: "path.open", path: "/home/test/notes.md" })
    const copy = Object.assign({}, row, { path: "/etc/shadow" })
    assert.deepEqual(engine.activate(copy, ""), { type: "path.open", path: "/home/test/notes.md" },
        "a copy's edited fields are ignored")
}

// App actions in a returned row do not alias the prepare cache
{
    const engine = L.createEngine()
    const env = baseEnv()
    const row = engine.run("ghost", "combi", env).rows[0]
    assert.equal(row.desktopId, "com.mitchellh.ghostty")
    try { row.actions.push({ id: "action:injected", label: "Injected" }) } catch (error) {}
    try { row.actions[0].id = "action:injected" } catch (error) {}
    assert.equal(engine.activate(row, "action:injected"), null)
    const later = engine.run("ghost", "combi", env).rows[0]
    assert.equal(later.actions.some(action => action.id === "action:injected"), false)
    assert.equal(engine.activate(later, "action:injected"), null)
    assert.equal(engine.activate(later, "action:new-window").actionId, "new-window")
}

// Capped results keep insertion order among exact ties
{
    const engine = L.createEngine()
    const apps = []
    for (let index = 0; index < 30; index++) apps.push(L.app("a" + index, "Editor"))
    for (const maxResults of [5, 20]) {
        const rows = engine.run("", "combi", { apps, settings: { maxResults }, now: L.NOW }).rows
        const expected = []
        for (let index = 0; index < maxResults; index++) expected.push("apps:a" + index)
        assert.deepEqual(rows.map(row => row.key), expected, `maxResults ${maxResults}`)
    }
}

console.log("engine: ok")
