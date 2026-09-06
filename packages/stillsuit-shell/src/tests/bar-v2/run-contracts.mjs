import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const fixtureDir = dirname(fileURLToPath(import.meta.url));
const sourceRoot = join(fixtureDir, "../..");
const ownedFiles = [
  "plugins/builtin/bar/Bar.qml",
  "plugins/builtin/bar/WidgetSlot.qml",
  "plugins/builtin/clock/ClockService.qml",
  "plugins/builtin/clock/ClockWidget.qml",
  "plugins/builtin/workspaces/WorkspaceWidget.qml",
  "plugins/builtin/osd/DictationPill.qml",
  "plugins/builtin/osd/OsdBar.qml",
  "plugins/builtin/osd/OsdOverlay.qml",
  "plugins/builtin/osd/Service.qml",
];
const sources = Object.fromEntries(ownedFiles.map((path) => [
  path,
  readFileSync(join(sourceRoot, path), "utf8"),
]));
const allSource = Object.values(sources).join("\n");

assert.doesNotMatch(allSource, /theme\.(?:colors|geometry|controls)\b/);
assert.doesNotMatch(allSource, /\.palette\b/);
assert.doesNotMatch(allSource, /#[0-9a-fA-F]{6}/);
assert.doesNotMatch(allSource, /component\.osd\.background/);
assert.doesNotMatch(allSource, /Behavior on (?:implicitWidth|implicitHeight|width|height)/);

const bar = sources["plugins/builtin/bar/Bar.qml"];
assert.match(bar, /context\.theme\.metrics\.barHeight/);
assert.match(bar, /context\.theme\.metrics\.barOuterGap/);
assert.match(bar, /top: true[\s\S]*left: true[\s\S]*right: true/);
assert.match(bar, /exclusiveZone: root\.shadowMode \? 0 : root\.exclusionZone/);
assert.match(bar, /Ui\.ShellSurface/);
assert.match(bar, /kind: "bar"\s*\n\s*radius: 0/);
assert.match(bar, /id: centerSlot[\s\S]*anchors\.centerIn: parent/);
assert.match(bar, /visible: root\.recordsFor\("center"\)\.length === 0/);

const workspaces = sources["plugins/builtin/workspaces/WorkspaceWidget.qml"];
assert.match(workspaces, /id: contentRow[\s\S]*id: workspaceStrip[\s\S]*id: separator[\s\S]*id: columnStrip/);
assert.match(workspaces, /component\.bar\.workspaceActive/);
assert.match(workspaces, /component\.bar\.workspaceIdle/);
assert.match(workspaces, /reducedMotion \? 0 : context\.theme\.motion\.fast/);

const clock = sources["plugins/builtin/clock/ClockWidget.qml"];
assert.match(clock, /Ui\.ShellText/);
assert.match(clock, /required property string outputId/);
assert.match(clock, /accessibleName/);

const osdBar = sources["plugins/builtin/osd/OsdBar.qml"];
assert.match(osdBar, /kind: "osd"/);
assert.match(osdBar, /semantic\.surface\.panel/);
assert.match(osdBar, /component\.osd\.(?:border|track|fill|text)/);
assert.match(osdBar, /semantic\.signal\[signalRole\]/);
assert.match(osdBar, /reducedMotion \? 0 : context\.theme\.motion\.normal/);

const overlay = sources["plugins/builtin/osd/OsdOverlay.qml"];
assert.match(overlay, /signalRole: "audio"/);
assert.match(overlay, /signalRole: "brightness"/);
assert.match(overlay, /required property string outputId/);

const dictation = sources["plugins/builtin/osd/DictationPill.qml"];
assert.match(dictation, /kind: "osd"/);
assert.match(dictation, /semantic\.surface\.panel/);
assert.match(dictation, /semantic\.signal\.microphone/);
assert.match(dictation, /visualizerState === "transcribing" && !root\.reducedMotion/);

const osdManifest = JSON.parse(readFileSync(
  join(sourceRoot, "plugins/builtin/osd/manifest.json"), "utf8"));
assert.equal(osdManifest.scope.service, "global");
assert.equal(osdManifest.scope.overlay, "per-output");

const themeSource = readFileSync(
  join(sourceRoot, "../themes/catppuccin-mocha.nix"), "utf8");
assert.match(themeSource, /barHeight = 28;/);
assert.match(themeSource, /barOuterGap = 0;/);

console.log("bar v2 source contracts: ok");
