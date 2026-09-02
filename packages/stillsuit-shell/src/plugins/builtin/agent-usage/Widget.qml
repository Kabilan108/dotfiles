import QtQuick
import "../../../ui" as Ui

Ui.ShellBarCluster {
    id: root

    required property var context
    required property var service
    required property string outputId

    readonly property int usedPercent: service && service.maxUsed >= 0
        ? Math.round(service.maxUsed * 100) : -1
    readonly property int remainingPercent: usedPercent >= 0
        ? Math.max(0, 100 - usedPercent) : -1
    readonly property bool hasCodex: _hasProvider("codex")
    readonly property bool hasClaude: _hasProvider("claude")

    theme: context.theme
    iconName: "agent"
    iconSource: hasCodex
        ? Qt.resolvedUrl("assets/codex.svg")
        : hasClaude ? Qt.resolvedUrl("assets/claude.svg") : ""
    secondaryIconSource: hasCodex && hasClaude
        ? Qt.resolvedUrl("assets/claude.svg") : ""
    label: remainingPercent >= 0 ? remainingPercent + "%" : ""
    active: context.panels.isOpen("stillsuit.agent-usage")
    busy: Boolean(service && service.refreshing)
    accessibleName: !service || !service.available
        ? "Agent usage unavailable"
        : service.accountCount === 0
            ? "No agent accounts configured"
            : remainingPercent >= 0
                ? "Agent limits, lowest account has " + remainingPercent
                    + " percent remaining across " + service.accountCount + " accounts"
                : "Agent usage for " + service.accountCount + " accounts"
    onClicked: context.actions.surfaceToggle("stillsuit.agent-usage", "")

    function _hasProvider(provider) {
        var accounts = service && service.accounts ? service.accounts : []
        for (var index = 0; index < accounts.length; index++) {
            if (String(accounts[index].provider || "") === provider)
                return true
        }
        return false
    }
}
