// Fuzzy scoring is a port of fzf's FuzzyMatchV2 (src/algo/algo.go at v0.74.4,
// default scheme), used under the MIT License, Copyright (c) 2013-2026
// Junegunn Choi. Subtracting the match start and the min(index * 5, 50) field
// penalty follows Elephant (GPL-3.0, pkg/common/fzf.go and
// internal/providers/desktopapplications/query.go). Acronym matching follows
// Omarchy's shell/services/AppSearch.js at commit
// 821ae589059ffdadc970315f866c94b55d268af7, used under the MIT License,
// Copyright (c) David Heinemeier Hansson.

var SCORE_MATCH = 16
var SCORE_GAP_START = -3
var SCORE_GAP_EXTENSION = -1
var BONUS_BOUNDARY = 8
var BONUS_NON_WORD = 8
var BONUS_CAMEL_123 = 7
var BONUS_CONSECUTIVE = 4
var BONUS_FIRST_CHAR_MULTIPLIER = 2
var BONUS_BOUNDARY_WHITE = 10
var BONUS_BOUNDARY_DELIMITER = 9
var BONUS_CASE_MATCH = 2
var FIELD_PENALTY_STEP = 5
var FIELD_PENALTY_MAX = 50
var ACRONYM_MAX_LENGTH = 5
var MAX_PATTERN_LENGTH = 128
var MAX_FIELD_LENGTH = 4096
// Rows within this fraction of the best score count as equally good, so
// recency-ordered providers (windows, clipboard) can keep their own order.
var STRONG_MATCH_RATIO = 0.75
var NO_LIMIT = -1000000

var CLASS_WHITE = 0
var CLASS_NON_WORD = 1
var CLASS_DELIMITER = 2
var CLASS_LOWER = 3
var CLASS_UPPER = 4
var CLASS_LETTER = 5
var CLASS_NUMBER = 6

var WHITE_CHARS = " \t\n\v\f\r\x85\xA0"
var DELIMITER_CHARS = "/,:;|"

var NO_MATCH = Object.freeze({ score: 0, field: -1, positions: Object.freeze([]) })

// Two-character patterns take twoCharMatch; tests turn this off to compare it
// with the general DP.
var TWO_CHAR_PATH = true
var scratchC1 = []
var scratchMatrixSize = 0
var scratchH = null
var scratchC = null
var scratchF = zeroes(MAX_PATTERN_LENGTH)
var scratchPositions = zeroes(MAX_PATTERN_LENGTH)
var lastStart = 0
var lastAcronymOffset = 0

// Plain arrays, not typed arrays: element access on typed arrays is about ten
// times slower in QML's V4 engine.
function zeroes(length) {
    var result = []
    for (var index = 0; index < length; index++) result.push(0)
    return result
}

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function charClass(code) {
    if (code >= 97 && code <= 122) return CLASS_LOWER
    if (code >= 65 && code <= 90) return CLASS_UPPER
    if (code >= 48 && code <= 57) return CLASS_NUMBER
    var ch = String.fromCharCode(code)
    if (WHITE_CHARS.indexOf(ch) >= 0) return CLASS_WHITE
    if (DELIMITER_CHARS.indexOf(ch) >= 0) return CLASS_DELIMITER
    if (code < 128) return CLASS_NON_WORD
    if (ch.toLowerCase() !== ch) return CLASS_UPPER
    if (ch.toUpperCase() !== ch) return CLASS_LOWER
    if (/\s/.test(ch)) return CLASS_WHITE
    // General punctuation, arrows, math and box-drawing blocks are not words.
    if (code >= 0x2000 && code <= 0x2bff) return CLASS_NON_WORD
    return CLASS_LETTER
}

function bonusFor(prevClass, cls) {
    if (cls >= CLASS_NON_WORD) {
        if (prevClass === CLASS_WHITE) return BONUS_BOUNDARY_WHITE
        if (prevClass === CLASS_DELIMITER) return BONUS_BOUNDARY_DELIMITER
        if (prevClass === CLASS_NON_WORD) return BONUS_BOUNDARY
    }
    if (prevClass === CLASS_LOWER && cls === CLASS_UPPER
            || prevClass !== CLASS_NUMBER && cls === CLASS_NUMBER)
        return BONUS_CAMEL_123
    if (cls === CLASS_NON_WORD || cls === CLASS_DELIMITER) return BONUS_NON_WORD
    if (cls === CLASS_WHITE) return BONUS_BOUNDARY_WHITE
    return 0
}

