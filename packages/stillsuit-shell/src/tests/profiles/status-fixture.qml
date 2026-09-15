import QtQuick
import Quickshell
import "core" as Core

ShellRoot {
    id: fixture

    QtObject {
        id: catalog

        property bool reconciling: false
        property int profileRevision: 1
        property string activeProfile: "work"
        property var availableProfiles: [
            { id: "default", name: "Default", description: "Base plugins" },
            { id: "work", name: "Work", description: "Work plugins" }
        ]
        property string loadError: ""
        property var failures: ({})
        property var runtimeErrors: ({})

        signal reconciliationFinished(var changedIds, var addedIds, var removedIds)
        signal pluginContained(string pluginId, string kind, string message)
    }

    QtObject {
        id: services

        property int revision: 0

        function statusRecords() {
            return ({})
        }
    }

    QtObject {
        id: surfaces

        property int pendingLoadCount: 0
        property int revision: 0
        property var records: ({})

        function statusRecords() {
            return records
        }
    }

    Core.IpcFacade {
        id: ipc

        catalog: catalog
        serviceRegistry: services
        surfaceRouter: surfaces
        ready: surfaces.pendingLoadCount === 0
        profileHelperPath: Quickshell.env("STILLSUIT_PROFILE_FAILURE_HELPER")
        profileRuntimeConfigPath: "/unused"
    }

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            ipc._syncProfileState()
            if (ipc.profileState !== "ready") {
                console.error("PROFILE_STATUS_FIXTURE_FAIL initial profile was not ready")
                Quickshell.exit(1)
                return
            }

            // Match loader completion ordering: readiness changes before the
            // contribution failure and its registry revision are recorded.
            surfaces.pendingLoadCount = 1
            surfaces.pendingLoadCount = 0
            surfaces.records = ({
                "stillsuit.broken": {
                    state: "error",
                    error: "panel construction returned null"
                }
            })
            surfaces.revision++
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: {
            if (ipc.profileState !== "degraded"
                    || ipc.profileError.indexOf("stillsuit.broken") === -1) {
                console.error("PROFILE_STATUS_FIXTURE_FAIL state="
                    + ipc.profileState + " error=" + ipc.profileError)
                Quickshell.exit(1)
                return
            }
            catalog.activeProfile = "default"
            if (ipc.profileActivate("work") !== "started") {
                console.error("PROFILE_STATUS_FIXTURE_FAIL failed activation did not start")
                Quickshell.exit(1)
                return
            }
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: false
        onTriggered: {
            if (ipc.profileState !== "error" || ipc.requestedProfile !== "") {
                console.error("PROFILE_STATUS_FIXTURE_FAIL failed activation state="
                    + ipc.profileState + " requested=" + ipc.requestedProfile)
                Quickshell.exit(1)
                return
            }
            console.log("PROFILE_STATUS_FIXTURE_OK")
            Qt.quit()
        }
    }
}
