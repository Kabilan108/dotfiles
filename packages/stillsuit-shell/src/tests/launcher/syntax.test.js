// QML's V4 engine loads these files as plain scripts. Reject syntax it lacks
// and any module plumbing other than the guarded module.exports.
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")
const { modelDir } = require("./load.js")

function modelFiles(dir) {
    const result = []
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name)
        if (entry.isDirectory()) result.push(...modelFiles(full))
        else if (entry.name.endsWith(".js")) result.push(full)
    }
    return result
}

function stripStringsAndComments(source) {
    return source
        .replace(/\/\*[\s\S]*?\*\//g, "")
        .replace(/\/\/[^\n]*/g, "")
        .replace(/"(?:[^"\\\n]|\\.)*"/g, "\"\"")
        .replace(/'(?:[^'\\\n]|\\.)*'/g, "''")
        .replace(/`(?:[^`\\]|\\.)*`/g, "``")
}

const files = modelFiles(modelDir)
assert.equal(files.length, 13, "Matcher, History, Query, Engine and nine providers")

const banned = [
    [/\?\./, "optional chaining"],
    [/\?\?/, "nullish coalescing"],
    [/^\s*import\s/m, "import statement"],
    [/^\s*export\s/m, "export statement"],
    [/\brequire\s*\(/, "require()"],
    [/\.pragma\b/, ".pragma"],
    [/\.import\b/, ".import"],
    [/\bclass\s+\w+/, "class declaration"],
    [/\.\.\.\w/, "spread or rest"],
    [/\basync\s+function\b|\bawait\s/, "async/await"]
]

for (const file of files) {
    const source = fs.readFileSync(file, "utf8")
    const code = stripStringsAndComments(source)
    for (const [pattern, label] of banned) {
        assert.equal(pattern.test(code), false, `${path.relative(modelDir, file)} uses ${label}`)
    }
    assert.match(source, /if \(typeof module !== "undefined"\) \{\n    module\.exports = \{/,
        `${path.relative(modelDir, file)} ends with the guarded module.exports`)
    // Runs as a classic script with no module or require in scope, as QML does.
    const context = vm.createContext({ console })
    vm.runInContext(source, context, { filename: file })
}

console.log(`syntax: ok (${files.length} files)`)
