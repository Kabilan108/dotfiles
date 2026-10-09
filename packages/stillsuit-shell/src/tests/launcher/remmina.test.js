const assert = require("node:assert/strict")
const { createEngine, Query } = require("./load.js")
const engine = createEngine()
const env = { connections: [
    { name: "Alpha", group: "Lab", protocol: "SSH", server: "one.example", path: "/tmp/a.remmina" },
    { name: "Beta", group: "Office", protocol: "RDP", server: "two.example", path: "/tmp/b.remmina" }
], settings: { maxResults: 1 } }
assert.deepEqual(Query.parse(">lab", "combi").providerIds, ["remmina"])
let result = engine.run("", "remmina", env)
assert.equal(result.rows.length, 2, "all entries remain available beyond normal result limit")
assert.equal(result.rows[0].text, "Alpha")
assert.equal(result.rows[0].subtext, "Lab · SSH · one.example")
assert.deepEqual(engine.activate(result.rows[0], "connect"), { type: "remmina.connect", path: "/tmp/a.remmina" })
const old = result.rows[0]
for (const query of ["lab", "ssh", "one.example"]) {
    result = engine.run(query, "remmina", env)
    assert.equal(result.rows.length, 1)
    assert.equal(result.rows[0].text, "Alpha")
}
assert.equal(engine.activate(old), null, "stale selection cannot launch")
console.log("remmina: ok")
