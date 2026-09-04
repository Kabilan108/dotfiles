import QtQuick

QtObject {
    id: root

    property int timeoutMs: 5000
    property int remainingMs: timeoutMs
    property bool interactionActive: false
    property bool running: false
    readonly property int remainingSeconds: Math.max(0, Math.ceil(remainingMs / 1000))

    signal expired()

    function start() {
        remainingMs = Math.max(0, timeoutMs)
        running = remainingMs > 0
        if (!running)
            expired()
    }

    function stop() {
        running = false
    }

    function tick(milliseconds) {
        if (!running || interactionActive)
            return false
        remainingMs = Math.max(0, remainingMs - Math.max(0, Number(milliseconds || 0)))
        if (remainingMs > 0)
            return false
        running = false
        expired()
        return true
    }
}