function isHigh(code) {
    return code >= 0xD800 && code <= 0xDBFF
}

function isLow(code) {
    return code >= 0xDC00 && code <= 0xDFFF
}

// Lowercases one code point (one or two UTF-16 units) to a string of the same
// length, so folded indices stay original indices. Final sigma folds to σ.
// When lowercasing changes the length ("İ" -> "i̇"), the first code point is
// kept if it has the original width.
function foldCodePoint(unit) {
    if (unit === "\u03C2") return "\u03C3"
    var lowered = unit.toLowerCase()
    if (lowered.length === unit.length) return lowered
    var width = isHigh(lowered.charCodeAt(0)) && isLow(lowered.charCodeAt(1)) ? 2 : 1
    return width === unit.length ? lowered.slice(0, width) : unit
}

// Chunks between replaced code points hold only ASCII and code points that
// fold to themselves, so lowercasing a chunk keeps its length.
function foldString(text) {
    if (!/[^\x00-\x7F]/.test(text)) return text.toLowerCase()
    var result = ""
    var start = 0
    for (var index = 0; index < text.length; index++) {
        var code = text.charCodeAt(index)
        if (code < 128) continue
        var width = isHigh(code) && isLow(text.charCodeAt(index + 1)) ? 2 : 1
        var unit = text.substr(index, width)
        var folded = foldCodePoint(unit)
        if (folded !== unit) {
            result += text.slice(start, index).toLowerCase() + folded
            start = index + width
        }
        index += width - 1
    }
    return result + text.slice(start).toLowerCase()
}

// Class of the code point starting at `index`; a low surrogate takes its
// pair's class.
function classAt(text, index) {
    var code = text.charCodeAt(index)
    if (code < 0xD800 || code > 0xDFFF) return charClass(code)
    var start = isLow(code) && index > 0 && isHigh(text.charCodeAt(index - 1)) ? index - 1 : index
    var pair = text.substr(start, 2)
    if (pair.length !== 2 || !isHigh(pair.charCodeAt(0)) || !isLow(pair.charCodeAt(1))) return CLASS_LETTER
    if (pair.toLowerCase() !== pair) return CLASS_UPPER
    if (pair.toUpperCase() !== pair) return CLASS_LOWER
    return CLASS_LETTER
}

function maskBit(code) {
    if (code >= 97 && code <= 122) return 1 << (code - 97)
    if (code >= 48 && code <= 57) return 1 << 26
    if (code === 32 || code === 9) return 0
    return 1 << 27
}

function isWordClass(cls) {
    return cls >= CLASS_LOWER
}

function prepare(value) {
    if (value && value.codes && value.bonus) return value
    var text = safeString(value)
    if (text.length > MAX_FIELD_LENGTH) text = text.slice(0, MAX_FIELD_LENGTH)
    var length = text.length
    var lower = foldString(text)
    var codes = []
    var bonus = []
    var mask = 0
    var boundaryMask = 0
    var acronym = ""
    var acronymPositions = []
    var prevClass = CLASS_WHITE
    for (var index = 0; index < length; index++) {
        var code = text.charCodeAt(index)
        var cls = code < 128 ? charClass(code) : classAt(text, index)
        var lowered = lower.charCodeAt(index)
        var charBonus = isLow(code) && prevClass === cls ? 0 : bonusFor(prevClass, cls)
        codes.push(lowered)
        bonus.push(charBonus)
        mask |= maskBit(lowered)
        if (charBonus > 0) boundaryMask |= maskBit(lowered)
        if (isWordClass(cls) && charBonus >= BONUS_CAMEL_123
                && !(cls === CLASS_NUMBER && prevClass === CLASS_NUMBER)) {
            acronym += lower.charAt(index)
            acronymPositions.push(index)
        }
        prevClass = cls
    }
    return {
        text: text,
        lower: lower,
        codes: codes,
        bonus: bonus,
        mask: mask,
        boundaryMask: boundaryMask,
        acronym: acronym,
        acronymPositions: acronymPositions
    }
}

