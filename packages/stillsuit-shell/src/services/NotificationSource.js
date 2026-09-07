var HOSTNAME = /^(?=.{1,253}$)[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$/

function text(value) {
    return value === undefined || value === null ? "" : String(value)
}

function slug(value) {
    return text(value).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
}

function hostname(value) {
    var candidate = text(value).trim().toLowerCase().replace(/^www\./, "").replace(/\.+$/, "")
    if (!HOSTNAME.test(candidate)) return ""
    if (/^\d+$/.test(candidate.split(".").pop())) return ""
    return candidate
}

function hostOf(url) {
    var match = text(url).match(/^https?:\/\/([^/?#]+)/i)
    if (!match) return ""
    var authority = match[1]
    var at = authority.lastIndexOf("@")
    if (at >= 0) authority = authority.slice(at + 1)
    return hostname(authority.replace(/:\d+$/, ""))
}

// Chromium prefixes native notification bodies with an origin anchor. It is
// sender identity, not message content, so lift only this narrow leading form.
function liftBrowserOrigin(body) {
    var raw = text(body)
    var match = raw.match(/^\s*<a\s+href=["']([^"']+)["'][^>]*>([^<]+)<\/a>\s*/i)
    if (!match) return { hostname: "", body: raw }
    var label = hostname(match[2])
    var host = hostOf(match[1])
    if (!host || (label && label !== host)) return { hostname: "", body: raw }
    return { hostname: host, body: raw.slice(match[0].length) }
}

function identify(snapshot) {
    var row = snapshot || {}
    var lifted = liftBrowserOrigin(row.body)
    var hints = row.hints || {}
    var desktopEntry = text(hints["desktop-entry"] || hints.desktopEntry).replace(/\.desktop$/i, "")
    var appName = text(row.appName).trim()
    var appIcon = text(row.appIcon).trim()
    var label = lifted.hostname || desktopEntry || appName || appIcon || "Unknown"
    var kind = lifted.hostname ? "web" : "app"
    var identity = lifted.hostname || desktopEntry || appName || appIcon || "unknown"
    return {
        key: kind + ":" + (kind === "web" ? identity : (slug(identity) || "unknown")),
        label: label,
        kind: kind,
        hostname: lifted.hostname,
        body: lifted.body
    }
}

if (typeof module !== "undefined") module.exports = {
    hostname: hostname,
    hostOf: hostOf,
    liftBrowserOrigin: liftBrowserOrigin,
    identify: identify,
    slug: slug
}
