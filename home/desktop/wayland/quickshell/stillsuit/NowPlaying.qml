import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Column {
    id: root

    property var player: {
        for (let i = 0; i < Mpris.players.values.length; i++) {
            const p = Mpris.players.values[i]
            if (p.isPlaying) return p
        }
        if (Mpris.players.values.length > 0) return Mpris.players.values[0]
        return null
    }

    visible: root.player !== null
    spacing: 14
    width: parent?.width ?? implicitWidth

    Timer {
        interval: 500
        running: root.player?.isPlaying ?? false
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    MixerSectionLabel {
        text: "Now Playing"
    }

    Row {
        width: parent.width
        spacing: 12

        Rectangle {
            implicitWidth: 60
            implicitHeight: 60
            radius: Theme.radiusSmall
            color: Theme.surface0
            border.width: Theme.borderWidth
            border.color: Theme.panelBorder
            clip: true

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: Theme.icon.music_note
                color: Theme.overlay0
                font.family: Theme.iconFamily
                font.variableAxes: ({ "wght": 500, "opsz": 20 })
                font.pixelSize: 26
                visible: !root.player?.trackArtUrl
            }
        }

        Column {
            width: parent.width - 72
            spacing: 3
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: root.player?.trackTitle ?? ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: root.player?.trackArtist ?? ""
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                elide: Text.ElideRight
                visible: text !== ""
                width: parent.width
            }

            Text {
                text: root.player?.trackAlbum ?? ""
                color: Theme.subtext1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                visible: text !== ""
                width: parent.width
            }
        }
    }

    Column {
        width: parent.width
        spacing: 6

        Rectangle {
            width: parent.width
            height: 5
            radius: 999
            color: Theme.surface0
            visible: root.player?.lengthSupported ?? false

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: {
                    const len = root.player?.length ?? 0
                    if (len <= 0) return 0
                    return parent.width * Math.min((root.player?.position ?? 0) / len, 1)
                }
                radius: parent.radius
                color: Theme.accent
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.player?.canSeek ?? false
                onClicked: mouse => {
                    const target = (mouse.x / parent.width) * root.player.length
                    const offset = target - root.player.position
                    root.player.seek(offset)
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: 6
            visible: root.player?.lengthSupported ?? false

            Text {
                text: formatTime(root.player?.position ?? 0)
                color: Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }

            Item { Layout.fillWidth: true }

            Text {
                text: formatTime(root.player?.length ?? 0)
                color: Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14

        Text {
            text: root.player?.shuffle ? Theme.icon.shuffle_on : Theme.icon.shuffle
            color: root.player?.shuffle ? Theme.accent : Theme.text
            font.family: Theme.iconFamily
            font.variableAxes: ({ "wght": 500, "opsz": 20 })
            font.pixelSize: 18
            height: 38
            verticalAlignment: Text.AlignVCenter
            visible: root.player?.shuffleSupported ?? false

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player.shuffle = !root.player.shuffle
            }
        }

        Text {
            text: Theme.icon.skip_previous
            color: root.player?.canGoPrevious ? Theme.text : Theme.overlay0
            font.family: Theme.iconFamily
            font.variableAxes: ({ "wght": 500, "opsz": 20 })
            font.pixelSize: 22
            height: 38
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player?.previous()
                enabled: root.player?.canGoPrevious ?? false
            }
        }

        Rectangle {
            implicitWidth: 38
            implicitHeight: 38
            radius: 19
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: root.player?.isPlaying ? Theme.icon.pause : Theme.icon.play_arrow
                color: Theme.crust
                font.family: Theme.iconFamily
                font.variableAxes: ({ "wght": 600, "opsz": 20 })
                font.pixelSize: 18
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player?.togglePlaying()
                enabled: root.player?.canTogglePlaying ?? false
            }
        }

        Text {
            text: Theme.icon.skip_next
            color: root.player?.canGoNext ? Theme.text : Theme.overlay0
            font.family: Theme.iconFamily
            font.variableAxes: ({ "wght": 500, "opsz": 20 })
            font.pixelSize: 22
            height: 38
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player?.next()
                enabled: root.player?.canGoNext ?? false
            }
        }

        Text {
            text: {
                const s = root.player?.loopState
                if (s === MprisLoopState.Track) return Theme.icon.repeat_one
                if (s === MprisLoopState.Playlist) return Theme.icon.repeat
                return Theme.icon.repeat
            }
            color: {
                const s = root.player?.loopState
                return (s === MprisLoopState.Track || s === MprisLoopState.Playlist)
                    ? Theme.accent : Theme.text
            }
            font.family: Theme.iconFamily
            font.variableAxes: ({ "wght": 500, "opsz": 20 })
            font.pixelSize: 18
            height: 38
            verticalAlignment: Text.AlignVCenter
            visible: root.player?.loopSupported ?? false

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const s = root.player.loopState
                    if (s === MprisLoopState.None) root.player.loopState = MprisLoopState.Playlist
                    else if (s === MprisLoopState.Playlist) root.player.loopState = MprisLoopState.Track
                    else root.player.loopState = MprisLoopState.None
                }
            }
        }
    }

    function formatTime(seconds: real): string {
        const m = Math.floor(seconds / 60)
        const s = Math.floor(seconds % 60)
        return `${m}:${s.toString().padStart(2, '0')}`
    }
}
