import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "ui" as Ui
import "design_lab" as Lab

ShellRoot {
    id: lab

    readonly property string labRoot: Quickshell.env("STILLSUIT_LAB_ROOT") || Quickshell.shellDir
    readonly property var themeChoices: [
        { label: "Stillsuit Spice", file: "stillsuit-spice.json" },
        { label: "Catppuccin", file: "catppuccin-mocha.json" },
        { label: "Graphite Cyan", file: "graphite-cyan.json" }
    ]
    readonly property var bodyFontChoices: ["Inter", "IBM Plex Sans", "Noto Sans", "JetBrainsMono Nerd Font"]
    readonly property var monoFontChoices: ["JetBrainsMono Nerd Font", "FiraMono Nerd Font", "IBM Plex Mono"]
    readonly property var iconFontChoices: ["Material Symbols Rounded", "Material Symbols Outlined"]
    readonly property var barHeightChoices: [26, 28, 30, 32]
    readonly property var reviewPreset: ({
        bodyFont: "Noto Sans",
        monoFont: "JetBrainsMono Nerd Font",
        iconFont: "Material Symbols Rounded",
        barHeight: 26,
        anchored: true,
        opacity: 0.85,
        radius: 4,
        motionScale: 0.55,
        accent: "#89b4fa",
        panel: "#181825",
        raised: "#313244",
        osd: "#1e1e2e",
        text: "#cdd6f4"
    })

    property bool ready: false
    property string errorText: ""
    property int selectedThemeIndex: 0
    property var baseTheme: ({})
    property var theme: ({})
    property string bodyFontChoice: "Inter"
    property string monoFontChoice: "JetBrainsMono Nerd Font"
    property string iconFontChoice: "Material Symbols Rounded"
    property int barHeightChoice: 30
    property bool anchoredChoice: true
    property real opacityChoice: 0.92
    property real radiusChoice: 9
    property real motionScaleChoice: 1
    property bool reducedMotionChoice: false
    property string accentChoice: "#d98952"
    property string panelChoice: "#181c24"
    property string raisedChoice: "#242a36"
    property string osdChoice: "#1b1f29"
    property string textChoice: "#e6ded0"

    FileView {
        id: spiceTheme
        path: lab.labRoot + "/themes/stillsuit-spice.json"
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: catppuccinTheme
        path: lab.labRoot + "/themes/catppuccin-mocha.json"
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: graphiteTheme
        path: lab.labRoot + "/themes/graphite-cyan.json"
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    IpcHandler {
        target: "stillsuit-design-lab"

        function selectTheme(index: int): string {
            lab.chooseTheme(index)
            return lab.ready ? lab.theme.identity.id : lab.errorText
        }

        function restoreReviewPreset(): string {
            lab.chooseReviewPreset()
            return lab.ready ? lab.theme.identity.id : lab.errorText
        }

        function selectNetworkState(index: int): string {
            if (!contentLoader.item)
                return "lab content is not ready"
            contentLoader.item.networkStateIndex = index
            return String(contentLoader.item.networkStateIndex)
        }

        function selectNotificationState(index: int): string {
            if (!contentLoader.item)
                return "lab content is not ready"
            contentLoader.item.notificationStateIndex = index
            return String(contentLoader.item.notificationStateIndex)
        }

        function status(): string {
            return JSON.stringify({
                ready: lab.ready,
                error: lab.errorText,
                theme: lab.ready ? lab.theme.identity.id : "",
                bodyFont: lab.bodyFontChoice,
                monoFont: lab.monoFontChoice,
                iconFont: lab.iconFontChoice,
                barHeight: lab.barHeightChoice,
                anchored: lab.anchoredChoice,
                opacity: lab.opacityChoice,
                radius: lab.radiusChoice,
                motionScale: lab.motionScaleChoice,
                osd: lab.osdChoice,
                windowSize: [window.width, window.height],
                loaderSize: [contentLoader.width, contentLoader.height],
                loaderStatus: contentLoader.status,
                itemSize: contentLoader.item ? [contentLoader.item.width, contentLoader.item.height] : []
            })
        }
    }

    Component.onCompleted: chooseReviewPreset()

    function _viewFor(index) {
        if (index === 1)
            return catppuccinTheme
        if (index === 2)
            return graphiteTheme
        return spiceTheme
    }

    function chooseTheme(index) {
        try {
            var parsed = JSON.parse(_viewFor(index).text())
            if (!parsed || parsed.schemaVersion !== 2)
                throw new Error("theme does not satisfy the design-lab v2 draft")
            selectedThemeIndex = index
            baseTheme = parsed
            bodyFontChoice = parsed.typography.bodyFamily
            monoFontChoice = parsed.typography.monoFamily
            iconFontChoice = parsed.typography.iconFamily
            barHeightChoice = parsed.metrics.barHeight
            anchoredChoice = parsed.metrics.barOuterGap === 0
            opacityChoice = parsed.effects.surfaceOpacity
            radiusChoice = parsed.metrics.radiusMedium
            motionScaleChoice = 1
            reducedMotionChoice = false
            accentChoice = parsed.semantic.accent.primary
            panelChoice = parsed.semantic.surface.panel
            raisedChoice = parsed.semantic.surface.raised
            osdChoice = parsed.component.osd.background
            textChoice = parsed.semantic.content.primary
            errorText = ""
            rebuildTheme()
            ready = true
        } catch (error) {
            errorText = String(error)
            ready = false
        }
    }

    function chooseReviewPreset() {
        chooseTheme(1)
        bodyFontChoice = reviewPreset.bodyFont
        monoFontChoice = reviewPreset.monoFont
        iconFontChoice = reviewPreset.iconFont
        barHeightChoice = reviewPreset.barHeight
        anchoredChoice = reviewPreset.anchored
        opacityChoice = reviewPreset.opacity
        radiusChoice = reviewPreset.radius
        motionScaleChoice = reviewPreset.motionScale
        reducedMotionChoice = false
        accentChoice = reviewPreset.accent
        panelChoice = reviewPreset.panel
        raisedChoice = reviewPreset.raised
        osdChoice = reviewPreset.osd
        textChoice = reviewPreset.text
        rebuildTheme()
    }

    function rebuildTheme() {
        if (!baseTheme || !baseTheme.identity)
            return

        var next = JSON.parse(JSON.stringify(baseTheme))
        next.typography.bodyFamily = bodyFontChoice
        next.typography.monoFamily = monoFontChoice
        next.typography.iconFamily = iconFontChoice
        next.metrics.barHeight = barHeightChoice
        next.metrics.barOuterGap = anchoredChoice ? 0 : 8
        next.metrics.radiusMedium = radiusChoice
        next.metrics.radiusLarge = Math.max(radiusChoice, radiusChoice + 4)
        next.effects.surfaceOpacity = opacityChoice

        var scale = reducedMotionChoice ? 0 : motionScaleChoice
        next.motion.fast = Math.round(baseTheme.motion.fast * scale)
        next.motion.normal = Math.round(baseTheme.motion.normal * scale)
        next.motion.slow = Math.round(baseTheme.motion.slow * scale)

        next.semantic.accent.primary = accentChoice
        next.semantic.outline.focus = accentChoice
        next.component.bar.workspaceActive = accentChoice
        next.component.control.active = accentChoice
        next.component.control.focus = accentChoice
        next.component.notification.unread = accentChoice
        next.component.osd.fill = accentChoice

        next.semantic.surface.panel = panelChoice
        next.component.panel.background = panelChoice
        next.component.notification.background = panelChoice
        next.component.osd.background = osdChoice

        next.semantic.surface.raised = raisedChoice
        next.component.panel.section = raisedChoice
        next.component.control.background = raisedChoice

        next.semantic.content.primary = textChoice
        next.component.control.text = textChoice
        next.component.bar.clusterActiveText = textChoice
        next.component.osd.text = textChoice

        theme = next
    }

    function applyColor(kind, value) {
        if (!/^#[0-9a-fA-F]{6}$/.test(value))
            return false
        if (kind === "accent")
            accentChoice = value
        else if (kind === "panel")
            panelChoice = value
        else if (kind === "raised")
            raisedChoice = value
        else if (kind === "osd")
            osdChoice = value
        else if (kind === "text")
            textChoice = value
        else
            return false
        rebuildTheme()
        return true
    }

    component SectionHeading: ColumnLayout {
        required property var theme
        property string title: "Section"
        property string detail: ""
        spacing: 2

        Ui.ShellText {
            theme: parent.theme
            text: parent.title
            sizeRole: "heading"
        }

        Ui.ShellText {
            visible: parent.detail !== ""
            Layout.fillWidth: true
            theme: parent.theme
            text: parent.detail
            role: "muted"
            sizeRole: "caption"
            wrapMode: Text.Wrap
        }
    }

    component ColorEditor: ColumnLayout {
        id: colorEditor

        required property var theme
        property string label: "Token"
        property string value: "#ffffff"
        property string tokenKind: "accent"
        spacing: 3

        Ui.ShellText {
            theme: colorEditor.theme
            text: colorEditor.label
            sizeRole: "caption"
            role: "secondary"
        }

        TextField {
            id: field
            Layout.fillWidth: true
            text: colorEditor.value
            color: colorEditor.theme.semantic.content.primary
            selectionColor: colorEditor.theme.semantic.accent.primary
            selectedTextColor: colorEditor.theme.semantic.accent.onAccent
            font.family: colorEditor.theme.typography.monoFamily
            font.pixelSize: colorEditor.theme.typography.captionSize
            leftPadding: 10
            rightPadding: 10
            onEditingFinished: {
                if (!lab.applyColor(colorEditor.tokenKind, text))
                    text = colorEditor.value
            }
            background: Rectangle {
                radius: colorEditor.theme.metrics.radiusSmall
                color: colorEditor.theme.component.control.background
                border.width: field.activeFocus ? 2 : 1
                border.color: field.activeFocus
                    ? colorEditor.theme.component.control.focus
                    : colorEditor.theme.component.control.outline
            }
        }
    }

    FloatingWindow {
        id: window
        visible: true
        title: "Stillsuit design lab"
        color: "#0b0c0f"
        implicitWidth: 1500
        implicitHeight: 940
        minimumSize: Qt.size(1120, 720)

        Loader {
            id: contentLoader

            anchors.fill: parent
            active: lab.ready
            sourceComponent: labContent
        }

        Ui.ShellText {
            anchors.centerIn: parent
            visible: !lab.ready
            theme: ({
                typography: {
                    bodyFamily: "Noto Sans",
                    monoFamily: "FiraMono Nerd Font",
                    baseSize: 13,
                    captionSize: 11,
                    headingSize: 17,
                    weightRegular: 400,
                    weightMedium: 500,
                    weightBold: 700
                },
                semantic: { content: { primary: "#ffffff" } }
            })
            text: lab.errorText === "" ? "Loading design lab…" : lab.errorText
        }
    }

    Component {
        id: labContent

        Rectangle {
            property alias networkStateIndex: networkPreview.previewStateIndex
            property alias notificationStateIndex: notificationPreview.stateIndex

            color: lab.theme.semantic.background.canvas

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.preferredWidth: 350
                    Layout.fillHeight: true
                    color: lab.theme.semantic.surface.overlay
                    border.width: 0

                    ScrollView {
                        id: controlsScroll
                        anchors.fill: parent
                        anchors.margins: 18
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            width: controlsScroll.availableWidth
                            spacing: 18

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Ui.ShellText {
                                    theme: lab.theme
                                    text: "STILLSUIT DESIGN LAB"
                                    sizeRole: "caption"
                                    monospace: true
                                    color: lab.theme.semantic.accent.primary
                                }

                                Ui.ShellText {
                                    theme: lab.theme
                                    text: "Tune the system before it reaches production."
                                    role: "secondary"
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                }
                            }

                            SectionHeading {
                                theme: lab.theme
                                title: "Theme"
                                detail: "Raw palette → semantic meaning → component assignment."
                            }

                            Flow {
                                Layout.fillWidth: true
                                width: parent.width
                                spacing: 7

                                Repeater {
                                    model: lab.themeChoices

                                    Ui.ShellButton {
                                        required property var modelData
                                        required property int index
                                        theme: lab.theme
                                        label: modelData.label
                                        compact: true
                                        active: index === lab.selectedThemeIndex
                                        onClicked: lab.chooseTheme(index)
                                    }
                                }
                            }

                            Ui.ShellButton {
                                theme: lab.theme
                                label: "Restore your saved pick"
                                iconName: "check"
                                ghost: true
                                onClicked: lab.chooseReviewPreset()
                            }

                            SectionHeading {
                                theme: lab.theme
                                title: "Typography"
                                detail: "Omarchy uses JetBrainsMono Nerd Font system-wide. Stillsuit can split body and telemetry type."
                            }

                            Ui.ShellText {
                                theme: lab.theme
                                text: "BODY"
                                sizeRole: "caption"
                                role: "muted"
                                monospace: true
                            }

                            Flow {
                                Layout.fillWidth: true
                                width: parent.width
                                spacing: 7

                                Repeater {
                                    model: lab.bodyFontChoices

                                    Ui.ShellButton {
                                        required property var modelData
                                        theme: lab.theme
                                        label: String(modelData)
                                        compact: true
                                        active: String(modelData) === lab.bodyFontChoice
                                        onClicked: {
                                            lab.bodyFontChoice = String(modelData)
                                            lab.rebuildTheme()
                                        }
                                    }
                                }
                            }

                            Ui.ShellText {
                                theme: lab.theme
                                text: "MONOSPACE"
                                sizeRole: "caption"
                                role: "muted"
                                monospace: true
                            }

                            Flow {
                                Layout.fillWidth: true
                                width: parent.width
                                spacing: 7

                                Repeater {
                                    model: lab.monoFontChoices

                                    Ui.ShellButton {
                                        required property var modelData
                                        theme: lab.theme
                                        label: String(modelData)
                                        compact: true
                                        active: String(modelData) === lab.monoFontChoice
                                        onClicked: {
                                            lab.monoFontChoice = String(modelData)
                                            lab.rebuildTheme()
                                        }
                                    }
                                }
                            }

                            Ui.ShellText {
                                theme: lab.theme
                                text: "ICONS"
                                sizeRole: "caption"
                                role: "muted"
                                monospace: true
                            }

                            Flow {
                                Layout.fillWidth: true
                                width: parent.width
                                spacing: 7

                                Repeater {
                                    model: lab.iconFontChoices

                                    Ui.ShellButton {
                                        required property var modelData
                                        theme: lab.theme
                                        label: String(modelData).replace("Material Symbols ", "")
                                        compact: true
                                        active: String(modelData) === lab.iconFontChoice
                                        onClicked: {
                                            lab.iconFontChoice = String(modelData)
                                            lab.rebuildTheme()
                                        }
                                    }
                                }
                            }

                            SectionHeading {
                                theme: lab.theme
                                title: "Bar"
                                detail: "Inline workspaces are fixed. Compare height and edge treatment."
                            }

                            Flow {
                                Layout.fillWidth: true
                                width: parent.width
                                spacing: 7

                                Repeater {
                                    model: lab.barHeightChoices

                                    Ui.ShellButton {
                                        required property var modelData
                                        theme: lab.theme
                                        label: String(modelData) + " px"
                                        compact: true
                                        active: Number(modelData) === lab.barHeightChoice
                                        onClicked: {
                                            lab.barHeightChoice = Number(modelData)
                                            lab.rebuildTheme()
                                        }
                                    }
                                }
                            }

                            Ui.ShellToggle {
                                Layout.fillWidth: true
                                theme: lab.theme
                                label: "Anchored to top"
                                description: "Zero outer gap; bar spans the output edge."
                                checked: lab.anchoredChoice
                                onToggled: checked => {
                                    lab.anchoredChoice = checked
                                    lab.rebuildTheme()
                                }
                            }

                            SectionHeading {
                                theme: lab.theme
                                title: "Surfaces"
                                detail: "These values update every real lab component."
                            }

                            Ui.ShellSlider {
                                Layout.fillWidth: true
                                theme: lab.theme
                                label: "Panel opacity"
                                from: 0.7
                                to: 1
                                value: lab.opacityChoice
                                decimals: 2
                                onMoved: value => {
                                    lab.opacityChoice = value
                                    lab.rebuildTheme()
                                }
                            }

                            Ui.ShellSlider {
                                Layout.fillWidth: true
                                theme: lab.theme
                                label: "Medium radius"
                                from: 0
                                to: 16
                                value: lab.radiusChoice
                                decimals: 0
                                suffix: " px"
                                onMoved: value => {
                                    lab.radiusChoice = Math.round(value)
                                    lab.rebuildTheme()
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 8
                                rowSpacing: 8

                                ColorEditor {
                                    Layout.fillWidth: true
                                    theme: lab.theme
                                    label: "Accent"
                                    value: lab.accentChoice
                                    tokenKind: "accent"
                                }

                                ColorEditor {
                                    Layout.fillWidth: true
                                    theme: lab.theme
                                    label: "Panel"
                                    value: lab.panelChoice
                                    tokenKind: "panel"
                                }

                                ColorEditor {
                                    Layout.fillWidth: true
                                    theme: lab.theme
                                    label: "Control / section"
                                    value: lab.raisedChoice
                                    tokenKind: "raised"
                                }

                                ColorEditor {
                                    Layout.fillWidth: true
                                    theme: lab.theme
                                    label: "OSD"
                                    value: lab.osdChoice
                                    tokenKind: "osd"
                                }

                                ColorEditor {
                                    Layout.fillWidth: true
                                    theme: lab.theme
                                    label: "Primary text"
                                    value: lab.textChoice
                                    tokenKind: "text"
                                }
                            }

                            SectionHeading {
                                theme: lab.theme
                                title: "Motion"
                                detail: "Use the replay card in the preview while changing speed."
                            }

                            Ui.ShellSlider {
                                Layout.fillWidth: true
                                theme: lab.theme
                                label: "Speed scale"
                                from: 0.5
                                to: 1.5
                                value: lab.motionScaleChoice
                                decimals: 2
                                suffix: "×"
                                onMoved: value => {
                                    lab.motionScaleChoice = value
                                    lab.rebuildTheme()
                                }
                            }

                            Ui.ShellToggle {
                                Layout.fillWidth: true
                                theme: lab.theme
                                label: "Reduced motion"
                                description: "Transforms and fades resolve immediately."
                                checked: lab.reducedMotionChoice
                                onToggled: checked => {
                                    lab.reducedMotionChoice = checked
                                    lab.rebuildTheme()
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Ui.ShellButton {
                                    theme: lab.theme
                                    label: "Theme defaults"
                                    iconName: "refresh"
                                    onClicked: lab.chooseTheme(lab.selectedThemeIndex)
                                }

                                Ui.ShellButton {
                                    theme: lab.theme
                                    label: "Your pick"
                                    iconName: "check"
                                    active: true
                                    onClicked: lab.chooseReviewPreset()
                                }
                            }

                            Item {
                                Layout.preferredHeight: 12
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: lab.theme.semantic.outline.subtle
                }

                ScrollView {
                    id: previewScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: Math.max(760, previewScroll.availableWidth)
                        spacing: 26

                        Item {
                            Layout.preferredHeight: 1
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 28
                            Layout.rightMargin: 28

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Ui.ShellText {
                                    theme: lab.theme
                                    text: lab.theme.identity.name
                                    sizeRole: "heading"
                                }

                                Ui.ShellText {
                                    Layout.fillWidth: true
                                    theme: lab.theme
                                    text: lab.theme.identity.description
                                    role: "secondary"
                                    wrapMode: Text.Wrap
                                }
                            }

                            Ui.ShellText {
                                theme: lab.theme
                                text: lab.bodyFontChoice + "  +  " + lab.monoFontChoice
                                sizeRole: "caption"
                                role: "muted"
                                monospace: true
                            }
                        }

                        SectionHeading {
                            Layout.fillWidth: true
                            Layout.leftMargin: 28
                            Layout.rightMargin: 28
                            theme: lab.theme
                            title: "Bar"
                            detail: "Same inline workspace and icon-led clusters at two output proportions."
                        }

                        Lab.BarPreview {
                            Layout.fillWidth: true
                            Layout.leftMargin: 28
                            Layout.rightMargin: 28
                            theme: lab.theme
                            anchored: lab.anchoredChoice
                            label: "DP-4 · 3440 × 1440"
                        }

                        Lab.BarPreview {
                            Layout.preferredWidth: Math.min(760, previewScroll.availableWidth - 56)
                            Layout.leftMargin: 28
                            theme: lab.theme
                            anchored: lab.anchoredChoice
                            label: "eDP-1 · 2256 × 1504"
                        }

                        SectionHeading {
                            Layout.fillWidth: true
                            Layout.leftMargin: 28
                            Layout.rightMargin: 28
                            theme: lab.theme
                            title: "Typography and icons"
                            detail: "Body copy uses the selected sans. Metrics and identifiers use the selected monospace face."
                        }

                        Ui.ShellSurface {
                            Layout.fillWidth: true
                            Layout.leftMargin: 28
                            Layout.rightMargin: 28
                            Layout.preferredHeight: typeColumn.implicitHeight + 32
                            theme: lab.theme
                            kind: "raised"

                            ColumnLayout {
                                id: typeColumn
                                anchors {
                                    fill: parent
                                    margins: 16
                                }
                                spacing: 8

                                Ui.ShellText {
                                    theme: lab.theme
                                    text: "A shell should say enough, then get out of the way."
                                    sizeRole: "heading"
                                }

                                Ui.ShellText {
                                    Layout.fillWidth: true
                                    theme: lab.theme
                                    text: "Longer labels and notification bodies use the body family. The rhythm should remain calm at compact desktop sizes."
                                    role: "secondary"
                                    wrapMode: Text.Wrap
                                }

                                Ui.ShellText {
                                    theme: lab.theme
                                    text: "CPU 18%   MEM 42%   22:14:08   workspace=2 column=3"
                                    monospace: true
                                    color: lab.theme.semantic.accent.primary
                                }

                                RowLayout {
                                    spacing: 16

                                    Repeater {
                                        model: ["network", "bluetooth", "audio", "microphone", "notifications", "battery", "brightness", "settings"]

                                        Ui.ShellIcon {
                                            required property var modelData
                                            theme: lab.theme
                                            name: String(modelData)
                                            sizeRole: "large"
                                        }
                                    }
                                }
                            }
                        }

                        SectionHeading {
                            Layout.fillWidth: true
                            Layout.leftMargin: 28
                            Layout.rightMargin: 28
                            theme: lab.theme
                            title: "Token map"
                            detail: "Shared components consume these assigned roles. Plugin QML should never read the raw palette."
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 28
                            Layout.rightMargin: 28
                            columns: Math.max(2, Math.floor((previewScroll.availableWidth - 56) / 190))
                            columnSpacing: 8
                            rowSpacing: 8

                            Repeater {
                                model: [
                                    { name: "accent.primary", value: lab.theme.semantic.accent.primary },
                                    { name: "surface.panel", value: lab.theme.semantic.surface.panel },
                                    { name: "surface.raised", value: lab.theme.semantic.surface.raised },
                                    { name: "osd.background", value: lab.theme.component.osd.background },
                                    { name: "content.primary", value: lab.theme.semantic.content.primary },
                                    { name: "content.secondary", value: lab.theme.semantic.content.secondary },
                                    { name: "outline.default", value: lab.theme.semantic.outline.default },
                                    { name: "status.success", value: lab.theme.semantic.status.success },
                                    { name: "status.warning", value: lab.theme.semantic.status.warning },
                                    { name: "status.danger", value: lab.theme.semantic.status.danger },
                                    { name: "notification.unread", value: lab.theme.component.notification.unread },
                                    { name: "notification.muted", value: lab.theme.component.notification.muted },
                                    { name: "signal.audio", value: lab.theme.semantic.signal.audio },
                                    { name: "signal.brightness", value: lab.theme.semantic.signal.brightness },
                                    { name: "signal.recording", value: lab.theme.semantic.signal.recording }
                                ]

                                Lab.TokenSwatch {
                                    required property var modelData
                                    theme: lab.theme
                                    tokenName: modelData.name
                                    tokenColor: modelData.value
                                }
                            }
                        }

                        SectionHeading {
                            Layout.fillWidth: true
                            Layout.leftMargin: 28
                            Layout.rightMargin: 28
                            theme: lab.theme
                            title: "Shared controls and panel composition"
                            detail: "This preview uses the real shared components that production panels will import."
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 28
                            Layout.rightMargin: 28
                            Layout.alignment: Qt.AlignTop
                            spacing: 18

                            Lab.PanelPreview {
                                id: networkPreview

                                theme: lab.theme
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: 14

                                Lab.NotificationPreview {
                                    id: notificationPreview

                                    Layout.fillWidth: true
                                    theme: lab.theme
                                }

                                Ui.ShellSurface {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    theme: lab.theme
                                    kind: "osd"

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            margins: 14
                                        }
                                        spacing: 12

                                        Ui.ShellIcon {
                                            theme: lab.theme
                                            name: "brightness"
                                            color: lab.theme.semantic.signal.brightness
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 6
                                            radius: 3
                                            color: lab.theme.component.osd.track

                                            Rectangle {
                                                width: parent.width * 0.68
                                                height: parent.height
                                                radius: parent.radius
                                                color: lab.theme.semantic.signal.brightness
                                            }
                                        }

                                        Ui.ShellText {
                                            theme: lab.theme
                                            text: "68%"
                                            monospace: true
                                        }
                                    }
                                }

                                Lab.MotionPreview {
                                    Layout.fillWidth: true
                                    theme: lab.theme
                                    reducedMotion: lab.reducedMotionChoice
                                }
                            }
                        }

                        Item {
                            Layout.preferredHeight: 28
                        }
                    }
                }
            }
        }
    }
}
