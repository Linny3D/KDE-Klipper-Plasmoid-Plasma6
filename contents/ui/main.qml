import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtWebSockets
import QtCharts 2.3
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    width: 320
    height: 240

    property int requestId: 0
    property var pending: ({})
    property string connectionState: "disconnected"
    property string errorText: ""
 

    property string printerState: "unknown"
    property string filename: ""
    property real progress: 0
    property real nozzleTemp: 0
    property real nozzleTarget: 0
    property real bedTemp: 0
    property real bedTarget: 0
    property int chartX: 0
    property int maxPoints: 120
    property var nozzleSeriesRef: null
    property var bedSeriesRef: null
    property real tempAxisMin: 0
    property var nozzleHistory: []
    property var bedHistory: []
    property real tempAxisMaxDynamic: 100
    property real tempAxisMax: {
        var peak = Math.max(tempAxisMaxDynamic, 100)
        if (peak <= 100) {
            return 100
        }
        return Math.ceil(peak / 10) * 10
    }
    property int tempAxisTicks: root.width < 420 ? 4 : 5
    property color accentColor: PlasmaCore.Theme.highlightColor
    property color accentAltColor: Qt.lighter(PlasmaCore.Theme.highlightColor, 1.4)
    property color cardColor: colorWithAlpha(PlasmaCore.Theme.backgroundColor, 0.85)
    property color cardBorderColor: colorWithAlpha(PlasmaCore.Theme.textColor, 0.12)

    function colorWithAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    property string startFile: plasmoid.configuration.defaultFile

    function isConfigured() {
        return plasmoid.configuration.host && plasmoid.configuration.port > 0
    }

    function connectionStateText() {
        if (connectionState === "connecting") {
            return i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Connecting")
        }
        if (connectionState === "connected") {
            return i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Connected")
        }
        if (connectionState === "not_configured") {
            return i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Not configured")
        }
        return i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Disconnected")
    }

    function wsUrl() {
        var scheme = plasmoid.configuration.useTls ? "wss" : "ws"
        var host = plasmoid.configuration.host
        var port = plasmoid.configuration.port
        if (!host || port <= 0) {
            return ""
        }
        var path = plasmoid.configuration.wsPath || "/websocket"
        if (path[0] !== "/") {
            path = "/" + path
        }
        var url = scheme + "://" + host + ":" + port + path
        if (plasmoid.configuration.apiKey) {
            url += "?token=" + encodeURIComponent(plasmoid.configuration.apiKey)
        }
        return url
    }

    function reconnect() {
        errorText = ""
        connectionState = "connecting"
        socket.active = false
        if (!isConfigured()) {
            connectionState = "not_configured"
            return
        }
        var url = wsUrl()
        socket.url = url
        socket.active = true
    }

    function sendRequest(method, params, callback) {
        if (socket.status !== WebSocket.Open) {
            errorText = "WebSocket not connected"
            return
        }
        requestId += 1
        var id = requestId
        if (callback) {
            pending[id] = callback
        }
        var payload = {
            jsonrpc: "2.0",
            id: id,
            method: method
        }
        if (params) {
            payload.params = params
        }
        socket.sendTextMessage(JSON.stringify(payload))
    }

    function updateFromStatus(status) {
        var tempUpdated = false
        var xValue = 0
        if (status.print_stats) {
            printerState = status.print_stats.state || printerState
            filename = status.print_stats.filename || filename
        }
        if (status.virtual_sdcard) {
            if (status.virtual_sdcard.progress !== undefined) {
                progress = status.virtual_sdcard.progress
            }
        }
        if (status.extruder) {
            if (status.extruder.temperature !== undefined) {
                nozzleTemp = status.extruder.temperature
            }
            if (status.extruder.target !== undefined) {
                nozzleTarget = status.extruder.target
            } else if (status.extruder.target_temp !== undefined) {
                nozzleTarget = status.extruder.target_temp
            }
        }
        if (status.heater_bed) {
            if (status.heater_bed.temperature !== undefined) {
                bedTemp = status.heater_bed.temperature
            }
            if (status.heater_bed.target !== undefined) {
                bedTarget = status.heater_bed.target
            } else if (status.heater_bed.target_temp !== undefined) {
                bedTarget = status.heater_bed.target_temp
            }
        }
    }

    function formatTemp(value) {
        return value.toFixed(1) + " C"
    }

    function nextX() {
        chartX += 1
        return chartX
    }

    function addPoint(series, xValue, yValue) {
        if (!series) {
            return
        }
        series.append(xValue, yValue)
        if (series.count > maxPoints) {
            series.remove(0)
        }
    }

    function updateTempHistory() {
        nozzleHistory.push(nozzleTemp)
        bedHistory.push(bedTemp)
        if (nozzleHistory.length > maxPoints) {
            nozzleHistory.shift()
        }
        if (bedHistory.length > maxPoints) {
            bedHistory.shift()
        }
        var maxTemp = 0
        for (var i = 0; i < nozzleHistory.length; i += 1) {
            if (nozzleHistory[i] > maxTemp) {
                maxTemp = nozzleHistory[i]
            }
        }
        for (var j = 0; j < bedHistory.length; j += 1) {
            if (bedHistory[j] > maxTemp) {
                maxTemp = bedHistory[j]
            }
        }
        tempAxisMaxDynamic = maxTemp
    }

    function tempAxisValueAt(index) {
        if (tempAxisTicks <= 1) {
            return tempAxisMax
        }
        var range = tempAxisMax - tempAxisMin
        return tempAxisMax - range * (index / (tempAxisTicks - 1))
    }

    function sampleCharts() {
        if (connectionState !== "connected") {
            return
        }
        updateTempHistory()
        var xValue = nextX()
        addPoint(nozzleSeriesRef, xValue, nozzleTemp)
        addPoint(bedSeriesRef, xValue, bedTemp)
    }

    function requestStatus() {
        var objects = {
            print_stats: null,
            virtual_sdcard: null,
            extruder: ["temperature", "target"],
            heater_bed: ["temperature", "target"]
        }
        sendRequest("printer.objects.subscribe", {
            objects: objects
        }, function(response) {
            if (response && response.result && response.result.status) {
                updateFromStatus(response.result.status)
            }
        })
        sendRequest("printer.objects.query", {
            objects: {
                print_stats: null,
                virtual_sdcard: null,
                extruder: null,
                heater_bed: null
            }
        }, function(response) {
            if (response && response.result && response.result.status) {
                updateFromStatus(response.result.status)
            }
        })
    }

    function startPrint() {
        if (!startFile) {
            errorText = "No filename provided"
            return
        }
        sendRequest("printer.print.start", { filename: startFile })
    }

    function pausePrint() {
        sendRequest("printer.print.pause")
    }

    function resumePrint() {
        sendRequest("printer.print.resume")
    }

    function cancelPrint() {
        sendRequest("printer.print.cancel")
    }

    WebSocket {
        id: socket
        active: false

        onStatusChanged: function(status) {
            if (!isConfigured()) {
                connectionState = "not_configured"
                return
            }
            if (status === WebSocket.Open) {
                connectionState = "connected"
                errorText = ""
                responseTimer.restart()
                sendRequest("server.info")
                requestStatus()
            } else if (status === WebSocket.Closed) {
                connectionState = "disconnected"
                if (isConfigured()) {
                    retryTimer.restart()
                }
            } else if (status === WebSocket.Connecting) {
                connectionState = "connecting"
            }
        }

        onTextMessageReceived: function(textMessage) {
            var message = {}
            try {
                if (!textMessage || textMessage.trim().length === 0) {
                    return
                }
                responseTimer.stop()
                message = JSON.parse(textMessage)
            } catch (e) {
                errorText = i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Invalid JSON from server: %1", textMessage)
                console.error("KlipperMonitor: invalid JSON", textMessage)
                return
            }

            if (message.id && pending[message.id]) {
                pending[message.id](message)
                delete pending[message.id]
                return
            }

            if (message.method === "notify_status_update" && message.params) {
                if (message.params.status) {
                    updateFromStatus(message.params.status)
                } else if (message.params.length > 0) {
                    updateFromStatus(message.params[0])
                }
                return
            }

            if (message.error && message.error.message) {
                errorText = i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Server error: %1", message.error.message)
            }
        }

        onBinaryMessageReceived: function(binaryMessage) {
        }

        onErrorStringChanged: function(errorString) {
            if (errorString) {
                errorText = errorString
            }
        }
    }

    Timer {
        id: responseTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (socket.status === WebSocket.Open) {
                errorText = i18nd("plasma_applet_org.kde.plasma.klippermonitor", "No response from server. Check host/port, reverse proxy, or auth token.")
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 5000
        repeat: false
        onTriggered: reconnect()
    }

    Timer {
        id: chartTimer
        interval: Math.max(250, plasmoid.configuration.chartIntervalMs)
        repeat: true
        running: isConfigured() && connectionState === "connected"
        onTriggered: sampleCharts()
    }

    Connections {
        target: plasmoid.configuration
        function onHostChanged() { reconnect() }
        function onPortChanged() { reconnect() }
        function onUseTlsChanged() { reconnect() }
        function onApiKeyChanged() { reconnect() }
        function onWsPathChanged() { reconnect() }
        function onDefaultFileChanged() {
            startFile = plasmoid.configuration.defaultFile
        }
    }

    Component.onCompleted: reconnect()

    fullRepresentation: Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: PlasmaCore.Theme.backgroundColor
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.colorWithAlpha(root.accentColor, 0.08) }
                GradientStop { position: 1.0; color: root.colorWithAlpha(PlasmaCore.Theme.textColor, 0.05) }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label {
                        text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Klipper Monitor")
                        font.weight: Font.DemiBold
                        font.pointSize: PlasmaCore.Theme.defaultFont.pointSize + 4
                    }

                    PlasmaComponents3.Label {
                        text: filename ? i18nd("plasma_applet_org.kde.plasma.klippermonitor", "%1 • %2", printerState, filename) : i18nd("plasma_applet_org.kde.plasma.klippermonitor", "%1 • No file", printerState)
                        opacity: 0.7
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 32
                    radius: 16
                    color: connectionState === "connected"
                        ? root.colorWithAlpha(root.accentColor, 0.20)
                        : connectionState === "connecting"
                            ? root.colorWithAlpha(PlasmaCore.Theme.textColor, 0.12)
                            : root.colorWithAlpha(PlasmaCore.Theme.negativeTextColor, 0.18)
                    border.color: connectionState === "connected"
                        ? root.colorWithAlpha(root.accentColor, 0.55)
                        : connectionState === "connecting"
                            ? root.colorWithAlpha(PlasmaCore.Theme.textColor, 0.35)
                            : root.colorWithAlpha(PlasmaCore.Theme.negativeTextColor, 0.55)

                    PlasmaComponents3.Label {
                        anchors.centerIn: parent
                        text: connectionStateText()
                        font.weight: Font.Medium
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: isConfigured()
                spacing: Kirigami.Units.mediumSpacing

                RowLayout {
                    Layout.fillWidth: true

                    PlasmaComponents3.ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: progress
                    }

                    PlasmaComponents3.Label {
                        text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "%1%", (progress * 100).toFixed(1))
                        font.weight: Font.Medium
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 4
                        horizontalAlignment: Text.AlignRight
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Kirigami.Units.smallSpacing
                    columnSpacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        radius: 12
                        color: root.cardColor
                        border.color: root.cardBorderColor

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            spacing: 2

                            PlasmaComponents3.Label { text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Nozzle"); opacity: 0.7 }
                            PlasmaComponents3.Label {
                                text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "%1 / %2", formatTemp(nozzleTemp), formatTemp(nozzleTarget))
                                font.weight: Font.Medium
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        radius: 12
                        color: root.cardColor
                        border.color: root.cardBorderColor

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Kirigami.Units.smallSpacing
                            spacing: 2

                            PlasmaComponents3.Label { text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Bed"); opacity: 0.7 }
                            PlasmaComponents3.Label {
                                text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "%1 / %2", formatTemp(bedTemp), formatTemp(bedTarget))
                                font.weight: Font.Medium
                            }
                        }
                    }

                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true

                        PlasmaComponents3.Label {
                            text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Thermals")
                            font.weight: Font.Medium
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Rectangle { width: 10; height: 10; radius: 3; color: root.accentColor }
                            PlasmaComponents3.Label { text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Nozzle") }
                            Rectangle { width: 10; height: 10; radius: 3; color: root.accentAltColor }
                            PlasmaComponents3.Label { text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Bed") }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Item {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                            Layout.fillHeight: true

                            Repeater {
                                model: root.tempAxisTicks

                                PlasmaComponents3.Label {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignRight
                                    text: formatTemp(root.tempAxisValueAt(index))
                                    opacity: 0.7
                                    font.pixelSize: Math.max(8, PlasmaCore.Theme.defaultFont.pixelSize - 2)
                                    y: (parent.height - height) * (root.tempAxisTicks > 1
                                        ? (index / (root.tempAxisTicks - 1))
                                        : 0)
                                }
                            }
                        }

                        ChartView {
                            id: tempChart
                            Layout.fillWidth: true
                            Layout.preferredHeight: 120
                            antialiasing: true
                            legend.visible: false
                            backgroundColor: "transparent"
                            margins { left: 8; right: 8; top: 4; bottom: 4 }

                            ValueAxis {
                                id: tempAxisX
                                min: Math.max(0, root.chartX - root.maxPoints)
                                max: Math.max(root.maxPoints, root.chartX)
                                labelsVisible: false
                                gridVisible: false
                                lineVisible: false
                            }
                            ValueAxis {
                                id: tempAxisY
                                min: root.tempAxisMin
                                max: root.tempAxisMax
                                labelsVisible: false
                                gridVisible: true
                                lineVisible: false
                            }

                        LineSeries {
                            id: nozzleSeries
                            axisX: tempAxisX
                            axisY: tempAxisY
                            color: root.accentColor
                            width: 2.0
                            Component.onCompleted: root.nozzleSeriesRef = nozzleSeries
                        }
                        LineSeries {
                            id: bedSeries
                            axisX: tempAxisX
                            axisY: tempAxisY
                            color: root.accentAltColor
                            width: 2.0
                            Component.onCompleted: root.bedSeriesRef = bedSeries
                        }
                        }
                    }
                }


                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.TextField {
                        id: startFileField
                        Layout.fillWidth: true
                        placeholderText: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "filename.gcode")
                        text: startFile
                        onEditingFinished: startFile = text
                    }

                    PlasmaComponents3.Button {
                        text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Start")
                        icon.name: "media-playback-start"
                        onClicked: startPrint()
                    }

                    PlasmaComponents3.Button {
                        text: printerState === "paused" ? i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Resume") : i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Pause")
                        icon.name: printerState === "paused" ? "media-playback-start" : "media-playback-pause"
                        onClicked: printerState === "paused" ? resumePrint() : pausePrint()
                    }

                    PlasmaComponents3.Button {
                        text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Cancel")
                        icon.name: "process-stop"
                        onClicked: cancelPrint()
                    }

                    PlasmaComponents3.Button {
                        icon.name: "view-refresh"
                        text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Reconnect")
                        onClicked: reconnect()
                    }
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: errorText
                    visible: errorText.length > 0
                    color: PlasmaCore.Theme.negativeTextColor
                    wrapMode: Text.Wrap
                }
            }

            PlasmaComponents3.Label {
                Layout.fillWidth: true
                visible: !isConfigured()
                text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Not configured. Open the settings to add your Moonraker host.")
                wrapMode: Text.Wrap
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
