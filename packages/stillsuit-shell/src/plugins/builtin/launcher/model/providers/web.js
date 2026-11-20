var meta = { id: "web", label: "Web", icon: "shell:search" }

var DEFAULT_ENGINE = "https://unduck.link?q=%TERM%"
var URL_SCORE = 800000
var INFERRED_URL_SCORE = 1
var BANG_SCORE = 2000000
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

function detectUrl(value) {
    var parsed = parseUrl(value)
    return parsed ? parsed.url : ""
}

function engineTemplate(env) {
    var template = safeString(env.settings && env.settings.webEngine)
    if (!/^https?:\/\/\S+$/i.test(template) || template.indexOf("%TERM%") < 0) return DEFAULT_ENGINE
    return template
}

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
    var bang = text.charAt(0) === "!"
    var parsed = parseUrl(text)
    if (parsed) {
        var url = parsed.url
        rows.push({
            key: meta.id + ":url",
            provider: meta.id,
            text: "Open " + url,
            subtext: "Open in browser",
            icon: meta.icon,
            score: parsed.explicit ? URL_SCORE : INFERRED_URL_SCORE,
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
            score: bang ? BANG_SCORE : FALLBACK_SCORE,
            positions: [],
            actions: [{ id: "open", label: "Search" }, { id: "copy", label: "Copy URL" }],
            url: search,
            trailing: !bang
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
        BANG_SCORE: BANG_SCORE,
        FALLBACK_SCORE: FALLBACK_SCORE
    }
}
