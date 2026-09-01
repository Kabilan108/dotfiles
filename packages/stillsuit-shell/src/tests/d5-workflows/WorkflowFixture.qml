import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/builtin/workflows" as Workflows
import "plugins/builtin/osd" as Osd
import "plugins/builtin/recording" as Recording
import "plugins/builtin/meeting" as Meeting

ShellRoot {
    id: fixture

    QtObject {
        id: fixtureContext
        property var settings: ({ values: {
            recorderHelperPath: Quickshell.env("STILLSUIT_FIXTURE_HELPER"),
            recordingStatePath: Quickshell.env("STILLSUIT_FIXTURE_RECORDING_STATE"),
            recordingDirectory: "/tmp/fixture-recordings",
            recordingDefaultTitle: "fixture-default-title",
            desktopAudioDefault: true,
            microphoneDefault: false,
            meetingStatusPath: Quickshell.env("STILLSUIT_FIXTURE_MEETING_STATE"),
            meetingJobsPath: Quickshell.env("STILLSUIT_FIXTURE_MEETING_JOBS"),
            meetingHelperPath: Quickshell.env("STILLSUIT_FIXTURE_MEETING_HELPER"),
            openHelperPath: Quickshell.env("STILLSUIT_FIXTURE_OPEN_HELPER"),
            dictatorSocketPath: Quickshell.env("STILLSUIT_FIXTURE_SOCKET")
        } })
        property var compositor: ({ focusedOutputId: "DP-1" })
        property var theme: ({ motion: { slow: 260 } })
    }

    Workflows.Service { id: workflows; context: fixtureContext }
    Osd.Service { id: osdService; context: fixtureContext }
    Recording.CompletionCountdown {
        id: completionCountdown
        property int expirationCount: 0
        onExpired: expirationCount += 1
    }
    Meeting.MeetingQueueModel {
        id: meetingQueue
        jobs: workflows.meeting.jobs
    }

    // Two output views consume one global aggregate. Production OsdOverlay
    // instances use context.services.get() with the same identity.
    property var overlayViews: [
        { outputId: "fixture-a", workflows: workflows, service: osdService },
        { outputId: "fixture-b", workflows: workflows, service: osdService }
    ]

    IpcHandler {
        target: "stillsuit-d5-fixture"
        function state(): string {
            return JSON.stringify({
                aggregateApiVersion: workflows.apiVersion,
                serviceObjects: 1,
                osdServiceObjects: 1,
                overlays: overlayViews.length,
                overlaySharesAggregate: overlayViews[0].workflows === overlayViews[1].workflows,
                overlaySharesOsdService: overlayViews[0].service === overlayViews[1].service,
                recording: { apiVersion: workflows.recording.apiVersion, phase: workflows.recording.phase, status: workflows.recording.stateStatus, active: workflows.recording.active, paused: workflows.recording.paused, elapsedSeconds: workflows.recording.elapsedSeconds, elapsedText: workflows.recording.elapsedText, completed: workflows.recording.completed, outputPath: workflows.recording.outputPath, outputFilename: workflows.recording.outputFilename, copiedPath: workflows.recording.copiedPath, errorMessage: workflows.recording.errorMessage, actionRunning: workflows.recording.actionRunning, command: workflows.recording.lastCommandJson },
                meeting: { apiVersion: workflows.meeting.apiVersion, phase: workflows.meeting.phase, status: workflows.meeting.stateStatus, jobsStatus: workflows.meeting.jobsStateStatus, visible: workflows.meeting.visible, failed: workflows.meeting.failed, completed: workflows.meeting.completed, label: workflows.meeting.label, errorMessage: workflows.meeting.errorMessage, snapshotSchemaVersion: workflows.meeting.snapshot.schemaVersion, command: workflows.meeting.lastCommandJson, retryingJobId: workflows.meeting.retryingJobId, jobs: workflows.meeting.jobs },
                queue: { page: meetingQueue.page, pageCount: meetingQueue.pageCount, actionableCount: meetingQueue.actionableCount, olderActionableCount: meetingQueue.olderActionableCount, jobs: meetingQueue.pageJobs },
                completion: { remainingMs: completionCountdown.remainingMs, remainingSeconds: completionCountdown.remainingSeconds, running: completionCountdown.running, interactionActive: completionCountdown.interactionActive, expirationCount: completionCountdown.expirationCount },
                dictator: { apiVersion: workflows.dictator.apiVersion, state: workflows.dictator.visualizerState, socketConnections: workflows.dictator.socketConnections, levels: workflows.dictator.levels.length }
            })
        }
        function refresh(): string { workflows.recording.refresh(); workflows.meeting.refresh(); return "ok" }
        function start(): string { return workflows.recording.start("/tmp/fixture-recordings", "DP-1", "fixture-title", true, false) }
        function d4Start(): string { return workflows.recording.start() }
        function d4Finish(): string { return workflows.recording.finish() }
        function pause(): string { return workflows.recording.togglePause() }
        function finishMeeting(): string { return workflows.recording.stopAsMeeting() }
        function cancel(): string { return workflows.recording.cancel() }
        function rename(title: string): string { return workflows.recording.rename(title) }
        function copyPath(): string { return workflows.recording.copyOutputPath() }
        function openRecording(): string { return workflows.recording.openRecording() }
        function openFolder(): string { return workflows.recording.openFolder() }
        function openResult(): string { return workflows.meeting.openResult() }
        function openJob(jobId: string): string { return workflows.meeting.openResult(jobId) }
        function retry(jobId: string): string { return workflows.meeting.retry(jobId) }
        function doubleRetry(jobId: string): string { return JSON.stringify([workflows.meeting.retry(jobId), workflows.meeting.retry(jobId)]) }
        function nextPage(): string { return meetingQueue.nextPage() ? "ok" : "end" }
        function previousPage(): string { return meetingQueue.previousPage() ? "ok" : "start" }
        function completionStart(): string { completionCountdown.start(); return "ok" }
        function completionInteract(active: bool): string { completionCountdown.interactionActive = active; return "ok" }
        function completionTick(milliseconds: int): string { return completionCountdown.tick(milliseconds) ? "expired" : "waiting" }
    }
}
