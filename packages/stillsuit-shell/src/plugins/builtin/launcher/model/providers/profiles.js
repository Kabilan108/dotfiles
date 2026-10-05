// Snapshot: context.profiles as {active: id, available: [{id, name, description}]}.

var meta = { id: "profiles", label: "Profiles", icon: "shell:settings", snapshot: "profiles" }

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function prepare(profiles, matcher) {
    var result = []
    if (!profiles || typeof profiles !== "object") return result
    var active = safeString(profiles.active)
    var available = profiles.available && typeof profiles.available.length === "number"
        ? profiles.available : []
    var seen = Object.create(null)
    for (var index = 0; index < available.length; index++) {
        var profile = available[index]
        if (!profile) continue
        var id = safeString(profile.id)
        if (id === "" || seen[id] === true) continue
        seen[id] = true
        var name = safeString(profile.name) || id
        var description = safeString(profile.description)
        result.push({
            key: meta.id + ":" + id,
            profileId: id,
            name: name,
            description: description,
            current: id === active,
            order: index,
            fields: [matcher.prepare(name), matcher.prepare(id), matcher.prepare(description)]
        })
    }
    return result
}

function itemsOf(env) {
    return env.prepared && env.prepared.profiles ? env.prepared.profiles : prepare(env.profiles, env.matcher)
}

function query(text, env) {
    var items = itemsOf(env)
    var prepared = text === "" ? null
        : env.query && env.query.text === text ? env.query : env.matcher.prepareQuery(text)
    var rows = []
    for (var index = 0; index < items.length; index++) {
        var item = items[index]
        var score = items.length - index
        var positions = []
        if (prepared) {
            var match = env.matcher.score(prepared, item.fields)
            if (match.score <= 0) continue
            score = match.score * 1000 + items.length - index
            positions = match.field === 0 ? match.positions : []
        } else if (item.current) {
            score = items.length + 1
        }
        rows.push({
            key: item.key,
            provider: meta.id,
            text: item.name,
            subtext: item.current ? (item.description ? "Current · " + item.description : "Current")
                : item.description,
            icon: meta.icon,
            score: score,
            positions: positions,
            actions: [{ id: "activate", label: "Switch" }],
            current: item.current,
            profileId: item.profileId
        })
    }
    return rows
}

function activate(row, actionId) {
    if (!row || row.provider !== meta.id) return null
    var action = safeString(actionId)
    if (action !== "" && action !== "activate") return null
    var id = safeString(row.profileId)
    if (id === "") return null
    return { type: "profile.activate", id: id }
}

if (typeof module !== "undefined") {
    module.exports = {
        meta: meta,
        prepare: prepare,
        query: query,
        activate: activate
    }
}
