// Calc gating. The input is sent to qalc only when one of these holds:
// 1. A unit conversion: number, unit (one or two words), to|in|as|into|->,
//    unit. "5 km to mi", "100 usd in eur".
// 2. "N% of M".
// 3. An expression made only of numbers, operators (+ - * / ^ × ÷ mod),
//    postfix % and !, parentheses, known functions (sqrt, sin, log, ...) and
//    constants (pi, e, tau, phi), with at least one operator, function,
//    parenthesis or implicit product (a number directly before a constant,
//    "2pi"), and ending in an operand. "sin(pi)", "pi+e" and "e^2" qualify.
// Any other word ("7zip", "x264", "2fa"), a bare number ("2048") or a bare
// constant ("pi", "e") is not math. ISO dates (2026-10-05) are excluded.

var meta = { id: "calc", label: "Calculator", icon: "shell:calculator" }

var CALC_SCORE = 1000000
var MAX_LENGTH = 256

var FUNCTIONS = [
    "sqrt", "cbrt", "root", "sin", "cos", "tan", "asin", "acos", "atan",
    "sinh", "cosh", "tanh", "ln", "log", "log2", "log10", "exp", "abs",
    "round", "floor", "ceil", "fact", "factorial"
]
var CONSTANTS = ["pi", "π", "e", "tau", "τ", "phi"]
var BINARY_OPERATORS = "+-*/^×÷·−"
var POSTFIX_OPERATORS = "%!"

var NUMBER = /^(\d+(?:[.,]\d+)*|\.\d+)(?:e[-+]?\d+)?/i
var WORD = /^[a-zπτ]+\d*/i
var ISO_DATE = /^\d{4}-\d{2}-\d{2}$/
var UNIT = "[^\\d\\s()+*/^=]{1,16}"
var CONVERSION = new RegExp("^[-+]?(?:\\d+(?:[.,]\\d+)*|\\.\\d+)(?:e[-+]?\\d+)?\\s*"
    + UNIT + "(?:\\s+" + UNIT + ")?\\s+(?:to|in|as|into|->|→)\\s+"
    + UNIT + "(?:\\s+" + UNIT + ")?$", "i")
var PERCENT_OF = /^\d+(?:[.,]\d+)?\s*%\s+of\s+\d+(?:[.,]\d+)?$/i

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function isExpression(text) {
    var rest = text
    var operand = false
    var numberOperand = false
    var hasOperator = false
    var depth = 0
    while (rest.length > 0) {
        var ch = rest.charAt(0)
        if (/\s/.test(ch)) {
            rest = rest.slice(1)
            continue
        }
        var number = NUMBER.exec(rest)
        if (number) {
            if (operand) return false
            operand = true
            numberOperand = true
            rest = rest.slice(number[0].length)
            continue
        }
        var word = WORD.exec(rest)
        if (word) {
            var name = word[0].toLowerCase()
            if (FUNCTIONS.indexOf(name) >= 0) {
                if (operand) return false
                hasOperator = true
                operand = false
            } else if (CONSTANTS.indexOf(name) >= 0) {
                if (operand && !numberOperand) return false
                if (operand) hasOperator = true
                operand = true
            } else if (name === "mod" && operand) {
                hasOperator = true
                operand = false
            } else {
                return false
            }
            numberOperand = false
            rest = rest.slice(word[0].length)
            continue
        }
        if (ch === "(") {
            depth++
            hasOperator = true
            operand = false
        } else if (ch === ")") {
            depth--
            if (depth < 0 || !operand) return false
            operand = true
        } else if (BINARY_OPERATORS.indexOf(ch) >= 0) {
            if (operand) {
                hasOperator = true
                operand = false
            } else if (ch !== "+" && ch !== "-" && ch !== "−") {
                return false
            }
        } else if (POSTFIX_OPERATORS.indexOf(ch) >= 0) {
            if (!operand) return false
            hasOperator = true
        } else {
            return false
        }
        numberOperand = false
        rest = rest.slice(1)
    }
    return hasOperator && operand
}

function looksLikeMath(value) {
    var text = safeString(value).trim()
    if (text === "" || text.length > MAX_LENGTH) return false
    if (ISO_DATE.test(text)) return false
    if (CONVERSION.test(text) || PERCENT_OF.test(text)) return true
    return isExpression(text)
}

function currentResult(text, env) {
    var result = env.calcResult
    if (!result || result.text !== text || result.error) return null
    var value = safeString(result.value).trim()
    return value === "" ? null : value
}

function pending(text, env) {
    if (!looksLikeMath(text)) return ""
    var result = env.calcResult
    return result && result.text === text ? "" : text
}

function query(text, env) {
    if (!looksLikeMath(text)) return []
    var value = currentResult(text, env)
    if (value === null) return []
    return [{
        key: meta.id + ":result",
        provider: meta.id,
        text: value,
        subtext: text,
        icon: meta.icon,
        score: CALC_SCORE,
        positions: [],
        actions: [{ id: "copy", label: "Copy result" }],
        value: value
    }]
}

function activate(row, actionId) {
    if (!row || row.provider !== meta.id) return null
    var action = safeString(actionId)
    if (action !== "" && action !== "copy") return null
    return { type: "text.copy", text: safeString(row.value) }
}

if (typeof module !== "undefined") {
    module.exports = {
        meta: meta,
        looksLikeMath: looksLikeMath,
        pending: pending,
        query: query,
        activate: activate,
        CALC_SCORE: CALC_SCORE
    }
}
