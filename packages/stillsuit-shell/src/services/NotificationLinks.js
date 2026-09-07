var MEETING_HOSTS = /(^|\.)(zoom\.us|meet\.google\.com|teams\.microsoft\.com|teams\.live\.com|whereby\.com|meet\.jit\.si)$/i

function tidy(url) {
    return String(url || "").replace(/[.,;:!?)\]}'"]+$/, "")
}

function hostOf(url) {
    var match = String(url || "").match(/^https?:\/\/([^/?#]+)/i)
    if (!match || match[1].indexOf("@") !== -1) return ""
    return match[1].replace(/:\d+$/, "").toLowerCase()
}

function links(summary, body, sourceHostname) {
    var input = String(summary || "") + "\n" + String(body || "")
    var pattern = /(?:href=["'](https?:\/\/[^"']+)["']|\b(https?:\/\/[^\s<>"']+))/gi
    var result = []
    var seen = {}
    var match
    while ((match = pattern.exec(input)) !== null) {
        var url = tidy(match[1] || match[2])
        var host = hostOf(url)
        if (!host || host === String(sourceHostname || "").toLowerCase() || seen[url]) continue
        seen[url] = true
        result.push({ url: url, host: host, meeting: MEETING_HOSTS.test(host) })
    }
    result.sort(function(left, right) { return Number(right.meeting) - Number(left.meeting) })
    return result
}

function primary(summary, body, sourceHostname) {
    var found = links(summary, body, sourceHostname)
    if (!found.length) return null
    return {
        url: found[0].url,
        label: found[0].meeting ? "Join meeting" : "Open link",
        meeting: found[0].meeting
    }
}

if (typeof module !== "undefined") module.exports = {
    links: links,
    primary: primary,
    hostOf: hostOf
}
