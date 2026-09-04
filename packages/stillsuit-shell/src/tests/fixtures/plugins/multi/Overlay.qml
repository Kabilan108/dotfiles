import QtQuick

QtObject {
    required property var context
    required property var screen
    required property string outputId
    required property var service

    readonly property string fixtureKind: "overlay"
}
