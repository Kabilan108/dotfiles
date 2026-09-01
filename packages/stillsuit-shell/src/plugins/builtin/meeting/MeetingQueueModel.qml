import QtQuick

QtObject {
    id: root

    readonly property int pageSize: 5
    property var jobs: []
    property int page: 0
    readonly property var rankedJobs: _rank(jobs)
    readonly property int pageCount: Math.max(1, Math.ceil(rankedJobs.length / pageSize))
    readonly property var pageJobs: rankedJobs.slice(page * pageSize, (page + 1) * pageSize)
    readonly property int actionableCount: rankedJobs.filter(function(job) { return _actionable(job.phase) }).length
    readonly property int olderActionableCount: Math.max(0, actionableCount - (page + 1) * pageSize)
    readonly property bool hasPreviousPage: page > 0
    readonly property bool hasNextPage: page + 1 < pageCount

    onPageCountChanged: if (page >= pageCount) page = pageCount - 1

    function setJobs(value) {
        jobs = Array.isArray(value) ? value.slice() : []
        page = Math.min(page, pageCount - 1)
    }

    function nextPage() {
        if (!hasNextPage)
            return false
        page += 1
        return true
    }

    function previousPage() {
        if (!hasPreviousPage)
            return false
        page -= 1
        return true
    }

    function _processing(phase) {
        return ["preparing", "chunking", "transcribing", "diarizing", "aligning",
            "generating", "enriching", "writing"].indexOf(String(phase || "")) !== -1
    }

    function _actionable(phase) {
        var value = String(phase || "")
        return value === "staging" || value === "queued" || value === "error" || _processing(value)
    }

    function _phaseRank(phase) {
        var value = String(phase || "")
        if (value === "staging" || value === "queued") return 0
        if (_processing(value)) return 1
        if (value === "error") return 2
        return 3
    }

    function _time(job) {
        return String(job.phase || "") === "completed"
            ? Number(job.completedAt || job.updatedAt || 0)
            : Number(job.updatedAt || job.createdAt || 0)
    }

    function _rank(value) {
        var rows = Array.isArray(value) ? value.slice() : []
        rows.sort(function(left, right) {
            var phaseDifference = _phaseRank(left.phase) - _phaseRank(right.phase)
            if (phaseDifference !== 0)
                return phaseDifference
            var timeDifference = _time(right) - _time(left)
            if (timeDifference !== 0)
                return timeDifference
            return String(left.jobId || "").localeCompare(String(right.jobId || ""))
        })
        return rows
    }
}
