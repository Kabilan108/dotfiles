import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/builtin/clipboard" as Clipboard

ShellRoot {
    id: root

    readonly property string fakeDir: Quickshell.env("CLIP_FIXTURE_FAKE_DIR")
    readonly property string stateRoot: Quickshell.env("CLIP_FIXTURE_STATE_ROOT")
    readonly property string collector: Quickshell.env("CLIP_FIXTURE_COLLECTOR")
    readonly property string fakePaste: Quickshell.env("CLIP_FIXTURE_WL_PASTE")
    readonly property string idlePaste: Quickshell.env("CLIP_FIXTURE_IDLE_WL_PASTE")
    readonly property string fakeCopy: Quickshell.env("CLIP_FIXTURE_WL_COPY")
    readonly property string expiryRoot: Quickshell.env("CLIP_FIXTURE_EXPIRY_ROOT")
    readonly property var expiryIds: String(Quickshell.env("CLIP_FIXTURE_EXPIRY_IDS")).split(" ")
    readonly property string sweepRoot: Quickshell.env("CLIP_FIXTURE_SWEEP_ROOT")
    readonly property string sweepCollector: Quickshell.env("CLIP_FIXTURE_SWEEP_COLLECTOR")
    readonly property string sweepCalls: Quickshell.env("CLIP_FIXTURE_SWEEP_CALLS")
    readonly property string sweepYoung: Quickshell.env("CLIP_FIXTURE_SWEEP_YOUNG")
    readonly property string sweepFuture: Quickshell.env("CLIP_FIXTURE_SWEEP_FUTURE")
    readonly property string sweepStaging: Quickshell.env("CLIP_FIXTURE_SWEEP_STAGING")
    readonly property string geckoRoot: Quickshell.env("CLIP_FIXTURE_GECKO_ROOT")
    readonly property string geckoPaste: Quickshell.env("CLIP_FIXTURE_GECKO_PASTE")
    readonly property string recordRoot: Quickshell.env("CLIP_FIXTURE_RECORD_ROOT")
    readonly property string recordPaste: Quickshell.env("CLIP_FIXTURE_RECORD_PASTE")
    readonly property string recordSha: Quickshell.env("CLIP_FIXTURE_RECORD_SHA")
    readonly property string pendingRoot: Quickshell.env("CLIP_FIXTURE_PENDING_ROOT")
    readonly property string pendingX: Quickshell.env("CLIP_FIXTURE_PENDING_X")
    readonly property string pendingY: Quickshell.env("CLIP_FIXTURE_PENDING_Y")
    readonly property string slowCollector: Quickshell.env("CLIP_FIXTURE_SLOW_COLLECTOR")
    readonly property string failingCollector: Quickshell.env("CLIP_FIXTURE_FAILING_COLLECTOR")
    readonly property string failingCalls: Quickshell.env("CLIP_FIXTURE_FAILING_CALLS")
    readonly property string normalizeRoot: Quickshell.env("CLIP_FIXTURE_NORMALIZE_ROOT")
    readonly property string modelCollector: Quickshell.env("CLIP_FIXTURE_MODEL_COLLECTOR")
    readonly property string modelCalls: Quickshell.env("CLIP_FIXTURE_MODEL_CALLS")
    readonly property string modelRoot: Quickshell.env("CLIP_FIXTURE_MODEL_ROOT")
    readonly property string missingCopy: Quickshell.env("CLIP_FIXTURE_MISSING_WL_COPY")
    readonly property string durableRoot: Quickshell.env("CLIP_FIXTURE_DURABLE_ROOT")
    readonly property string durableX: Quickshell.env("CLIP_FIXTURE_DURABLE_X")
    readonly property string durableY: Quickshell.env("CLIP_FIXTURE_DURABLE_Y")
    readonly property string durableCollector: Quickshell.env("CLIP_FIXTURE_DURABLE_COLLECTOR")
    readonly property string durableCalls: Quickshell.env("CLIP_FIXTURE_DURABLE_CALLS")
    readonly property string durableSnapshots: Quickshell.env("CLIP_FIXTURE_DURABLE_SNAPSHOTS")
    readonly property string lateRoot: Quickshell.env("CLIP_FIXTURE_LATE_ROOT")
    readonly property var lateIds: String(Quickshell.env("CLIP_FIXTURE_LATE_IDS")).split(" ")
    readonly property string hangingCollector: Quickshell.env("CLIP_FIXTURE_HANGING_COLLECTOR")
    readonly property string latePids: Quickshell.env("CLIP_FIXTURE_LATE_PIDS")
    readonly property string gcGateRoot: Quickshell.env("CLIP_FIXTURE_GCGATE_ROOT")
    readonly property string gcGateX: Quickshell.env("CLIP_FIXTURE_GCGATE_X")
    readonly property string gcGateY: Quickshell.env("CLIP_FIXTURE_GCGATE_Y")
    readonly property string gcGateCollector: Quickshell.env("CLIP_FIXTURE_GCGATE_COLLECTOR")
    readonly property string gcGatePaste: Quickshell.env("CLIP_FIXTURE_GCGATE_PASTE")
    readonly property string gcGateFake: Quickshell.env("CLIP_FIXTURE_GCGATE_FAKE")
    readonly property string gcGateCalls: Quickshell.env("CLIP_FIXTURE_GCGATE_CALLS")
    readonly property real startedAt: Date.now()
    property var logLines: []
    property int checks: 0
    property int step: 0
    property real stepStarted: Date.now()
    property bool sawDegraded: false
    property string alphaId: ""
    property string bravoId: ""
    property string imageId: ""
    property var shortLived: null

    property int expiryStep: 0
    property real expiryStepStarted: 0
    property real e2LastUsed: 0
    property real e1ExpiresAt: 0
    property int sweepStep: 0
    property real sweepGoneAt: 0
    property int geckoStep: 0
    property int recordStep: 0
    property int pendingStep: 0
    property real pendingStepStarted: 0
    property var pendingService: null
    property int normalizeStep: 0
    property real normalizeStarted: 0
    property int modelStep: 0
    property var lateModelled: null
    property var lateHelperPids: []
    property real modelStepStarted: 0
    property int durableStep: 0
    property real durableStepStarted: 0
    property var durableService: null
    property int gcGateStep: 0
    property real gcGateStepStarted: 0
    property var gcGateService: null
    property int gcGateRunsBefore: 0

    function makeContext(values, stateRootPath, tag) {
        return contextComponent.createObject(root, { values: values, stateRootPath: stateRootPath, tag: tag || "" })
    }

    // Production gc grace (the default, 120 s) unless a test overrides it.
    function baseValues(pastePath, extra) {
        var values = {
            collectorPath: collector,
            wlPastePath: pastePath,
            wlCopyPath: fakeCopy,
            secretSourcePrefixes: ["chrome-extension://nngceckbapebfimnlniiiahkandclblb/",
                "https://vault.sole-pierce.ts.net"]
        }
        for (var key in extra || {})
            values[key] = extra[key]
        return values
    }

    property Component contextComponent: Component {
        QtObject {
            id: fixtureContext
            property var values: ({})
            property string stateRootPath: ""
            property string tag: ""
            property var settings: QtObject {
                property var values: ({})
                property var paths: ({ stateRoot: "" })
            }
            property var logger: QtObject {
                function debug(message) { root.logLines.push(fixtureContext.tag + "debug " + message) }
                function info(message) { root.logLines.push(fixtureContext.tag + "info " + message) }
                function warn(message) { root.logLines.push(fixtureContext.tag + "warn " + message) }
                function error(message) { root.logLines.push(fixtureContext.tag + "error " + message) }
            }
            Component.onCompleted: {
                settings.values = values
                settings.paths = { stateRoot: stateRootPath }
            }
        }
    }

    property var mainContext: makeContext(baseValues(fakePaste), stateRoot)
    property var brokenContext: makeContext({ collectorPath: "", wlPastePath: fakePaste, wlCopyPath: fakeCopy },
        stateRoot)
    property var unwritableContext: makeContext(baseValues(fakePaste), "/proc/stillsuit-clipboard-fixture")
    property var expiryContext: makeContext(baseValues(idlePaste, { ttlHours: 0.1, wlCopyPath: missingCopy }),
        expiryRoot)
    property var sweepContext: makeContext(baseValues(idlePaste, { collectorPath: sweepCollector, gcGraceSec: 4 }),
        sweepRoot)
    property var geckoContext: makeContext(baseValues(geckoPaste), geckoRoot)
    property var recordContext: makeContext(baseValues(recordPaste, { unattributedFirefox: "record" }), recordRoot)
    property var normalizeContext: makeContext(baseValues(idlePaste), normalizeRoot)
    // No production settings at all, as in the workbench.
    property var modelContext: makeContext({ collectorPath: modelCollector }, modelRoot, "model: ")

    property QtObject fixtureModel: QtObject {
        property int revision: 1
        property var items: [
            { id: "m1", kind: "text", mime: "text/plain", bytes: 12, preview: "fixture text", created: 1, lastUsed: 2 },
            { id: "m2", kind: "image", mime: "image/png", bytes: 40, preview: "", path: "/fixture.png" }
        ]
        property string lastAction: ""
        function copy(id) { lastAction = "copy " + id; return "ok" }
        function remove(id) {
            lastAction = "remove " + id
            items = items.filter(function(item) { return item.id !== id })
            revision++
            return "ok"
        }
        function clear() { lastAction = "clear"; items = []; revision++; return "ok" }
    }

    Clipboard.Service { id: service; context: root.mainContext }
    Clipboard.Service { id: broken; context: root.brokenContext }
    Clipboard.Service { id: unwritable; context: root.unwritableContext }
    Clipboard.Service { id: expiring; context: root.expiryContext }
    Clipboard.Service { id: sweeper; context: root.sweepContext }
    Clipboard.Service { id: gecko; context: root.geckoContext }
    Clipboard.Service { id: recorder; context: root.recordContext }
    Clipboard.Service { id: normalizer; context: root.normalizeContext }
    Clipboard.Service { id: modelled; context: root.modelContext; model: root.fixtureModel }

    property Component transientComponent: Component {
        Clipboard.Service {}
    }

    Connections {
        target: service
        function onStatusChanged() {
            if (service.status === "degraded" && service.error.indexOf("status 3") >= 0)
                root.sawDegraded = true
        }
    }

    FileView {
        id: reader
        blockLoading: true
        printErrors: false
        watchChanges: false
    }

    FileView {
        id: gateWriter
        printErrors: false
    }

    function readFile(path) {
        reader.path = ""
        reader.path = path
        reader.reload()
        return reader.text()
    }

    function verify(condition, message) {
        checks++
        if (!condition)
            throw new Error(message)
    }

    function byPreview(prefix) {
        for (var index = 0; index < service.items.length; index++) {
            if (service.items[index].kind === "text" && service.items[index].preview.indexOf(prefix) === 0)
                return service.items[index]
        }
        return null
    }

    function itemIds(target) {
        var ids = []
        for (var index = 0; index < target.items.length; index++)
            ids.push(target.items[index].id)
        return ids
    }

    function logged(fragment) {
        for (var index = 0; index < logLines.length; index++) {
            if (logLines[index].indexOf(fragment) >= 0)
                return true
        }
        return false
    }

    function historyShas(rootPath) {
        var history = JSON.parse(readFile(rootPath + "/clipboard/history.v1.json"))
        verify(history.schemaVersion === 1, "history schema version")
        var shas = []
        for (var index = 0; index < history.entries.length; index++)
            shas.push(history.entries[index].sha)
        return shas
    }

    function advance() {
        step++
        stepStarted = Date.now()
    }

    function tick() {
        var waited = Date.now() - stepStarted
        if (step === 0) {
            if (!(service.status === "ok" && service.items.length === 3 && service.items[1].kind === "image"
                    && service.items[0].preview === "alpha line\n"))
                return
            verify(broken.status === "error", "missing collector path must set status error")
            verify(broken.error.indexOf("collectorPath") >= 0, "error names the bad setting: " + broken.error)
            verify(broken.copy("x") === "unavailable", "broken service refuses copy")
            verify(broken.items.length === 0, "broken service has no items")
            alphaId = service.items[0].id
            imageId = service.items[1].id
            bravoId = service.items[2].id
            verify(service.items[2].preview === "bravo line\n", "bravo recorded")
            verify(service.items[1].path === stateRoot + "/clipboard/blobs/" + imageId, "image blob path")
            verify(service.items[0].path === "", "text items carry no path")
            verify(service.revision > 0, "revision advances")
            for (var index = 0; index < service.items.length; index++)
                verify(service.items[index].preview.indexOf("SECRET") < 0, "secret copy was not recorded")
            gateWriter.path = fakeDir + "/gate-1"
            gateWriter.setText("go\n")
            advance()
        } else if (step === 1) {
            if (unwritable.status !== "error")
                return
            verify(unwritable.error.indexOf("unusable") >= 0, "init failure is reported: " + unwritable.error)
            advance()
        } else if (step === 2) {
            if (!(sawDegraded && service.status === "ok"))
                return
            verify(service.items.length === 4, "a failed sender's empty read purged nothing: "
                + JSON.stringify(service.items))
            var charlie = byPreview("charlie")
            verify(charlie !== null && service.items[0].id === charlie.id, "charlie kept and newest")
            verify(service.copy(bravoId) === "ok", "copy accepted")
            verify(service.items[0].id === charlie.id, "copy moves the item only once wl-copy succeeded")
            verify(service.copy("missing") === "unknown", "copy of a missing id")
            advance()
        } else if (step === 3) {
            if (readFile(fakeDir + "/wl-copy.stdin") !== "bravo line\n" || service.items[0].id !== bravoId)
                return
            verify(readFile(fakeDir + "/wl-copy.argv") === "--type\ntext/plain;charset=utf-8\n", "wl-copy argv")
            verify(readFile(stateRoot + "/clipboard/blobs/" + imageId) !== "", "image blob present before remove")
            verify(service.remove(imageId) === "ok", "remove image")
            verify(service.remove(imageId) === "unknown", "second remove is unknown")
            verify(service.items.length === 3, "three items remain")
            advance()
        } else if (step === 4) {
            if (waited < 600)
                return
            verify(readFile(stateRoot + "/clipboard/blobs/" + imageId) === "",
                "removed image blob deleted at once despite the 120 s gc grace")
            var shas = historyShas(stateRoot)
            verify(shas.length === 3, "history persisted after remove")
            verify(shas[0] === bravoId, "history keeps copy order")
            shortLived = transientComponent.createObject(root, { context: makeContext(baseValues(idlePaste), stateRoot) })
            advance()
        } else if (step === 5) {
            if (shortLived.status !== "ok")
                return
            shortLived.destroy()
            verify(service.clear() === "ok", "clear accepted")
            verify(service.items.length === 0, "clear empties items")
            advance()
        } else if (step === 6) {
            if (waited < 1500)
                return
            verify(historyShas(stateRoot).length === 0, "cleared history persisted")
            verify(readFile(stateRoot + "/clipboard/blobs/" + alphaId) === ""
                && readFile(stateRoot + "/clipboard/blobs/" + bravoId) === "", "cleared blobs deleted at once")
            advance()
        } else if (step === 7) {
            if (expiryStep < 4 || sweepStep < 3 || geckoStep < 1 || recordStep < 2 || pendingStep < 5
                    || normalizeStep < 1 || modelStep < 3 || durableStep < 5 || gcGateStep < 4)
                return
            for (var line = 0; line < logLines.length; line++) {
                var logged = logLines[line]
                verify(logged.indexOf("model: ") !== 0, "the model-driven service logged: " + logged)
                verify(logged.indexOf("SECRET") < 0 && logged.indexOf("GECKO-secret") < 0
                    && logged.indexOf("RECORD-password") < 0
                    && logged.indexOf("alpha line") < 0 && logged.indexOf("bravo line") < 0
                    && logged.indexOf("charlie line") < 0,
                    "logs carry no clipboard content: " + logged)
            }
            console.log("CLIPBOARD_FIXTURE_OK", checks)
            Qt.quit()
        }
    }

    // copy() checks expiry before acting and updates order only on success.
    // A copy whose blob is gone drops the entry; any other failure keeps it.
    function tickExpiry() {
        var e1 = expiryIds[0], e2 = expiryIds[1], e3 = expiryIds[2]
        var waited = Date.now() - expiryStepStarted
        if (expiryStep === 0) {
            if (!(expiring.status === "ok" && expiring.items.length === 3))
                return
            verify(itemIds(expiring).join() === [e2, e3, e1].join(), "expiry fixture order")
            e2LastUsed = expiring.items[0].lastUsed
            e1ExpiresAt = expiring.items[2].lastUsed + 360000
            verify(expiring.copy(e3) === "ok", "copy of an entry without a blob is attempted")
            verify(expiring.copy(e2) === "ok", "copy without wl-copy is attempted")
            verify(expiring.items[1].id === e3, "copy does not reorder before it succeeds")
        } else if (expiryStep === 1) {
            if (itemIds(expiring).indexOf(e3) >= 0 || !logged("clipboard copy failed with status 1"))
                return
            verify(logged("stored copy is gone"), "the dropped entry is logged")
            verify(itemIds(expiring).join() === [e2, e1].join(), "only the entry without a blob is dropped")
            verify(expiring.items[0].lastUsed === e2LastUsed, "a failed copy leaves order and lastUsed alone")
            verify(expiring.copy(e3) === "unknown", "the dropped entry is unknown")
        } else if (expiryStep === 2) {
            if (Date.now() < e1ExpiresAt + 50)
                return
            verify(historyShas(expiryRoot).join() === [e2, e1].join(), "the dropped entry is gone on disk")
            verify(itemIds(expiring).indexOf(e1) >= 0, "expired entry still listed until the next prune")
            verify(expiring.copy(e1) === "unknown", "copy of an expired entry is refused")
            verify(itemIds(expiring).join() === e2, "copy prunes the expired entry")
        } else if (expiryStep === 3) {
            if (waited < 700)
                return
            verify(historyShas(expiryRoot).join() === e2, "expired entry not resurrected on disk")
        } else {
            return
        }
        expiryStep++
        expiryStepStarted = Date.now()
    }

    // Deferred orphans and staging files get one follow-up sweep, when the
    // first of them becomes eligible.
    function gcRuns() {
        var count = 0
        var lines = readFile(sweepCalls).split("\n")
        for (var index = 0; index < lines.length; index++) {
            if (lines[index] === "gc")
                count++
        }
        return count
    }

    function tickSweep() {
        if (sweepStep === 0) {
            if (sweeper.status !== "ok" || gcRuns() < 1)
                return
            verify(readFile(sweepYoung) === "y", "first sweep defers the young orphan")
            verify(readFile(sweepStaging) === "s", "first sweep defers the staging file")
        } else if (sweepStep === 1) {
            if (readFile(sweepYoung) !== "" || readFile(sweepStaging) !== "")
                return
            verify(gcRuns() === 2, "one follow-up sweep removed the young orphan and the staging file")
            sweepGoneAt = Date.now()
        } else if (sweepStep === 2) {
            if (Date.now() - sweepGoneAt < 7000)
                return
            verify(gcRuns() === 2, "the follow-up schedules no further sweep")
            verify(readFile(sweepFuture) === "f", "a future-dated orphan stays deferred")
        } else {
            return
        }
        sweepStep++
    }

    function previews(target) {
        var result = []
        for (var index = 0; index < target.items.length; index++)
            result.push(target.items[index].preview)
        return result
    }

    function historyDocument(rootPath) {
        return JSON.parse(readFile(rootPath + "/clipboard/history.v1.json"))
    }

    function pendingShas(rootPath) {
        var document = historyDocument(rootPath)
        var shas = []
        var batches = document.pendingRemovals || []
        for (var b = 0; b < batches.length; b++)
            shas = shas.concat(batches[b].shas)
        return shas
    }

    // The probe replay in skip mode: only the page copy and the sentinel.
    function tickGecko() {
        if (geckoStep !== 0 || previews(gecko).indexOf("GECKO-done") < 0)
            return
        verify(previews(gecko).join("|") === "GECKO-done|GECKO-page-copy",
            "only the attributed copy is recorded: " + previews(gecko).join("|"))
        geckoStep++
    }

    // Record mode: the nil events keep the clear attached, so it purges. An
    // empty read of another offer's types does not purge.
    function tickRecord() {
        if (recordStep === 0) {
            if (previews(recorder).indexOf("RECORD-after") < 0)
                return
            verify(previews(recorder).join("|") === "RECORD-after|RECORD-done",
                "the clear purged the unattributed copy, the other app's empty read nothing: "
                + previews(recorder).join("|"))
        } else if (recordStep === 1) {
            if (readFile(recordRoot + "/clipboard/blobs/" + recordSha) !== "")
                return
        } else {
            return
        }
        recordStep++
    }

    function pendingContext(collectorPath) {
        return makeContext(baseValues(idlePaste, { collectorPath: collectorPath }), pendingRoot)
    }

    function blob(rootPath, sha) {
        return readFile(rootPath + "/clipboard/blobs/" + sha)
    }

    // A removal survives an `rm` killed by shutdown, a failing `rm` and a
    // restart, and its blob goes long before the 120 s gc grace would allow.
    function tickPending() {
        var waited = Date.now() - pendingStepStarted
        if (pendingStep === 0) {
            if (!pendingService)
                pendingService = transientComponent.createObject(root, { context: pendingContext(slowCollector) })
            if (pendingService.status !== "ok" || pendingService.items.length !== 2)
                return
            verify(pendingService.remove(pendingX) === "ok", "remove x")
            pendingService.destroy()
            pendingService = null
        } else if (pendingStep === 1) {
            if (blob(pendingRoot, pendingX) !== "")
                return
            verify(waited < 8000, "x was deleted after the shutdown")
            verify(historyShas(pendingRoot).join() === pendingY, "history kept y only")
            pendingService = transientComponent.createObject(root, { context: pendingContext(failingCollector) })
        } else if (pendingStep === 2) {
            if (pendingService.status !== "ok" || readFile(failingCalls) === "")
                return
            verify(pendingService.remove(pendingY) === "ok", "remove y")
        } else if (pendingStep === 3) {
            if (waited < 1200)
                return
            verify(blob(pendingRoot, pendingY) === "pending-y", "a failing rm leaves y in place")
            verify(pendingShas(pendingRoot).indexOf(pendingY) >= 0, "y's removal is persisted while it fails")
            verify(pendingShas(pendingRoot).indexOf(pendingX) >= 0, "x's failed removal is kept for a retry")
            pendingService.destroy()
            pendingService = transientComponent.createObject(root, { context: pendingContext(collector) })
        } else if (pendingStep === 4) {
            if (blob(pendingRoot, pendingY) !== "" || pendingShas(pendingRoot).length !== 0)
                return
            verify(waited < 8000, "the restart finished the removal")
            verify(historyShas(pendingRoot).length === 0, "history is empty")
            pendingService.destroy()
            pendingService = null
        } else {
            return
        }
        pendingStep++
        pendingStepStarted = Date.now()
    }

    function tickNormalize() {
        if (normalizeStep !== 0 || normalizer.status !== "ok")
            return
        if (normalizeStarted === 0)
            normalizeStarted = Date.now()
        if (Date.now() - normalizeStarted < 800)
            return
        var entry = historyDocument(normalizeRoot).entries[0]
        verify(entry.lastUsed <= Date.now(), "a future timestamp was written back clamped")
        verify(entry.unattributed === undefined, "dropped fields were written away")
        normalizeStep++
    }

    function tickModel() {
        if (modelStep === 0) {
            if (modelled.status !== "ok")
                return
            verify(modelled.error === "", "a model-driven service reports no error")
            verify(previews(modelled).join("|") === "fixture text|", "items come from the model")
            verify(modelled.items[1].path === "/fixture.png", "fixture image path")
            verify(modelled.copy("m1") === "ok" && fixtureModel.lastAction === "copy m1", "copy goes to the model")
            verify(modelled.remove("m1") === "ok" && modelled.items.length === 1, "remove goes to the model")
            lateModelled = transientComponent.createObject(root,
                { context: makeContext(baseValues(idlePaste, { collectorPath: hangingCollector }), lateRoot) })
        } else if (modelStep === 1) {
            if (lateModelled.status !== "ok")
                return
            if (modelStepStarted === 0) {
                verify(lateModelled.copy(lateIds[0]) === "ok", "late copy starts")
                verify(lateModelled.remove(lateIds[1]) === "ok", "late remove starts")
                modelStepStarted = Date.now()
            }
            lateHelperPids = []
            var helpers = ["copy", "rm", "gc"]
            for (var h = 0; h < helpers.length; h++) {
                var pid = readFile(latePids + helpers[h] + ".pid")
                if (pid === "")
                    return
                lateHelperPids.push(pid)
            }
            for (var live = 0; live < lateHelperPids.length; live++)
                verify(readFile("/proc/" + lateHelperPids[live] + "/cmdline") !== "", "late helpers are running")
            lateModelled.model = fixtureModel
            verify(previews(lateModelled).join("|") === "", "a late model replaces the live items: "
                + previews(lateModelled).join("|"))
            verify(lateModelled.clear() === "ok" && fixtureModel.lastAction === "clear", "clear goes to the model")
            modelStepStarted = Date.now()
        } else if (modelStep === 2) {
            verify(lateModelled.items.length === 0, "model items follow the model")
            if (Date.now() - modelStepStarted < 500)
                return
            for (var index = 0; index < lateHelperPids.length; index++)
                verify(readFile("/proc/" + lateHelperPids[index] + "/cmdline") === "",
                    "a helper kept running after the model was attached: pid " + lateHelperPids[index])
            lateModelled.destroy()
            lateModelled = null
        } else {
            return
        }
        modelStep++
    }

    function durableContext() {
        return makeContext(baseValues(idlePaste, { collectorPath: durableCollector }), durableRoot)
    }

    function snapshot(index) {
        var raw = readFile(durableSnapshots + index)
        return raw === "" ? null : JSON.parse(raw)
    }

    function rmCalls() {
        var raw = readFile(durableCalls)
        return raw === "" ? 0 : raw.split("\n").length - 1
    }

    function setDurableMode(mode) {
        chmodProcess.command = ["chmod", mode, durableRoot + "/clipboard"]
        chmodProcess.running = true
    }

    // A dropped entry is gone from the history on disk, with its removal
    // pending, before `rm` starts; a failed write holds `rm` back until a
    // retry succeeds.
    function tickDurable() {
        var waited = Date.now() - durableStepStarted
        if (durableStep === 0) {
            if (!durableService)
                durableService = transientComponent.createObject(root, { context: durableContext() })
            if (durableService.status !== "ok" || durableService.items.length !== 2)
                return
            verify(durableService.remove(durableX) === "ok", "remove x")
        } else if (durableStep === 1) {
            if (blob(durableRoot, durableX) !== "")
                return
            var first = snapshot(0)
            verify(first !== null, "rm ran")
            verify(first.entries.length === 1 && first.entries[0].sha === durableY,
                "x was off the history on disk before rm started: " + JSON.stringify(first.entries))
            verify(JSON.stringify(first.pendingRemovals || []).indexOf(durableX) >= 0,
                "x's removal was on disk before rm started")
            setDurableMode("500")
        } else if (durableStep === 2) {
            if (chmodProcess.running || waited < 200)
                return
            verify(durableService.remove(durableY) === "ok", "remove y")
            verify(durableService.items.length === 0, "y is gone from the items at once")
        } else if (durableStep === 3) {
            if (waited < 1500)
                return
            verify(rmCalls() === 1, "rm ran while the history could not be written")
            verify(blob(durableRoot, durableY) === "durable-y", "y's blob outlived a failed write")
            verify(historyShas(durableRoot).join() === durableY, "the history on disk still lists y")
            verify(logged("clipboard history could not be written; retrying"), "the failed write is logged")
            setDurableMode("700")
        } else if (durableStep === 4) {
            if (blob(durableRoot, durableY) !== "" || pendingShas(durableRoot).length !== 0)
                return
            var second = snapshot(1)
            verify(second !== null && second.entries.length === 0, "the retried write dropped y before rm")
            verify(JSON.stringify(second.pendingRemovals || []).indexOf(durableY) >= 0,
                "y's removal was on disk before rm started")
            verify(historyShas(durableRoot).length === 0, "durable history is empty")
            durableService.destroy()
            durableService = null
        } else {
            return
        }
        durableStep++
        durableStepStarted = Date.now()
    }

    function gcGateRuns() {
        var raw = readFile(gcGateCalls)
        var runs = []
        var lines = raw.split("\n")
        for (var index = 0; index < lines.length; index++) {
            if (lines[index] !== "")
                runs.push(JSON.parse(lines[index]))
        }
        return runs
    }

    function verifyGcGateRuns() {
        var runs = gcGateRuns()
        for (var index = 0; index < runs.length; index++) {
            verify(runs[index].mode !== "0o500", "gc ran while the history could not be written")
            verify(runs[index].missing.length === 0,
                "gc was free to delete blobs the history on disk lists: " + runs[index].missing.join())
        }
        return runs
    }

    function setGcGateMode(mode) {
        gcGateChmod.command = ["chmod", mode, gcGateRoot + "/clipboard"]
        gcGateChmod.running = true
    }

    // A dropped entry whose history write fails stays listed on disk, so its
    // blob must outlive every gc until a write succeeds; a gc asked for in
    // the meantime runs once it has.
    function tickGcGate() {
        var waited = Date.now() - gcGateStepStarted
        if (gcGateStep === 0) {
            if (!gcGateService)
                gcGateService = transientComponent.createObject(root, { context: makeContext(
                    baseValues(gcGatePaste, { collectorPath: gcGateCollector }), gcGateRoot, "gcgate: ") })
            if (gcGateService.status !== "ok" || gcGateService.items.length !== 2 || verifyGcGateRuns().length < 1)
                return
            setGcGateMode("500")
        } else if (gcGateStep === 1) {
            if (gcGateChmod.running || waited < 200)
                return
            verify(gcGateService.remove(gcGateX) === "ok", "remove x")
            gcGateSignal.path = gcGateFake + "/gcgate-go"
            gcGateSignal.setText("go\n")
        } else if (gcGateStep === 2) {
            if (!logged("gcgate: warn clipboard watcher exited") || waited < 4000)
                return
            gcGateRunsBefore = verifyGcGateRuns().length
            verify(historyShas(gcGateRoot).join() === [gcGateX, gcGateY].join(), "the history on disk still lists x")
            verify(blob(gcGateRoot, gcGateX) === "gcgate-x", "x's blob outlived the failed write")
            setGcGateMode("700")
        } else if (gcGateStep === 3) {
            if (blob(gcGateRoot, gcGateX) !== "" || verifyGcGateRuns().length <= gcGateRunsBefore)
                return
            verify(historyShas(gcGateRoot).join() === gcGateY, "the retried write dropped x")
            gcGateService.destroy()
            gcGateService = null
        } else {
            return
        }
        gcGateStep++
        gcGateStepStarted = Date.now()
    }

    Process {
        id: chmodProcess
    }

    Process {
        id: gcGateChmod
    }

    FileView {
        id: gcGateSignal
        printErrors: false
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            try {
                if ((root.step < 7 && Date.now() - root.stepStarted > 15000) || Date.now() - root.startedAt > 70000)
                    throw new Error("timed out in step " + root.step + " expiry " + root.expiryStep
                        + " sweep " + root.sweepStep + " gecko " + root.geckoStep + " record " + root.recordStep
                        + " pending " + root.pendingStep + " normalize " + root.normalizeStep
                        + " model " + root.modelStep + " durable " + root.durableStep
                        + " gcgate " + root.gcGateStep
                        + "; status " + service.status
                        + " error " + service.error + " items " + JSON.stringify(service.items))
                root.tick()
                root.tickExpiry()
                root.tickSweep()
                root.tickGecko()
                root.tickRecord()
                root.tickPending()
                root.tickNormalize()
                root.tickModel()
                root.tickDurable()
                root.tickGcGate()
            } catch (error) {
                console.error("CLIPBOARD_FIXTURE_FAIL", error, JSON.stringify(root.logLines))
                running = false
                Qt.exit(1)
            }
        }
    }
}