// The alignment DP covers the first MAX_PATTERN_LENGTH units (`length`); a
// match also requires the whole pattern (`fullLength`) to be a subsequence
// of the field. Patterns longer than a field can be never match, so they are
// cut just past MAX_FIELD_LENGTH.
function prepareQuery(value) {
    if (value && value.isQuery === true) return value
    var raw = safeString(value)
    if (raw.length > MAX_FIELD_LENGTH + 1) raw = raw.slice(0, MAX_FIELD_LENGTH + 1)
    var fullLength = raw.length
    var length = Math.min(fullLength, MAX_PATTERN_LENGTH)
    var lower = foldString(raw)
    var codes = []
    var rawCodes = []
    var mask = 0
    var hasUpper = false
    var hasWhite = false
    var chars = []
    for (var index = 0; index < fullLength; index++) {
        var code = raw.charCodeAt(index)
        var lowered = lower.charCodeAt(index)
        mask |= maskBit(lowered)
        chars.push(lower.charAt(index))
        if (index >= length) continue
        if (lowered !== code) hasUpper = true
        if (charClass(code) === CLASS_WHITE) hasWhite = true
        codes.push(lowered)
        rawCodes.push(code)
    }
    return {
        isQuery: true,
        text: raw,
        lower: lower,
        length: length,
        fullLength: fullLength,
        codes: codes,
        chars: chars,
        rawCodes: rawCodes,
        mask: mask,
        firstBit: fullLength > 0 ? maskBit(lower.charCodeAt(0)) : 0,
        hasUpper: hasUpper,
        rawCeiling: (SCORE_MATCH + BONUS_BOUNDARY_WHITE) * length
            + BONUS_BOUNDARY_WHITE * (BONUS_FIRST_CHAR_MULTIPLIER - 1),
        acronym: fullLength >= 2 && fullLength <= ACRONYM_MAX_LENGTH && !hasWhite
    }
}

function ensureMatrix(size) {
    if (size <= scratchMatrixSize) return
    var next = Math.max(256, scratchMatrixSize)
    while (next < size) next *= 2
    scratchMatrixSize = next
    scratchH = zeroes(next)
    scratchC = zeroes(next)
}

