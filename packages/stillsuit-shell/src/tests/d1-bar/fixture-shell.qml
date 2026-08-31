import QtQuick
import Quickshell
import "bar"

ShellRoot {
    id: fixture

    readonly property var goodRegistration: ({
        component: requiredWidgetComponent,
        context: fixtureContext,
        service: tracker,
        manifest: { id: "stillsuit.fixture-good" },
        release: function(message) {
            throw new Error("valid widget released its registration: " + message)
        }
    })
    readonly property var failingRegistration: ({
        component: missingServiceComponent,
        context: fixtureContext,
        manifest: { id: "stillsuit.fixture-missing-service" },
        release: function(message) {
            tracker.recordRelease(message)
        }
    })
    readonly property var staleFailureRegistration: ({
        component: missingServiceComponent,
        context: fixtureContext,
        manifest: { id: "stillsuit.fixture-stale" },
        release: function(message) {
            tracker.recordStaleRelease(message)
        }
    })
    readonly property var staleBuildRegistration: ({
        component: requiredWidgetComponent,
        context: fixtureContext,
        service: staleService,
        manifest: { id: "stillsuit.fixture-stale-build" },
        release: function(message) {
            throw new Error("stale build widget released its registration: " + message)
        }
    })
    readonly property var replacementRegistration: ({
        component: requiredWidgetComponent,
        context: fixtureContext,
        service: tracker,
        manifest: { id: "stillsuit.fixture-replacement" },
        release: function(message) {
            throw new Error("replacement widget released its registration: " + message)
        }
    })

    QtObject {
        id: tracker

        property int constructionCount: 0
        property int destructionCount: 0
        property int releaseCount: 0
        property int staleConstructionCount: 0
        property int staleReleaseCount: 0
        property int warningCount: 0
        property string releasedMessage: ""

        function recordConstruction(instanceId) {
            fixture.assert(instanceId === "d1-bar-fixture",
                "constructed widget did not receive its required context")
            constructionCount++
        }

        function recordDestruction() {
            destructionCount++
        }

        function recordRelease(message) {
            releaseCount++
            releasedMessage = String(message)
        }

        function recordStaleRelease(message) {
            staleReleaseCount++
        }
    }

    QtObject {
        id: staleService

        function recordConstruction(instanceId) {
            tracker.staleConstructionCount++
        }

        function recordDestruction() {}
    }

    QtObject {
        id: fixtureContext

        readonly property string instanceId: "d1-bar-fixture"
        readonly property var theme: ({
            colors: {
                surface: { panel: "#1e1e2e" },
                border: { normal: "#45475a", focus: "#89b4fa" },
                text: { primary: "#cdd6f4", secondary: "#a6adc8" }
            },
            typography: { family: "sans-serif", baseSize: 13 },
            geometry: { barHeight: 34, panelGap: 6, radius: 8 }
        })
        readonly property QtObject compositor: QtObject {
            readonly property string focusedOutputId: ""
        }
        readonly property QtObject settings: QtObject {
            readonly property var values: ({ shadowMode: true })
        }
        readonly property QtObject logger: QtObject {
            function warn(message) {
                tracker.warningCount++
            }
        }
    }

    Component {
        id: requiredWidgetComponent
        RequiredWidget {}
    }

    Component {
        id: missingServiceComponent
        RequiredWidget {}
    }

    Bar {
        id: fixtureBar
        objectName: "d1-fixture-bar"
        context: fixtureContext
        widgetRegistrations: []
        outputScreens: []
    }

    WidgetSlot {
        id: testedSlot
        registration: fixture.goodRegistration
    }

    Timer {
        property int phase: 0

        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (phase === 0) {
                fixture.assert(tracker.constructionCount === 1,
                    "required-property widget was not constructed exactly once")
                fixture.assert(testedSlot.createdWidget !== null && !testedSlot.failed,
                    "valid widget instance is not retained by its slot")
                fixture.assert(testedSlot.children.length === 1,
                    "valid slot retained duplicate visual instances")
                testedSlot.registration = fixture.staleBuildRegistration
                testedSlot.registration = fixture.staleFailureRegistration
                testedSlot.registration = fixture.replacementRegistration
                phase = 1
                return
            }

            if (phase === 1) {
                fixture.assert(tracker.constructionCount === 2,
                    "rapid registration replacement built a stale or duplicate widget")
                fixture.assert(tracker.destructionCount === 1,
                    "rapid registration replacement did not destroy the prior widget")
                fixture.assert(tracker.staleConstructionCount === 0,
                    "stale scheduled construction built its superseded registration")
                fixture.assert(tracker.staleReleaseCount === 0,
                    "stale scheduled construction released its superseded registration")
                fixture.assert(tracker.warningCount === 0,
                    "stale scheduled construction reached the failure path")
                fixture.assert(testedSlot.createdWidget !== null && !testedSlot.failed,
                    "replacement widget was not retained")
                fixture.assert(testedSlot.children.length === 1,
                    "rapid replacement retained duplicate visual instances")
                testedSlot.registration = fixture.failingRegistration
                phase = 2
                return
            }

            stop()
            fixture.assert(tracker.constructionCount === 2,
                "failing replacement constructed another valid widget")
            fixture.assert(tracker.destructionCount === 2,
                "failing replacement did not destroy the prior widget")
            fixture.assert(tracker.releaseCount === 1,
                "failing widget did not release its claim exactly once")
            fixture.assert(tracker.staleConstructionCount === 0,
                "superseded registration constructed after the final replacement")
            fixture.assert(tracker.staleReleaseCount === 0,
                "superseded registration released after the final construction")
            fixture.assert(tracker.warningCount === 1,
                "failing widget did not log exactly one warning")
            fixture.assert(tracker.releasedMessage === "component construction returned null",
                "release callback received an unexpected error message")
            fixture.assert(testedSlot.createdWidget === null && testedSlot.failed,
                "failed widget remained visible")
            fixture.assert(fixtureBar.objectName === "d1-fixture-bar",
                "bar did not survive widget construction failure")
            console.log("d1 qml fixture: ok")
            Qt.quit()
        }
    }

    function assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }
}
