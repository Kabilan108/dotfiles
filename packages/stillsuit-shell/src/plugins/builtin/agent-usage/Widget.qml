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
    readonly property bool hasCodex: _hasReportingDefault("codex")
    readonly property bool hasClaude: _hasReportingDefault("claude")
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
    label: remainingPercent >= 0 ? remainingPercent + "%" : ""
    active: context.panels.isOpen("stillsuit.agent-usage")
    accessibleName: !service || !service.available
        ? "Agent usage unavailable"
        : reportingDefaultCount === 0
            ? "No default agent accounts reporting"
            : remainingPercent >= 0
                ? "Default agent limits, lowest account has " + remainingPercent
                    + " percent remaining"
                : "Default agent usage"
    onClicked: context.actions.surfaceToggle("stillsuit.agent-usage", "")

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
