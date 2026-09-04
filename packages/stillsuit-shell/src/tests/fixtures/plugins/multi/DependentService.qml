import QtQuick

QtObject {
    required property var context
    readonly property string apiVersion: "1"
    readonly property bool dependencyVisible: context.services.has("stillsuit.multi")
}
