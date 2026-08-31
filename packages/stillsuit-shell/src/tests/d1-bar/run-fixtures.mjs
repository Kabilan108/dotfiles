import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const fixtureDir = dirname(fileURLToPath(import.meta.url));
const fixture = JSON.parse(readFileSync(join(fixtureDir, "fixtures.json"), "utf8"));
const barSource = readFileSync(join(fixtureDir, "../../plugins/builtin/bar/Bar.qml"), "utf8");
const slotSource = readFileSync(join(fixtureDir, "../../plugins/builtin/bar/WidgetSlot.qml"), "utf8");
const manifest = JSON.parse(readFileSync(join(fixtureDir, "../../plugins/builtin/bar/manifest.json"), "utf8"));

function recordsFor(section) {
  const seenSingle = new Set();
  return fixture.registrations
    .map((record, sequence) => ({ ...record, sequence }))
    .filter((record) => {
      if (record.section !== section) return false;
      if (!record.allowMultiple && seenSingle.has(record.id)) return false;
      if (!record.allowMultiple) seenSingle.add(record.id);
      return true;
    })
    .sort((left, right) => left.id.localeCompare(right.id) || left.sequence - right.sequence);
}

function surfacePlan(shadowMode) {
  return fixture.outputs.map((outputId) => ({
    outputId,
    exclusionZone: shadowMode ? 0 : 40,
    owner: "stillsuit.bar",
  }));
}

assert.deepEqual(manifest, {
  schemaVersion: 1,
  id: "stillsuit.bar",
  name: "Stillsuit bar",
  description: "Per-output Stillsuit status bar with manifest-backed widget slots.",
  version: "1.0.0",
  apiVersion: "1",
  kinds: ["bar"],
  entryPoints: { bar: "Bar.qml" },
  scope: { bar: "per-output" },
});

const production = surfacePlan(false);
assert.equal(production.length, 2, "one bar view per actual output");
assert.deepEqual(production.map((surface) => surface.owner), ["stillsuit.bar", "stillsuit.bar"]);
assert.deepEqual(production.map((surface) => surface.exclusionZone), [40, 40]);
assert.equal(new Set(production.map((surface) => surface.outputId)).size, 2);

const shadow = surfacePlan(true);
assert.deepEqual(shadow.map((surface) => surface.exclusionZone), [0, 0]);

assert.deepEqual(recordsFor("left").map((record) => record.id), [
  "stillsuit.spacer", "stillsuit.spacer", "stillsuit.workspaces",
]);
assert.deepEqual(recordsFor("center").map((record) => record.id), ["stillsuit.clock"]);
assert.deepEqual(recordsFor("right").map((record) => record.id), [
  "stillsuit.broken", "stillsuit.network",
]);
assert.equal(recordsFor("right").filter((record) => record.id === "stillsuit.network").length, 1);

const mountedRight = recordsFor("right").filter((record) => record.result === "ok");
assert.deepEqual(mountedRight.map((record) => record.id), ["stillsuit.network"]);
assert.match(slotSource, /releaseSlot\(message\)/);
assert.match(slotSource, /widgetLoader\.active = false/);
assert.match(slotSource, /registration\.service !== undefined/);
assert.match(barSource, /exclusiveZone: root\.shadowMode \? 0 : root\.exclusionZone/);
assert.match(barSource, /property var widgetRegistrations: \[\]/);
assert.match(barSource, /property var outputScreens: \[\]/);

console.log("d1 bar fixtures: ok");
