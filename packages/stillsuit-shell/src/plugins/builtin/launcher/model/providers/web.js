// URL detection. An "Open" row is offered only for http(s) URLs:
// - explicit: http:// or https:// followed by a host without "@" (no userinfo,
//   so "https://bank.com@evil.example" is rejected) and an optional
//   path/query/fragment, no whitespace;
// - bare domains: dot-separated DNS labels ending in a two-letter TLD or one
//   from COMMON_TLDS, optional :port and path. https:// is prepended. TLDs
//   that are also common file extensions ("notes.md", "main.go", "x.zip") are
//   not inferred; type the scheme to open those.
// Reverse-DNS app ids such as "org.gnome.Nautilus" end in a word that is not
// a known TLD, so they are not URLs.
// An explicit URL ranks near the top; an inferred one ranks below every other
// match, just above the trailing search row.

var meta = { id: "web", label: "Web", icon: "web-browser" }

var DEFAULT_ENGINE = "https://unduck.link?q=%TERM%"
var URL_SCORE = 800000
var INFERRED_URL_SCORE = 1
// Combi's fallback row is trailing: the engine appends it after every real
// match, and only when the result cap leaves a free slot.
var FALLBACK_SCORE = 0
var MAX_URL_LENGTH = 8192

var COMMON_TLDS = [
    "com", "net", "org", "edu", "gov", "mil", "int", "info", "biz", "app",
    "dev", "xyz", "site", "online", "tech", "store", "blog", "page", "link",
    "live", "news", "cloud", "wiki", "zone", "tools", "social", "email",
    "art", "design", "run", "build", "chat", "codes", "systems", "network"
]

var FILE_EXTENSIONS = [
    "ai", "as", "bz", "c", "cc", "conf", "cpp", "cs", "cxx", "db", "el", "ex", "fs", "gz", "go",
    "h", "hh", "hpp", "hs", "ini", "java", "jl", "jpg", "js", "json", "kt", "lock", "log", "lua",
    "md", "mk", "ml", "mov", "mp3", "mp4", "nim", "nix", "nu", "pdf", "pl", "png", "ps", "py",
    "rb", "rs", "rst", "sh", "so", "sql", "toml", "ts", "txt", "vb", "xz", "yaml", "yml", "zig", "zip"
]

var EXPLICIT_URL = /^https?:\/\/[^\s\/?#@]+(?:[\/?#]\S*)?$/i
var BARE_URL = /^((?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+([a-z]{2,63}))(?::\d{1,5})?(?:[\/?#]\S*)?$/i

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

// Returns {url, explicit} or null.
function parseUrl(value) {
    var text = safeString(value).trim()
    if (text === "" || text.length > MAX_URL_LENGTH) return null
    if (EXPLICIT_URL.test(text)) return { url: text, explicit: true }
    var bare = BARE_URL.exec(text)
    if (!bare) return null
    var tld = bare[2].toLowerCase()
    if (tld.length !== 2 && COMMON_TLDS.indexOf(tld) < 0) return null
    if (FILE_EXTENSIONS.indexOf(tld) >= 0) return null
    var url = "https://" + text
    return url.length > MAX_URL_LENGTH ? null : { url: url, explicit: false }
}

// Returns the URL to open, or "".
function detectUrl(value) {
    var parsed = parseUrl(value)
    return parsed ? parsed.url : ""
}

function engineTemplate(env) {
    var template = safeString(env.settings && env.settings.webEngine)
    if (!/^https?:\/\/\S+$/i.test(template) || template.indexOf("%TERM%") < 0) return DEFAULT_ENGINE
    return template
}

// Returns "" when the text cannot be encoded (lone surrogates); Query.parse
// already replaces those.
function searchUrl(template, text) {
    var term
    try {
        term = encodeURIComponent(text)
    } catch (error) {
        return ""
    }
    return template.split("%TERM%").join(term)
}

function engineHost(template) {
    var match = /^https?:\/\/([^\/?#]+)/i.exec(template)
    return match ? match[1] : ""
}

function query(text, env) {
    if (text === "") return []
    var rows = []
    var prefixed = env.prefix === "@"
    var parsed = parseUrl(text)
    if (parsed) {
        var url = parsed.url
        rows.push({
            key: meta.id + ":url",
            provider: meta.id,
            text: "Open " + url,
            subtext: "Open in browser",
            icon: meta.icon,
            score: prefixed ? 2 : parsed.explicit ? URL_SCORE : INFERRED_URL_SCORE,
            positions: [],
            actions: [{ id: "open", label: "Open" }, { id: "copy", label: "Copy URL" }],
            url: url
        })
    }
    var template = engineTemplate(env)
    var search = searchUrl(template, text)
    if (search !== "" && search.length <= MAX_URL_LENGTH) {
        rows.push({
            key: meta.id + ":search",
            provider: meta.id,
            text: "Search the web for " + text,
            subtext: engineHost(template),
            icon: meta.icon,
            score: prefixed ? 1 : FALLBACK_SCORE,
            positions: [],
            actions: [{ id: "open", label: "Search" }, { id: "copy", label: "Copy URL" }],
            url: search,
            trailing: !prefixed
        })
    }
    return rows
}

function activate(row, actionId) {
    if (!row || row.provider !== meta.id) return null
    var url = safeString(row.url)
    if (!/^https?:\/\//i.test(url) || url.length > MAX_URL_LENGTH) return null
    var action = safeString(actionId)
    if (action === "" || action === "open") return { type: "url.open", url: url }
    if (action === "copy") return { type: "text.copy", text: url }
    return null
}

if (typeof module !== "undefined") {
    module.exports = {
        meta: meta,
        detectUrl: detectUrl,
        searchUrl: searchUrl,
        query: query,
        activate: activate,
        DEFAULT_ENGINE: DEFAULT_ENGINE,
        URL_SCORE: URL_SCORE,
        INFERRED_URL_SCORE: INFERRED_URL_SCORE,
        FALLBACK_SCORE: FALLBACK_SCORE
    }
}
