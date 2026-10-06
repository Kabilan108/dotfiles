// Snapshot: env.filesResult {text, paths} from the service's async fd run.
// Rows come only from a result whose text equals the current query, so a slow
// reply for an older query never shows.
//
// Query forms (fdQuery turns them into an fd regular expression):
// - words: the file name contains each word, in order ("nix flake").
// - a glob without "/": the whole file name matches ("*.pdf", "report-??.txt").
// - anything with "/": matched against the path below the search root, so
//   "downloads/ pdf" and "downloads/*.pdf" find PDFs in a Downloads folder.
//   A leading "/" starts a folder name ("/dl" skips "nodl"). With a glob the
//   pattern must reach the end of the path; without one it may stop anywhere.
// Spaces stand for "anything", "*" for anything within one folder or name,
// "**" for anything across folders, "?" for one character. Every other
// character is literal. Matching ignores case unless the text has a capital.

var meta = { id: "files", label: "Files", icon: "shell:folder" }

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

function escapeRegex(text) {
    return text.replace(/[\\.+*?()|\[\]{}^$#&\-~]/g, "\\$&")
}

function isGlob(text) {
    return /[*?]/.test(text)
}

// fd refuses a name pattern containing "/", so name globs use "." for "any
// character"; a name holds no "/" anyway.
function translate(text, path) {
    var any = path ? "[^/]" : "."
    var out = ""
    for (var index = 0; index < text.length; index++) {
        var ch = text.charAt(index)
        if (/\s/.test(ch)) {
            while (index + 1 < text.length && /\s/.test(text.charAt(index + 1))) index++
            out += ".*"
        } else if (ch === "*" && text.charAt(index + 1) === "*") {
            index++
            if (text.charAt(index + 1) === "/") {
                index++
                out += "(?:.*/)?"
            } else {
                out += ".*"
            }
        } else if (ch === "*") {
            out += any + "*"
        } else if (ch === "?") {
            out += any
        } else {
            out += escapeRegex(ch)
        }
    }
    return out
}

// Returns {pattern, fullPath, caseSensitive} for fd, or null when there is
// nothing to search for. root is the absolute search root fd walks.
function fdQuery(text, root) {
    var value = safeString(text).trim()
    if (value === "") return null
    var caseSensitive = value !== value.toLowerCase()
    var glob = isGlob(value)
    var path = value.indexOf("/") >= 0
    var body = translate(value, path)
    if (!path) {
        return { pattern: glob ? "^" + body + "$" : body, fullPath: false, caseSensitive: caseSensitive }
    }
    var base = safeString(root)
    while (base.length > 1 && base.charAt(base.length - 1) === "/") base = base.slice(0, -1)
    var rootPart = base === "/" ? "" : escapeRegex(base)
    var lead = value.charAt(0) === "/" ? "(?:/.*)?" : "/.*"
    return {
        pattern: "^" + rootPart + lead + body + (glob ? "$" : ""),
        fullPath: true,
        caseSensitive: caseSensitive
    }
}

// Glob and path queries rank by their literal characters; plain words rank
// as typed.
function scoreText(text) {
    if (!isGlob(text) && text.indexOf("/") < 0) return text
    return text.replace(/[*?\s]+/g, "")
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
    var ranked = scoreText(text)
    var prepared = env.query && env.query.text === ranked ? env.query : env.matcher.prepareQuery(ranked)
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
            icon: directory ? "shell:folder" : "shell:file",
            // fd already matched the path; keep its rows even when the fuzzy
            // matcher disagrees (globs and spaces are not fuzzy patterns).
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
        fdQuery: fdQuery,
        pending: pending,
        query: query,
        activate: activate
    }
}
