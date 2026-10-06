// Usage boost reimplements the formula of Elephant's CalcUsageScore
// (abenz1267/elephant pkg/common/history/history.go, GPL-3.0) as restated in
// docs/plans/stillsuit-launcher-spec.md. Differences: related stored queries
// contribute their best per-record boost instead of a summed count, and the
// length difference divides as (1 + delta), so results don't depend on map
// iteration order.

var VERSION = 1
var MAX_RECORDS = 2000
var MAX_COUNT = 10
var MAX_QUERY_LENGTH = 256
var MAX_KEY_LENGTH = 512
var DAY_MS = 24 * 60 * 60 * 1000
var BASE_DAYS = 10
var MAX_EMPTY_COUNT = 50
// Boost tables are rebuilt when this much time has passed, so a cached table
// never drifts by more than a fraction of a day.
var TABLE_MAX_AGE_MS = 60 * 1000
// Records stamped further ahead than this are dropped on load; nearer future
// stamps (clock skew) rank as now.
var MAX_FUTURE_MS = DAY_MS
// The empty-query recency tie-breaker stays below this, and ranks are
// integers, so recency only orders equal ranks.
var TIE_BREAK_MAX = 0.5

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function normalizeQuery(query) {
    return safeString(query).trim().toLowerCase().slice(0, MAX_QUERY_LENGTH)
}

function finiteNow(now) {
    var value = Number(now)
    return isFinite(value) ? value : Date.now()
}

function effectiveTime(lastUsed, now) {
    return lastUsed > now ? now : lastUsed
}

function daysSince(lastUsed, now) {
    var days = Math.floor((now - lastUsed) / DAY_MS)
    return days > 0 ? days : 0
}

function recordBoost(count, lastUsed, now) {
    return Math.max((BASE_DAYS - daysSince(lastUsed, now)) * count, 1)
}

function validRecord(entry, now) {
    if (!entry || typeof entry !== "object") return null
    if (typeof entry.query !== "string" || typeof entry.key !== "string") return null
    if (entry.key === "" || entry.key.length > MAX_KEY_LENGTH) return null
    if (entry.query.length > MAX_QUERY_LENGTH) return null
    var count = Number(entry.count)
    var lastUsed = Number(entry.lastUsed)
    if (!isFinite(count) || !isFinite(lastUsed) || count < 1 || lastUsed <= 0) return null
    if (lastUsed > now + MAX_FUTURE_MS) return null
    return {
        query: normalizeQuery(entry.query),
        key: entry.key,
        count: Math.min(Math.floor(count), MAX_COUNT),
        lastUsed: lastUsed
    }
}

function parseData(data, now) {
    var document = data
    if (typeof data === "string") {
        try {
            document = JSON.parse(data)
        } catch (error) {
            return []
        }
    }
    if (!document || typeof document !== "object" || document.version !== VERSION
            || !Array.isArray(document.records))
        return []
    var result = []
    for (var index = 0; index < document.records.length; index++) {
        var record = validRecord(document.records[index], now)
        if (record) result.push(record)
    }
    return result
}

function isHistory(value) {
    return !!value && typeof value.boost === "function"
        && typeof value.emptyQueryRank === "function"
}