// Returns fzf's raw score, or -1. Fills scratchPositions in reverse order with
// `query.length` entries and sets lastStart. Also returns -1 when raw score
// minus start cannot exceed `mustExceed`: the match starts at or after the
// first occurrence of the first query character, and the raw score is at most
// `ceiling`. score() has already checked the character masks.
function fuzzyMatch(query, field, mustExceed, ceiling) {
    var pattern = query.codes
    var M = query.length
    var full = query.fullLength
    var T = field.codes
    var B = field.bonus
    var N = T.length
    if (M === 0 || full > N) return -1

    // Native indexOf finds the greedy first occurrences (fzf's F) and rejects
    // non-matches before any per-character loop; the DP then only spans
    // F[0]..lastIdx, like fzf's asciiFuzzyIndex trimming. Characters past the
    // DP's pattern only need to be a subsequence.
    var F = scratchF
    var lower = field.lower
    var chars = query.chars
    var found = -1
    for (var k = 0; k < full; k++) {
        found = lower.indexOf(chars[k], found + 1)
        if (found < 0) return -1
        if (k < M) F[k] = found
    }
    if (ceiling - F[0] <= mustExceed) return -1

    if (M === 1) {
        // Same choice as fzf's single-character path, visiting occurrences only.
        var bestPos = -1
        var best = 0
        for (var at = F[0]; at >= 0; at = lower.indexOf(chars[0], at + 1)) {
            var single = SCORE_MATCH + B[at] * BONUS_FIRST_CHAR_MULTIPLIER
            if (single > best) {
                best = single
                bestPos = at
                if (B[at] >= BONUS_BOUNDARY) break
            }
        }
        scratchPositions[0] = bestPos
        lastStart = bestPos
        return best
    }

    var lastIdx = lower.lastIndexOf(chars[M - 1])
    if (M === 2 && TWO_CHAR_PATH) return twoCharMatch(query, field, F[0], F[1], lastIdx)
    var f0 = F[0]
    var width = lastIdx - f0 + 1
    ensureMatrix(width * M)
    var H = scratchH
    var C = scratchC
    var pchar0 = pattern[0]
    var prevH0 = 0
    var inGap = false

    for (var off = f0; off <= lastIdx; off++) {
        var cell0 = off - f0
        if (T[off] === pchar0) {
            prevH0 = SCORE_MATCH + B[off] * BONUS_FIRST_CHAR_MULTIPLIER
            C[cell0] = 1
            inGap = false
        } else {
            var gapped = prevH0 + (inGap ? SCORE_GAP_EXTENSION : SCORE_GAP_START)
            prevH0 = gapped > 0 ? gapped : 0
            C[cell0] = 0
            inGap = true
        }
        H[cell0] = prevH0
    }

    var maxScore = 0
    var maxScorePos = 0
    for (var row = 1; row < M; row++) {
        var f = F[row]
        var rowChar = pattern[row]
        var base = row * width
        var rowInGap = false
        H[base + f - f0 - 1] = 0
        for (var col = f; col <= lastIdx; col++) {
            var cell = base + col - f0
            var s1 = 0
            var s2 = H[cell - 1] + (rowInGap ? SCORE_GAP_EXTENSION : SCORE_GAP_START)
            var consecutive = 0
            if (rowChar === T[col]) {
                var diag = cell - width - 1
                s1 = H[diag] + SCORE_MATCH
                var b = B[col]
                consecutive = C[diag] + 1
                if (consecutive > 1) {
                    var fb = B[col - consecutive + 1]
                    if (b >= BONUS_BOUNDARY && b > fb) {
                        consecutive = 1
                    } else {
                        if (b < BONUS_CONSECUTIVE) b = BONUS_CONSECUTIVE
                        if (b < fb) b = fb
                    }
                }
                if (s1 + b < s2) {
                    s1 += B[col]
                    consecutive = 0
                } else {
                    s1 += b
                }
            }
            C[cell] = consecutive
            rowInGap = s1 < s2
            var cellScore = s1 > s2 ? s1 : s2
            if (cellScore < 0) cellScore = 0
            if (row === M - 1 && cellScore > maxScore) {
                maxScore = cellScore
                maxScorePos = col
            }
            H[cell] = cellScore
        }
    }

    var i = M - 1
    var j = maxScorePos
    var preferMatch = true
    var count = 0
    for (;;) {
        var I = i * width
        var j0 = j - f0
        var s = H[I + j0]
        var up = 0
        var left = 0
        if (i > 0 && j >= F[i]) up = H[I - width + j0 - 1]
        if (j > F[i]) left = H[I + j0 - 1]
        var currentRow = i
        if (s > up && (s > left || s === left && preferMatch)) {
            scratchPositions[count++] = j
            if (i === 0) break
            i--
        }
        preferMatch = C[I + j0] > 1
            || currentRow + 1 < M && j < lastIdx && j + 1 >= F[currentRow + 1]
                && C[I + width + j0 + 1] > 0
        j--
    }
    lastStart = j
    return maxScore
}

// Row 0 of the DP at `column`: the first-character score of the nearest
// occurrence at or before it, minus a gap of -3 then -1 per column, floored
// at 0.
function firstRowScore(lower, bonus, char0, column) {
    var at = lower.lastIndexOf(char0, column)
    var first = SCORE_MATCH + bonus[at] * BONUS_FIRST_CHAR_MULTIPLIER
    if (at === column) return first
    var decayed = first - (column - at) - 2
    return decayed > 0 ? decayed : 0
}

