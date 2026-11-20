import QtQuick
import "Motion.js" as Motion

Item {
    id: root

    property var spring: Motion.LAYOUT
    property real target: 0
    property real from: NaN
    property real epsilon: 0.25
    property bool instant: false
    property bool hold: false
    property real value: 0
    property real velocity: 0
    readonly property bool moving: frame.running

    property var _solved: null
    property real _segmentTarget: 0
    property bool _ready: false

    signal settled

    visible: false
    width: 0
    height: 0

    function launch(position, speed) {
        value = position
        velocity = speed
        retarget()
    }

    function jump(position) {
        frame.stop()
        value = position
        velocity = 0
    }

    function retarget() {
        if (!_ready || hold)
            return
        var offset = value - target
        if (instant || (Math.abs(offset) < epsilon && Math.abs(velocity) < epsilon * 10)) {
            var wasMoving = frame.running
            frame.stop()
            value = target
            velocity = 0
            if (wasMoving || instant || offset !== 0)
                settled()
            return
        }
        _solved = Motion.solve(spring, offset, velocity)
        _segmentTarget = target
        frame.restart()
    }

    onTargetChanged: retarget()
    onInstantChanged: retarget()
    onHoldChanged: retarget()

    FrameAnimation {
        id: frame

        onTriggered: {
            var sampled = Motion.sample(root._solved, elapsedTime)
            if (Math.abs(sampled[0]) < root.epsilon && Math.abs(sampled[1]) < root.epsilon * 10) {
                stop()
                root.value = root._segmentTarget
                root.velocity = 0
                root.settled()
                return
            }
            root.value = root._segmentTarget + sampled[0]
            root.velocity = sampled[1]
        }
    }

    Component.onCompleted: {
        value = isNaN(from) ? target : from
        _ready = true
        retarget()
    }
}
