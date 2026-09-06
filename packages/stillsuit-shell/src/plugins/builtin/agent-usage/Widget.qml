import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property real defaultMaxUsed: _defaultMaxUsed()
    readonly property int usedPercent: defaultMaxUsed >= 0
        ? Math.round(defaultMaxUsed * 100) : -1
    readonly property int remainingPercent: usedPercent >= 0
        ? Math.max(0, 100 - usedPercent) : -1
    readonly property bool hasCodex: codexRemaining >= 0
    readonly property bool hasClaude: claudeRemaining >= 0
    readonly property int reportingDefaultCount:
        (hasCodex ? 1 : 0) + (hasClaude ? 1 : 0)

    theme: context.theme
    visible: reportingDefaultCount > 0
    iconName: "agent"
    iconSource: hasCodex
        ? Qt.resolvedUrl("assets/codex.svg")
        : hasClaude ? Qt.resolvedUrl("assets/claude.svg") : ""
    secondaryIconSource: hasCodex && hasClaude
        ? Qt.resolvedUrl("assets/claude.svg") : ""
    readonly property int codexRemaining: _remaining("codex")
    readonly property int claudeRemaining: _remaining("claude")
    label: hasCodex ? codexRemaining + "%" : hasClaude ? claudeRemaining + "%" : ""
    secondaryLabel: hasCodex && hasClaude ? claudeRemaining + "%" : ""
    selected: context.panels && context.panels.selectedId === "stillsuit.agent-usage"
        && context.panels.selectedOutputId === outputId
    accessibleName: !service || !service.available
        ? "Agent usage unavailable"
        : reportingDefaultCount === 0
            ? "No default agent accounts reporting"
            : (hasCodex ? "Codex " + codexRemaining + "% remaining" : "")
                + (hasCodex && hasClaude ? "; " : "")
                + (hasClaude ? "Claude " + claudeRemaining + "% remaining" : "")
    onClicked: context.actions.surfaceToggle("stillsuit.agent-usage", JSON.stringify({outputId: root.outputId}))

    function _isReportingDefault(account) {
        return account && String(account.source || "") === "default"
            && String(account.status || "") === "ready"
            && account.windows && account.windows.length > 0
    }

    function _hasReportingDefault(provider) {
        var accounts = service && service.accounts ? service.accounts : []
        for (var index = 0; index < accounts.length; index++) {
            if (_isReportingDefault(accounts[index])
                    && String(accounts[index].provider || "") === provider)
                return true
        }
        return false
    }

    function _remaining(provider) {
        var accounts = service && service.accounts ? service.accounts : []
        var maximum = -1
        for (var index = 0; index < accounts.length; index++) {
            var account = accounts[index]
            if (!_isReportingDefault(account) || account.provider !== provider)
                continue
            for (var windowIndex = 0; windowIndex < account.windows.length; windowIndex++) {
                var used = Number(account.windows[windowIndex].used)
                if (isFinite(used))
                    maximum = Math.max(maximum, Math.max(0, Math.min(1, used)))
            }
        }
        return maximum < 0 ? -1 : 100 - Math.round(maximum * 100)
    }

    function _defaultMaxUsed() {
        var accounts = service && service.accounts ? service.accounts : []
        var maximum = -1
        for (var accountIndex = 0; accountIndex < accounts.length; accountIndex++) {
            var account = accounts[accountIndex]
            if (!_isReportingDefault(account))
                continue
            for (var windowIndex = 0; windowIndex < account.windows.length;
                    windowIndex++) {
                var used = Number(account.windows[windowIndex].used)
                if (isFinite(used))
                    maximum = Math.max(maximum, Math.max(0, Math.min(1, used)))
            }
        }
        return maximum
    }
}