// fuzzyMatch for two-character patterns: the same score, start and positions
// as the general DP, evaluated only at occurrences of the two characters.
// Between occurrences of the second character its row only decays, so its
// maximum and the cells the traceback reads sit on occurrences; row 0 is
// firstRowScore. Needs f0 < f1 <= lastIdx from fuzzyMatch.
function twoCharMatch(query, field, f0, f1, lastIdx) {
    var lower = field.lower
    var B = field.bonus
    var char0 = query.chars[0]
    var char1 = query.chars[1]
    var C1 = scratchC1
    var maxScore = 0
    var maxScorePos = 0
    var prevColumn = f1 - 1
    var prevScore = 0
    var prevGap = SCORE_GAP_START
    for (var col = f1; col >= 0 && col <= lastIdx; col = lower.indexOf(char1, col + 1)) {
        // Exact while positive; any value <= 0 has the same effect below.
        var s2 = prevScore + prevGap - (col - prevColumn - 1)
        var diagonal = firstRowScore(lower, B, char0, col - 1)
        var s1 = diagonal + SCORE_MATCH
        var b = B[col]
        var consecutive = 1
        if (lower.charAt(col - 1) === char0) {
            consecutive = 2
            var fb = B[col - 1]
            if (b >= BONUS_BOUNDARY && b > fb) {
                consecutive = 1
            } else {
                if (b < BONUS_CONSECUTIVE) b = BONUS_CONSECUTIVE
                if (b < fb) b = fb
            }
        }
        if (s1 + b < s2) {
            s1 += B[col]
            consecutive = 0
        } else {
            s1 += b
        }
        C1[col] = consecutive
        var cellScore = s1 > s2 ? s1 : s2
        if (cellScore > maxScore) {
            maxScore = cellScore
            maxScorePos = col
        }
        prevScore = cellScore > 0 ? cellScore : 0
        prevGap = s1 < s2 ? SCORE_GAP_EXTENSION : SCORE_GAP_START
        prevColumn = col
    }

    // The traceback records maxScorePos on row 1 at once; on row 0 only an
    // occurrence of the first character can be recorded.
    var column = maxScorePos - 1
    var start = f0
    for (;;) {
        var at = lower.lastIndexOf(char0, column)
        var here = SCORE_MATCH + B[at] * BONUS_FIRST_CHAR_MULTIPLIER
        var left = at > f0 ? firstRowScore(lower, B, char0, at - 1) : 0
        var preferMatch = at === maxScorePos - 1 ? C1[maxScorePos] > 1
            : at + 1 < lastIdx && at + 2 >= f1 && lower.charAt(at + 2) === char1 && C1[at + 2] > 0
        if (here > left || here === left && preferMatch) {
            start = at
            break
        }
        column = at - 1
    }
    scratchPositions[0] = maxScorePos
    scratchPositions[1] = start
    lastStart = start
    return maxScore
}

function caseBonus(query, field, positions, count, reversed) {
    if (!query.hasUpper) return 0
    var bonus = 0
    var text = field.text
    for (var index = 0; index < count; index++) {
        var position = positions[reversed ? count - 1 - index : index]
        if (text.charCodeAt(position) === query.rawCodes[index]) bonus += BONUS_CASE_MATCH
    }
    return bonus
}

function fieldPenalty(index) {
    return Math.min(index * FIELD_PENALTY_STEP, FIELD_PENALTY_MAX)
}

function acronymScore(query, field) {
    if (!query.acronym || field.acronym.length < query.length) return -1
    var offset = field.acronym.indexOf(query.lower)
    if (offset < 0) return -1
    var positions = field.acronymPositions
    var first = positions[offset]
    var total = field.bonus[first] * (BONUS_FIRST_CHAR_MULTIPLIER - 1)
    for (var index = 0; index < query.length; index++) {
        total += SCORE_MATCH + field.bonus[positions[offset + index]]
    }
    lastStart = first
    lastAcronymOffset = offset
    return total
}

