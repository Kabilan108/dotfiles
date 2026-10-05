const assert = require("node:assert/strict")
const { Query } = require("./load.js")

const cases = [
    ["", "combi", { prefix: "", providerIds: ["calc", "apps", "web"], text: "" }],
    ["  ghost  ", "combi", { prefix: "", providerIds: ["calc", "apps", "web"], text: "ghost" }],
    ["/", "combi", { prefix: "/", providerIds: ["files"], text: "" }],
    ["/  src/main.qml ", "combi", { prefix: "/", providerIds: ["files"], text: "src/main.qml" }],
    ["@", "combi", { prefix: "@", providerIds: ["web"], text: "" }],
    ["@  nix  flake ", "combi", { prefix: "@", providerIds: ["web"], text: "nix  flake" }],
    ["$", "combi", { prefix: "$", providerIds: ["windows"], text: "" }],
    ["$hel", "combi", { prefix: "$", providerIds: ["windows"], text: "hel" }],
    [":", "combi", { prefix: ":", providerIds: ["clipboard"], text: "" }],
    [":token", "power", { prefix: ":", providerIds: ["clipboard"], text: "token" }],
    ["foo/bar", "combi", { prefix: "", providerIds: ["calc", "apps", "web"], text: "foo/bar" }],
    ["a@b", "combi", { prefix: "", providerIds: ["calc", "apps", "web"], text: "a@b" }],
    ["x$", "combi", { prefix: "", providerIds: ["calc", "apps", "web"], text: "x$" }],
    [" /foo", "combi", { prefix: "", providerIds: ["calc", "apps", "web"], text: "/foo" }],
    ["//", "combi", { prefix: "/", providerIds: ["files"], text: "/" }],
    ["", "windows", { prefix: "", providerIds: ["windows"], text: "" }],
    ["sl", "power", { prefix: "", providerIds: ["power"], text: "sl" }],
    ["", "profiles", { prefix: "", providerIds: ["profiles"], text: "" }],
    ["", "clipboard", { prefix: "", providerIds: ["clipboard"], text: "" }],
    ["x", "bogus", { mode: "combi", prefix: "", providerIds: ["calc", "apps", "web"], text: "x" }],
    ["x", undefined, { mode: "combi" }],
    ["x", "__proto__", { mode: "combi" }],
    [null, "combi", { text: "", prefix: "" }],
    [42, "combi", { text: "42" }]
]

for (const [input, mode, expected] of cases) {
    const parsed = Query.parse(input, mode)
    for (const key of Object.keys(expected)) {
        assert.deepEqual(parsed[key], expected[key], `${JSON.stringify(input)} in ${mode}: ${key}`)
    }
}

const first = Query.parse("", "combi")
first.providerIds.push("mutated")
assert.deepEqual(Query.parse("", "combi").providerIds, ["calc", "apps", "web"], "the mode table is not shared")
assert.equal(Query.parse("x".repeat(5000), "combi").text.length, 1024)

// Input is cut on code point boundaries and lone surrogates become U+FFFD.
assert.equal(Query.parse("x".repeat(1023) + "\u{1F600}", "combi").text, "x".repeat(1023))
assert.equal(Query.parse("x".repeat(1022) + "\u{1F600}", "combi").text, "x".repeat(1022) + "\u{1F600}")
assert.equal(Query.parse("a\uD800b\uDC00c\uD83D", "combi").text, "a\uFFFDb\uFFFDc\uFFFD")
assert.equal(Query.parse("\uDE00\uD83D\uDE00", "combi").text, "\uFFFD\u{1F600}")
for (const input of ["@" + "x".repeat(1022) + "\u{1F600}", "\uD800".repeat(2000), "\uDFFF@"]) {
    assert.doesNotThrow(() => encodeURIComponent(Query.parse(input, "combi").text))
}

console.log("query: ok")