// `now` (ms, default Date.now()) bounds the timestamps accepted from `data`.
function create(data, now) {
    if (isHistory(data)) return data

    var byQuery = new Map()
    var size = 0
    var boostTable = null
    var boostRawQuery = null
    var boostBuiltAt = 0
    var boostRevision = -1
    var emptyTable = null
    var emptyBuiltAt = 0
    var emptyRevision = -1

    var history = {
        revision: 0
    }

    function put(record) {
        var keys = byQuery.get(record.query)
        if (!keys) {
            keys = new Map()
            byQuery.set(record.query, keys)
        }
        var existing = keys.get(record.key)
        if (existing) {
            existing.count = Math.min(existing.count + record.count, MAX_COUNT)
            existing.lastUsed = Math.max(existing.lastUsed, record.lastUsed)
            return
        }
        keys.set(record.key, { count: record.count, lastUsed: record.lastUsed })
        size++
    }

    function evictOldest() {
        while (size > MAX_RECORDS) {
            var oldestQuery = null
            var oldestKey = null
            var oldestTime = Infinity
            byQuery.forEach(function(keys, query) {
                keys.forEach(function(entry, key) {
                    if (entry.lastUsed < oldestTime) {
                        oldestTime = entry.lastUsed
                        oldestQuery = query
                        oldestKey = key
                    }
                })
            })
            if (oldestQuery === null) return
            var keys = byQuery.get(oldestQuery)
            keys.delete(oldestKey)
            if (keys.size === 0) byQuery.delete(oldestQuery)
            size--
        }
    }

    function changed() {
        history.revision++
    }

    function buildBoostTable(query, now) {
        var table = new Map()
        byQuery.forEach(function(keys, stored) {
            if (stored.indexOf(query) !== 0 && query.indexOf(stored) !== 0) return
            var divisor = 1 + Math.abs(stored.length - query.length)
            keys.forEach(function(entry, key) {
                var value = recordBoost(entry.count, entry.lastUsed, now) / divisor
                var current = table.get(key)
                if (current === undefined || value > current) table.set(key, value)
            })
        })
        return table
    }

    function buildEmptyTable(now) {
        var totals = new Map()
        byQuery.forEach(function(keys) {
            keys.forEach(function(entry, key) {
                var total = totals.get(key)
                if (!total) {
                    totals.set(key, { count: entry.count, lastUsed: entry.lastUsed })
                } else {
                    total.count += entry.count
                    if (entry.lastUsed > total.lastUsed) total.lastUsed = entry.lastUsed
                }
            })
        })
        var table = new Map()
        totals.forEach(function(total, key) {
            var count = Math.min(total.count, MAX_EMPTY_COUNT)
            var recency = now > 0 ? Math.max(effectiveTime(total.lastUsed, now), 0) / now : 0
            table.set(key, recordBoost(count, total.lastUsed, now) + TIE_BREAK_MAX * recency)
        })
        return table
    }

    history.record = function(query, key, now) {
        var itemKey = safeString(key)
        if (itemKey === "" || itemKey.length > MAX_KEY_LENGTH) return false
        var normalized = normalizeQuery(query)
        var time = finiteNow(now)
        var keys = byQuery.get(normalized)
        var existing = keys ? keys.get(itemKey) : undefined
        if (existing) {
            existing.count = Math.min(existing.count + 1, MAX_COUNT)
            existing.lastUsed = time
        } else {
            put({ query: normalized, key: itemKey, count: 1, lastUsed: time })
            evictOldest()
        }
        changed()
        return true
    }

    // Called once per matching candidate on every keystroke, so the raw query
    // is compared before normalising it again.
    history.boost = function(query, key, now) {
        var time = typeof now === "number" && isFinite(now) ? now : finiteNow(now)
        if (!boostTable || query !== boostRawQuery || boostRevision !== history.revision
                || Math.abs(time - boostBuiltAt) > TABLE_MAX_AGE_MS) {
            var normalized = normalizeQuery(query)
            boostTable = normalized === "" ? new Map() : buildBoostTable(normalized, time)
            boostRawQuery = query
            boostRevision = history.revision
            boostBuiltAt = time
        }
        if (boostTable.size === 0) return 0
        var value = boostTable.get(typeof key === "string" ? key : safeString(key))
        return value === undefined ? 0 : value
    }

    history.emptyQueryRank = function(key, now) {
        var time = finiteNow(now)
        if (!emptyTable || emptyRevision !== history.revision
                || Math.abs(time - emptyBuiltAt) > TABLE_MAX_AGE_MS) {
            emptyTable = buildEmptyTable(time)
            emptyRevision = history.revision
            emptyBuiltAt = time
        }
        var value = emptyTable.get(safeString(key))
        return value === undefined ? 0 : value
    }

    history.remove = function(key) {
        var itemKey = safeString(key)
        var removed = false
        byQuery.forEach(function(keys, query) {
            if (keys.delete(itemKey)) {
                removed = true
                size--
                if (keys.size === 0) byQuery.delete(query)
            }
        })
        if (removed) changed()
        return removed
    }

    history.clear = function() {
        if (size === 0) return
        byQuery = new Map()
        size = 0
        changed()
    }

    history.size = function() {
        return size
    }

    history.toJSON = function() {
        var records = []
        byQuery.forEach(function(keys, query) {
            keys.forEach(function(entry, key) {
                records.push({ query: query, key: key, count: entry.count, lastUsed: entry.lastUsed })
            })
        })
        records.sort(function(a, b) {
            if (a.lastUsed !== b.lastUsed) return b.lastUsed - a.lastUsed
            if (a.query !== b.query) return a.query < b.query ? -1 : 1
            return a.key < b.key ? -1 : a.key > b.key ? 1 : 0
        })
        return { version: VERSION, records: records }
    }

    var loaded = parseData(data, finiteNow(now))
    loaded.sort(function(a, b) { return b.lastUsed - a.lastUsed })
    for (var index = 0; index < loaded.length && size < MAX_RECORDS; index++) put(loaded[index])
    return history
}

if (typeof module !== "undefined") {
    module.exports = {
        create: create,
        isHistory: isHistory,
        normalizeQuery: normalizeQuery,
        VERSION: VERSION,
        MAX_RECORDS: MAX_RECORDS,
        MAX_COUNT: MAX_COUNT,
        DAY_MS: DAY_MS
    }
}
