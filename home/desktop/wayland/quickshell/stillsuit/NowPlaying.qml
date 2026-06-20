import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

ColumnLayout {
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
    spacing: 0

    Text {
        text: "Now Playing"
        color: Theme.dimText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
    }

    Item { implicitHeight: 6 }

    RowLayout {
        spacing: 10

        Rectangle {
            implicitWidth: 48
            implicitHeight: 48
            radius: Theme.radiusSmall
            color: Theme.surface0
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
                font.pixelSize: 22
                visible: !root.player?.trackArtUrl
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.player?.trackTitle ?? ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMedium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.player?.trackArtist ?? ""
                color: Theme.dimText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                visible: text !== ""
            }
        }
    }

    Item { implicitHeight: 6 }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 20

        Text {
            text: root.player?.shuffle ? Theme.icon.shuffle_on : Theme.icon.shuffle
            color: root.player?.shuffle ? Theme.accent : Theme.overlay0
            font.family: Theme.iconFamily
            font.variableAxes: ({ "wght": 500, "opsz": 20 })
            font.pixelSize: 16
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
            font.pixelSize: 20

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.player?.previous()
                enabled: root.player?.canGoPrevious ?? false
            }
        }

        Rectangle {
            implicitWidth: 32
            implicitHeight: 32
            radius: 16
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: root.player?.isPlaying ? Theme.icon.pause : Theme.icon.play_arrow
                color: Theme.crust
                font.family: Theme.iconFamily
                font.variableAxes: ({ "wght": 500, "opsz": 20 })
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
            font.pixelSize: 20

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
                    ? Theme.accent : Theme.overlay0
            }
            font.family: Theme.iconFamily
            font.variableAxes: ({ "wght": 500, "opsz": 20 })
            font.pixelSize: 16
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

    Item { implicitHeight: 4 }

    RowLayout {
        spacing: 6
        visible: root.player?.lengthSupported ?? false

        Text {
            text: formatTime(root.player?.position ?? 0)
            color: Theme.dimText
            font.family: Theme.fontFamily
            font.pixelSize: 9
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Theme.surface0

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
                onClicked: mouse => {
                    if (root.player?.canSeek) {
                        const target = (mouse.x / parent.width) * root.player.length
                        const offset = target - root.player.position
                        root.player.seek(offset)
                    }
                }
            }
        }

        Text {
            text: formatTime(root.player?.length ?? 0)
            color: Theme.dimText
            font.family: Theme.fontFamily
            font.pixelSize: 9
        }
    }

    function formatTime(seconds: real): string {
        const m = Math.floor(seconds / 60)
        const s = Math.floor(seconds % 60)
        return `${m}:${s.toString().padStart(2, '0')}`
    }
}