// fields: strings or prepare() results; empty entries keep their index.
// opts.acronym (default true), opts.startPenalty (default true),
// opts.positions (default true), opts.minScore (default 0: scores below it
// are no match, which lets fields and alignments that cannot reach it be
// skipped).
function score(query, fields, opts) {
    var prepared = prepareQuery(query)
    if (prepared.length === 0 || !fields) return NO_MATCH
    var useAcronym = !opts || opts.acronym !== false
    var useStart = !opts || opts.startPenalty !== false
    var wantPositions = !opts || opts.positions !== false
    var minScore = opts && opts.minScore > 0 ? opts.minScore : 0

    var bestScore = 0
    var bestField = -1
    var bestStart = 0
    var bestAcronym = false
    var bestPositions = null

    // No alignment scores above a run of boundary matches starting the string.
    var caseCeiling = prepared.hasUpper ? BONUS_CASE_MATCH * prepared.length : 0
    var ceiling = prepared.rawCeiling + caseCeiling
    var nonBoundaryCeiling = prepared.rawCeiling - BONUS_BOUNDARY_WHITE * BONUS_FIRST_CHAR_MULTIPLIER
    var queryMask = prepared.mask
    var tryAcronym = useAcronym && prepared.acronym
    for (var index = 0; index < fields.length; index++) {
        var penalty = fieldPenalty(index)
        // Penalties only grow with the index, so no later field can win.
        if (bestScore > 0 && bestScore >= ceiling - penalty) break
        if (ceiling - penalty < minScore) break
        var raw = fields[index]
        if (raw === undefined || raw === null || raw === "") continue
        var field = raw.codes ? raw : prepare(raw)
        // Neither alignment nor acronym can use a character the field lacks.
        if ((field.mask & queryMask) !== queryMask) continue
        // Every non-zero bonus is at least BONUS_CAMEL_123, so when the first
        // character is never on a boundary its doubled bonus is lost and no
        // acronym can start. Whitespace has no mask bit, so a zero firstBit
        // proves nothing.
        var boundaryFirst = prepared.firstBit === 0 || (field.boundaryMask & prepared.firstBit) !== 0
        var fieldCeiling = boundaryFirst ? prepared.rawCeiling : nonBoundaryCeiling

        var mustExceed = NO_LIMIT
        if (useStart) {
            if (bestScore > 0) mustExceed = bestScore + penalty - caseCeiling
            if (minScore > 0 && minScore - 1 + penalty - caseCeiling > mustExceed)
                mustExceed = minScore - 1 + penalty - caseCeiling
            if (fieldCeiling <= mustExceed) continue
        }
        var fuzzy = fuzzyMatch(prepared, field, mustExceed, fieldCeiling)
        if (fuzzy >= 0) {
            var fuzzyStart = lastStart
            var value = fuzzy - (useStart ? fuzzyStart : 0) - penalty
                + caseBonus(prepared, field, scratchPositions, prepared.length, true)
            if (value < 1) value = 1
            if (value > bestScore) {
                bestScore = value
                bestField = index
                bestStart = fuzzyStart
                bestAcronym = false
                if (wantPositions) {
                    bestPositions = new Array(prepared.length)
                    for (var p = 0; p < prepared.length; p++)
                        bestPositions[p] = scratchPositions[prepared.length - 1 - p]
                }
            }
        }

        if (tryAcronym && boundaryFirst && (field.boundaryMask & queryMask) === queryMask) {
            var acronym = acronymScore(prepared, field)
            if (acronym >= 0) {
                var acronymPositions = field.acronymPositions.slice(lastAcronymOffset,
                    lastAcronymOffset + prepared.length)
                var acronymValue = acronym - (useStart ? lastStart : 0) - penalty
                    + caseBonus(prepared, field, acronymPositions, prepared.length, false)
                if (acronymValue < 1) acronymValue = 1
                if (acronymValue > bestScore) {
                    bestScore = acronymValue
                    bestField = index
                    bestStart = lastStart
                    bestAcronym = true
                    bestPositions = wantPositions ? acronymPositions : null
                }
            }
        }
    }

    if (bestField < 0 || bestScore < minScore) return NO_MATCH
    return {
        score: bestScore,
        field: bestField,
        start: bestStart,
        acronym: bestAcronym,
        positions: bestPositions || []
    }
}

function strongThreshold(bestScore) {
    return bestScore * STRONG_MATCH_RATIO
}

if (typeof module !== "undefined") {
    module.exports = {
        prepare: prepare,
        prepareQuery: prepareQuery,
        score: score,
        strongThreshold: strongThreshold,
        NO_MATCH: NO_MATCH,
        SCORE_MATCH: SCORE_MATCH,
        STRONG_MATCH_RATIO: STRONG_MATCH_RATIO,
        ACRONYM_MAX_LENGTH: ACRONYM_MAX_LENGTH
    }
}
