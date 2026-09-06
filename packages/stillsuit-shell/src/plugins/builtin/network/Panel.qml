import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../ui" as Ui

Item {
    id: root
    readonly property bool hostedPanel: true
    implicitWidth: root.context.theme.metrics.panelWidth
    implicitHeight: panelContent.implicitHeight + root.context.theme.metrics.panelPadding * 2
    visible: false
    property bool opened: false

    required property var context
    required property var service
    required property var screen
    required property string outputId
    property var credentialNetwork: null
    property bool tailscaleExpanded: false

    readonly property var connectedRows: service ? service.networks.filter(function (network) {
        return network && network.connected;
    }) : []
    readonly property var availableRows: service ? service.networks.filter(function (network) {
        return network && !network.connected && !network.known;
    }) : []
    readonly property var savedRows: service ? service.networks.filter(function (network) {
        return network && !network.connected && network.known;
    }) : []
    readonly property var allowlistedVpns: service ? service.vpns.filter(function (vpn) {
        return vpn && vpn.name === "MobergAnalytics" && vpn.toggleAllowed !== false;
    }) : []
    readonly property var activeReadOnlyVpns: service ? service.vpns.filter(function (vpn) {
        return vpn && vpn.active && (vpn.name !== "MobergAnalytics" || vpn.readOnly === true);
    }) : []

    Ui.ShellSurface {
        id: panelSurface

        anchors.fill: parent

        theme: root.context.theme
        kind: "panel"

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        ColumnLayout {
            id: panelContent

            anchors.fill: parent
            anchors.margins: root.context.theme.metrics.panelPadding
            spacing: 10

            Ui.ShellPanelHeader {
                Layout.fillWidth: true
                theme: root.context.theme
                title: "Network"
                Ui.ShellButton {
                    theme: root.context.theme
                    label: ""
                    iconName: "settings"
                    compact: true
                    ghost: true
                    accessibleName: "Open network settings"
                    onClicked: root.service.openManager()
                }
            }

            ColumnLayout {
                visible: Boolean(root.service && root.service.wiredConnected)
                Layout.fillWidth: true
                spacing: 4
                Ui.ShellSectionLabel {
                    theme: root.context.theme
                    text: "Ethernet"
                }
                Repeater {
                    model: root.service ? root.service.wiredConnections : []
                    ColumnLayout {
                        id: ethernetEntry
                        required property var modelData
                        property bool expanded: false
                        Layout.fillWidth: true
                        Ui.ShellRow {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            label: ethernetEntry.modelData.name
                            description: "Connected"
                            iconName: "ethernet"
                            trailingIconName: ethernetEntry.expanded ? "expand-less" : "expand-more"
                            onClicked: ethernetEntry.expanded = !ethernetEntry.expanded
                        }
                        Ui.ShellText {
                            visible: ethernetEntry.expanded
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: ethernetEntry.modelData.device + (ethernetEntry.modelData.carrier ? " · Link " + ethernetEntry.modelData.carrier : "") + "\n" + (ethernetEntry.modelData.addresses.length ? ethernetEntry.modelData.addresses.join("\n") : "IP address unavailable")
                            sizeRole: "caption"
                            role: "secondary"
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }

            Ui.ShellToggle {
                Layout.fillWidth: true
                theme: root.context.theme
                label: "Wi-Fi"
                description: root.service && root.service.wifiEnabled ? "NetworkManager radio is enabled" : "NetworkManager radio is disabled"
                checked: Boolean(root.service && root.service.wifiEnabled)
                busy: Boolean(root.service && root.service.wifiChanging)
                interactive: Boolean(root.service && root.service.available)
                onToggled: function (requested) {
                    root.service.setWifiEnabled(requested);
                }
            }

            Ui.ShellStatus {
                Layout.fillWidth: true
                visible: root.service && root.service.lastError !== ""
                theme: root.context.theme
                status: "danger"
                iconName: "danger"
                label: root.service ? root.service.lastError : ""
                wrap: true
                maximumLines: 3
            }

            Ui.ShellStateView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.service || !root.service.available
                theme: root.context.theme
                mode: "error"
                title: "NetworkManager unavailable"
                message: "The fixed Stillsuit network helper is not configured or running."
                iconName: "wifi-off"
            }

            Flickable {
                Layout.fillWidth: true
                implicitHeight: Math.min(panelBody.implicitHeight, 430)
                visible: root.service && root.service.available
                clip: true
                contentWidth: width
                contentHeight: panelBody.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                ColumnLayout {
                    id: panelBody

                    width: parent.width
                    spacing: 6

                    GridLayout {
                        Layout.fillWidth: true
                        visible: root.service && root.service.tailscale.available
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 0

                        Ui.ShellText {
                            Layout.rowSpan: 2
                            theme: root.context.theme
                            text: "tailscale"
                            sizeRole: "label"
                        }

                        Ui.ShellAction {
                            Layout.fillWidth: true
                            implicitHeight: 16
                            accessibleName: "Copy Tailscale DNS name"
                            onActivated: root.service.copyTailscale("dns")

                            Ui.ShellText {
                                anchors.fill: parent
                                theme: root.context.theme
                                text: String(root.service.tailscale.dnsName || "")
                                sizeRole: "caption"
                                role: "muted"
                                elide: Text.ElideLeft
                                horizontalAlignment: Text.AlignRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.service.copyTailscale("dns")
                            }
                        }

                        Ui.ShellAction {
                            Layout.fillWidth: true
                            implicitHeight: 16
                            accessibleName: "Copy Tailscale IPv4 address"
                            onActivated: root.service.copyTailscale("ip")

                            Ui.ShellText {
                                anchors.fill: parent
                                theme: root.context.theme
                                text: String(root.service.tailscale.ip || "")
                                sizeRole: "caption"
                                role: "muted"
                                monospace: true
                                elide: Text.ElideLeft
                                horizontalAlignment: Text.AlignRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.service.copyTailscale("ip")
                            }
                        }
                    }

                    Ui.ShellAction {
                        Layout.fillWidth: true
                        implicitHeight: 14
                        visible: root.service && root.service.tailscale.available && root.service.tailscale.services.length > 0
                        accessibleName: root.tailscaleExpanded ? "Collapse Tailscale services" : "Expand Tailscale services"
                        onActivated: root.tailscaleExpanded = !root.tailscaleExpanded

                        Ui.ShellIcon {
                            anchors.centerIn: parent
                            theme: root.context.theme
                            name: "chevron-right"
                            sizeRole: "small"
                            role: "muted"
                            rotation: root.tailscaleExpanded ? -90 : 90
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.tailscaleExpanded && root.service.tailscale.services.length > 0
                        Layout.leftMargin: 0
                        Layout.rightMargin: 12
                        spacing: 8

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            color: root.context.theme.semantic.outline.subtle
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Repeater {
                                model: root.service.tailscale.services

                                delegate: Ui.ShellAction {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 16
                                    accessibleName: "Copy Tailscale service URL " + String(modelData)
                                    onActivated: root.service.copyTailscale("service", String(modelData))

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 0

                                        Ui.ShellText {
                                            theme: root.context.theme
                                            text: root.tailscaleServiceName(modelData)
                                            sizeRole: "caption"
                                            role: "secondary"
                                        }

                                        Ui.ShellText {
                                            Layout.fillWidth: true
                                            theme: root.context.theme
                                            text: root.tailscaleServiceSuffix(modelData)
                                            sizeRole: "caption"
                                            role: "muted"
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.service.copyTailscale("service", String(modelData))
                                    }
                                }
                            }
                        }
                    }

                    Ui.ShellSectionLabel {
                        visible: root.connectedRows.length > 0
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Connected"
                    }

                    Repeater {
                        model: root.connectedRows

                        delegate: NetworkRow {
                            required property var modelData
                            Layout.fillWidth: true
                            network: modelData
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.service && root.service.wifiEnabled

                        Ui.ShellSectionLabel {
                            Layout.fillWidth: true
                            theme: root.context.theme
                            text: "Available"
                        }

                        Ui.ShellButton {
                            theme: root.context.theme
                            label: "Scan"
                            iconName: "refresh"
                            compact: true
                            ghost: true
                            busy: Boolean(root.service && root.service.scanning)
                            accessibleName: "Scan for Wi-Fi networks"
                            onClicked: root.service.scan()
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.availableRows.length === 0
                        spacing: 8

                        Ui.ShellBusyIndicator {
                            visible: root.service && root.service.scanning
                            theme: root.context.theme
                            sizeRole: "small"
                            role: "muted"
                        }

                        Ui.ShellIcon {
                            visible: !root.service || !root.service.scanning
                            theme: root.context.theme
                            name: "wifi"
                            sizeRole: "small"
                            role: "muted"
                        }

                        Ui.ShellText {
                            theme: root.context.theme
                            text: root.service && root.service.scanning ? "Scanning" : "No available networks"
                            sizeRole: "caption"
                            role: "muted"
                        }
                    }

                    Repeater {
                        model: root.availableRows

                        delegate: NetworkRow {
                            required property var modelData
                            Layout.fillWidth: true
                            network: modelData
                        }
                    }

                    Ui.ShellSectionLabel {
                        visible: root.savedRows.length > 0
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "Saved"
                    }

                    Repeater {
                        model: root.savedRows

                        delegate: NetworkRow {
                            required property var modelData
                            Layout.fillWidth: true
                            network: modelData
                        }
                    }

                    Ui.ShellSurface {
                        visible: root.credentialNetwork !== null
                        Layout.fillWidth: true
                        implicitHeight: credentialColumn.implicitHeight + 20
                        theme: root.context.theme
                        kind: "raised"

                        ColumnLayout {
                            id: credentialColumn

                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: 10
                            }
                            spacing: 7

                            Ui.ShellText {
                                Layout.fillWidth: true
                                theme: root.context.theme
                                text: "Password for " + (root.credentialNetwork ? root.credentialNetwork.name || "network" : "network")
                                sizeRole: "label"
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 34
                                radius: root.context.theme.metrics.radiusSmall
                                color: root.context.theme.component.control.background
                                border.width: 1
                                border.color: root.context.theme.component.control.outline

                                TextInput {
                                    id: passwordInput

                                    anchors.fill: parent
                                    anchors.margins: 8
                                    color: root.context.theme.semantic.content.primary
                                    selectionColor: root.context.theme.semantic.accent.primary
                                    selectedTextColor: root.context.theme.semantic.accent.onAccent
                                    font.family: root.context.theme.typography.bodyFamily
                                    font.pixelSize: root.context.theme.typography.baseSize
                                    echoMode: TextInput.Password
                                    passwordCharacter: "•"
                                    clip: true
                                    Keys.onReturnPressed: root.submitPassword()
                                    Keys.onEnterPressed: root.submitPassword()
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignRight

                                Ui.ShellButton {
                                    theme: root.context.theme
                                    label: "Cancel"
                                    compact: true
                                    ghost: true
                                    onClicked: {
                                        passwordInput.text = "";
                                        root.credentialNetwork = null;
                                    }
                                }

                                Ui.ShellButton {
                                    theme: root.context.theme
                                    label: "Connect"
                                    iconName: "lock"
                                    compact: true
                                    active: true
                                    interactive: passwordInput.text.length > 0
                                    onClicked: root.submitPassword()
                                }
                            }
                        }
                    }

                    Ui.ShellSectionLabel {
                        visible: root.allowlistedVpns.length > 0 || root.activeReadOnlyVpns.length > 0
                        Layout.fillWidth: true
                        theme: root.context.theme
                        text: "VPN"
                    }

                    Repeater {
                        model: root.allowlistedVpns

                        delegate: Ui.ShellToggle {
                            required property var modelData
                            Layout.fillWidth: true
                            theme: root.context.theme
                            label: modelData.name
                            description: modelData.active ? "Connected" : "Disconnected"
                            checked: Boolean(modelData.active)
                            busy: root.service.operation === "vpn-toggle" && root.service.operationTarget === String(modelData.uuid || modelData.name)
                            onToggled: root.service.toggleVpn(modelData)
                        }
                    }

                    Repeater {
                        model: root.activeReadOnlyVpns

                        delegate: Ui.ShellRow {
                            required property var modelData
                            Layout.fillWidth: true
                            theme: root.context.theme
                            label: modelData.name
                            description: "Active " + String(modelData.type || "VPN") + ", managed outside Stillsuit"
                            iconName: "vpn"
                            trailingText: "read-only"
                            selected: true
                            interactive: false
                        }
                    }
                }
            }
        }
    }

    component NetworkRow: Ui.ShellRow {
        id: row

        required property var network
        readonly property string kind: root.service.networkKind(network)
        readonly property string status: root.service.statusFor(network)

        theme: root.context.theme
        label: String(network.name || "Unnamed network")
        description: row.status === "joining" ? "Joining with NetworkManager" : row.status === "disconnecting" ? "Disconnecting with NetworkManager" : row.kind === "enterprise" ? "Enterprise Wi-Fi, opens NetworkManager editor" : row.network.connected ? root.service.signalPercentage(network) + "% signal" : row.network.known ? "Saved network" : row.kind === "open" ? "Open network" : "Personal secured network"
        iconName: row.kind === "open" ? "wifi" : "lock"
        trailingText: row.status
        selected: Boolean(network.connected)
        busy: row.status === "joining" || row.status === "disconnecting"
        interactive: root.service.operation === "idle"
        accessibleName: label + ", " + description
        onClicked: {
            if (row.kind === "personal" && !row.network.known && !row.network.connected) {
                root.credentialNetwork = row.network;
                passwordInput.forceActiveFocus();
            } else {
                root.service.activate(row.network, "");
            }
        }
    }

    function submitPassword() {
        if (!credentialNetwork || passwordInput.text.length === 0)
            return;
        var password = passwordInput.text;
        passwordInput.text = "";
        var network = credentialNetwork;
        credentialNetwork = null;
        service.activate(network, password);
        password = "";
    }

    function tailscaleServiceName(serviceName) {
        var value = String(serviceName || "");
        var separator = value.indexOf(".");
        return separator === -1 ? value : value.slice(0, separator);
    }

    function tailscaleServiceSuffix(serviceName) {
        var value = String(serviceName || "");
        var separator = value.indexOf(".");
        return separator === -1 ? "" : value.slice(separator);
    }

    function open(payloadJson) {
        root.opened = true;
        if (service)
            service.refresh();
    }

    function close() {
        passwordInput.text = "";
        credentialNetwork = null;
        root.opened = false;
    }
}
