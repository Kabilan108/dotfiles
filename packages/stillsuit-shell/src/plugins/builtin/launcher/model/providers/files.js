// Snapshot: env.filesResult {text, paths} from the service's async fd run.
// Rows come only from a result whose text equals the current query, so a slow
// reply for an older query never shows.

var meta = { id: "files", label: "Files", icon: "system-file-manager" }

var MAX_PATHS = 1000
var MAX_PATH_LENGTH = 4096

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function rootOf(env) {
    var root = safeString(env.settings && env.settings.searchRoot)
    while (root.length > 1 && root.charAt(root.length - 1) === "/") root = root.slice(0, -1)
    return root.charAt(0) === "/" ? root : ""
}

function absolutePath(path, root) {
    if (path.charAt(0) === "/") return path
    if (root === "") return ""
    var relative = path.indexOf("./") === 0 ? path.slice(2) : path
    return root === "/" ? "/" + relative : root + "/" + relative
}

function displayPath(path, root) {
    if (root === "" || root === "/") return path
    if (path === root) return "."
    return path.indexOf(root + "/") === 0 ? path.slice(root.length + 1) : path
}

function baseName(path) {
    var trimmed = path.charAt(path.length - 1) === "/" ? path.slice(0, -1) : path
    return trimmed.slice(trimmed.lastIndexOf("/") + 1)
}

function pending(text, env) {
    if (text === "") return ""
    var result = env.filesResult
    return result && result.text === text ? "" : text
}

function query(text, env) {
    var result = env.filesResult
    if (text === "" || !result || result.text !== text) return []
    var paths = result.paths && typeof result.paths.length === "number" ? result.paths : []
    var root = rootOf(env)
    var prepared = env.query && env.query.text === text ? env.query : env.matcher.prepareQuery(text)
    var rows = []
    var seen = Object.create(null)
    var count = Math.min(paths.length, MAX_PATHS)
    for (var index = 0; index < count; index++) {
        var raw = safeString(paths[index])
        if (raw === "" || raw.length > MAX_PATH_LENGTH || raw.indexOf("\u0000") >= 0) continue
        var path = absolutePath(raw, root)
        if (path === "" || seen[path] === true) continue
        seen[path] = true
        var shown = displayPath(path, root)
        var name = baseName(shown)
        var match = env.matcher.score(prepared, [name, shown])
        var positions = match.positions
        if (match.field === 0) {
            var offset = shown.length - name.length - (shown.charAt(shown.length - 1) === "/" ? 1 : 0)
            positions = []
            for (var p = 0; p < match.positions.length; p++) positions.push(match.positions[p] + offset)
        }
        var directory = path.charAt(path.length - 1) === "/"
        rows.push({
            key: meta.id + ":" + path,
            provider: meta.id,
            text: shown,
            subtext: "",
            icon: directory ? "folder" : "text-x-generic",
            // fd already matched the path; keep its rows even when the fuzzy
            // matcher disagrees (fd patterns are regular expressions).
            score: match.score > 0 ? match.score : 1,
            positions: match.score > 0 ? positions : [],
            actions: [
                { id: "open", label: "Open" },
                { id: "reveal", label: "Show in folder" },
                { id: "copy", label: "Copy path" }
            ],
            path: path,
            relativePath: shown
        })
    }
    return rows
}

function activate(row, actionId) {
    if (!row || row.provider !== meta.id) return null
    var path = safeString(row.path)
    if (path.charAt(0) !== "/" || path.indexOf("\u0000") >= 0) return null
    var action = safeString(actionId)
    if (action === "" || action === "open") return { type: "path.open", path: path }
    if (action === "reveal") return { type: "path.reveal", path: path }
    if (action === "copy") return { type: "text.copy", text: path }
    return null
}

if (typeof module !== "undefined") {
    module.exports = {
        meta: meta,
        pending: pending,
        query: query,
        activate: activate
    }
}
