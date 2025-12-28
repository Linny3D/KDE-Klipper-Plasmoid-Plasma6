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
    implicitWidth: fullRoot.implicitWidth
    implicitHeight: fullRoot.implicitHeight
    Layout.minimumWidth: fullRoot.Layout.minimumWidth
    Layout.minimumHeight: fullRoot.Layout.minimumHeight
    Layout.preferredWidth: fullRoot.Layout.preferredWidth
    Layout.preferredHeight: fullRoot.Layout.preferredHeight

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
    property real posX: 0
    property real posY: 0
    property real posZ: 0
    property real speedFactor: 0
    property real flowFactor: 0
    property real fanSpeed: 0
    property var gcodeFiles: []
    property string selectedFile: ""
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

    function isEnabled() {
        return plasmoid.configuration.enableConnections
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
        if (connectionState === "disabled") {
            return i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Disabled")
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
        if (!isEnabled()) {
            connectionState = "disabled"
            return
        }
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
        if (status.motion_report && status.motion_report.live_position && status.motion_report.live_position.length >= 3) {
            posX = status.motion_report.live_position[0]
            posY = status.motion_report.live_position[1]
            posZ = status.motion_report.live_position[2]
        } else if (status.toolhead && status.toolhead.position && status.toolhead.position.length >= 3) {
            posX = status.toolhead.position[0]
            posY = status.toolhead.position[1]
            posZ = status.toolhead.position[2]
        }
        if (status.gcode_move) {
            if (status.gcode_move.speed_factor !== undefined) {
                speedFactor = status.gcode_move.speed_factor
            }
            if (status.gcode_move.extrude_factor !== undefined) {
                flowFactor = status.gcode_move.extrude_factor
            }
        }
        if (status.fan && status.fan.speed !== undefined) {
            fanSpeed = status.fan.speed
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
            heater_bed: ["temperature", "target"],
            toolhead: ["position", "homed_axes"],
            motion_report: ["live_position", "live_velocity"],
            gcode_move: ["speed_factor", "extrude_factor"],
            fan: ["speed"]
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
                heater_bed: null,
                toolhead: null,
                motion_report: null,
                gcode_move: null,
                fan: null
            }
        }, function(response) {
            if (response && response.result && response.result.status) {
                updateFromStatus(response.result.status)
            }
        })
    }

    function normalizeFileList(response) {
        if (!response || !response.result || !response.result.files) {
            return []
        }
        var files = []
        for (var i = 0; i < response.result.files.length; i += 1) {
            var entry = response.result.files[i]
            var path = entry.path || entry.filename || entry.name
            if (path) {
                files.push(path)
            }
        }
        files.sort()
        return files
    }

    function applyFileList(files) {
        gcodeFiles = files
        if (gcodeFiles.length === 0) {
            selectedFile = ""
            return
        }
        if (startFile && gcodeFiles.indexOf(startFile) >= 0) {
            selectedFile = startFile
        } else if (!selectedFile || gcodeFiles.indexOf(selectedFile) < 0) {
            selectedFile = gcodeFiles[0]
        }
    }

    function refreshFiles() {
        sendRequest("server.files.list", { root: "gcodes" }, function(response) {
            var files = normalizeFileList(response)
            if (files.length > 0) {
                applyFileList(files)
                return
            }
            sendRequest("server.files.list", null, function(fallback) {
                files = normalizeFileList(fallback)
                applyFileList(files)
            })
        })
    }

    function requestMotionSnapshot() {
        sendRequest("printer.objects.query", {
            objects: {
                toolhead: ["position", "homed_axes"],
                motion_report: ["live_position", "live_velocity"],
                gcode_move: ["speed_factor", "extrude_factor"],
                fan: ["speed"]
            }
        }, function(response) {
            if (response && response.result && response.result.status) {
                updateFromStatus(response.result.status)
            }
        })
    }

    function sendGcode(script) {
        sendRequest("printer.gcode.script", { script: script })
    }

    function jog(axis, distance) {
        if (!distance || distance === 0) {
            return
        }
        var target = 0
        if (axis === "X") {
            target = posX + distance
        } else if (axis === "Y") {
            target = posY + distance
        } else if (axis === "Z") {
            target = posZ + distance
        } else {
            return
        }
        if (isNaN(target)) {
            return
        }
        var feed = 0
        if (axis === "Z") {
            feed = plasmoid.configuration.jogFeedZ
        } else {
            feed = plasmoid.configuration.jogFeedXY
        }
        var feedPart = feed > 0 ? (" F" + feed) : ""
        sendGcode("G90\nG1 " + axis + target.toFixed(2) + feedPart)
    }

    function homeAll() {
        sendGcode("G28")
    }

    function homeAxis(axis) {
        sendGcode("G28 " + axis)
    }

    function startPrint() {
        var file = selectedFile || startFile
        if (!file) {
            errorText = i18nd("plasma_applet_org.kde.plasma.klippermonitor", "No filename provided")
            return
        }
        sendRequest("printer.print.start", { filename: file })
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
                refreshFiles()
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
        running: isConfigured() && isEnabled() && connectionState === "connected"
        onTriggered: sampleCharts()
    }

    Timer {
        id: motionTimer
        interval: 200
        repeat: true
        running: isConfigured() && isEnabled() && connectionState === "connected"
        onTriggered: requestMotionSnapshot()
    }

    Connections {
        target: plasmoid.configuration
        function onUseTlsChanged() { reconnect() }
        function onApiKeyChanged() { reconnect() }
        function onWsPathChanged() { reconnect() }
        function onDefaultFileChanged() {
            startFile = plasmoid.configuration.defaultFile
        }
        function onHostChanged() { reconnect() }
        function onPortChanged() { reconnect() }
        function onEnableConnectionsChanged() {
            if (plasmoid.configuration.enableConnections) {
                reconnect()
            } else {
                errorText = ""
                socket.active = false
                connectionState = "disabled"
            }
        }
    }

    Component.onCompleted: reconnect()

    fullRepresentation: Item {
        id: fullRoot
        readonly property int contentMinWidth: Kirigami.Units.gridUnit * 26
        implicitWidth: Math.max(contentMinWidth, contentLayout.implicitWidth) + Kirigami.Units.largeSpacing * 2
        implicitHeight: contentLayout.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
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
            id: contentLayout
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            width: Math.max(fullRoot.contentMinWidth, implicitWidth)

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

                PlasmaComponents3.Switch {
                    text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Enabled")
                    checked: plasmoid.configuration.enableConnections
                    onToggled: plasmoid.configuration.enableConnections = checked
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: isConfigured()
                spacing: Kirigami.Units.mediumSpacing
                enabled: isEnabled()
                opacity: isEnabled() ? 1.0 : 0.35

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
                            text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Toolhead")
                            font.weight: Font.Medium
                        }

                        Item { Layout.fillWidth: true }

                        PlasmaComponents3.Label {
                            text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Position: absolute")
                            opacity: 0.7
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: Kirigami.Units.smallSpacing
                        columnSpacing: Kirigami.Units.smallSpacing

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: 10
                            color: root.cardColor
                            border.color: root.cardBorderColor

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                spacing: 2
                                PlasmaComponents3.Label { text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "X"); opacity: 0.7 }
                                PlasmaComponents3.Label { text: posX.toFixed(2) }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: 10
                            color: root.cardColor
                            border.color: root.cardBorderColor

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                spacing: 2
                                PlasmaComponents3.Label { text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Y"); opacity: 0.7 }
                                PlasmaComponents3.Label { text: posY.toFixed(2) }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            radius: 10
                            color: root.cardColor
                            border.color: root.cardBorderColor

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                spacing: 2
                                PlasmaComponents3.Label { text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Z"); opacity: 0.7 }
                                PlasmaComponents3.Label { text: posZ.toFixed(2) }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.mediumSpacing

                        Item {
                            id: jogPad
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 9

                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height)
                                height: width
                                radius: width / 2
                                color: root.colorWithAlpha(root.accentColor, 0.08)
                                border.color: root.colorWithAlpha(PlasmaCore.Theme.textColor, 0.2)
                                border.width: 1
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.56
                                height: width
                                radius: width / 2
                                color: root.colorWithAlpha(PlasmaCore.Theme.backgroundColor, 0.9)
                                border.color: root.cardBorderColor
                                border.width: 1
                            }

                            Rectangle {
                                id: jogUp
                                width: Kirigami.Units.gridUnit * 2.3
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: Kirigami.Units.smallSpacing
                                radius: 6
                                color: root.cardColor
                                border.color: root.cardBorderColor
                                PlasmaComponents3.Label {
                                    anchors.centerIn: parent
                                    text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Y+")
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: jog("Y", plasmoid.configuration.jogStep)
                                }
                            }

                            Rectangle {
                                id: jogDown
                                width: Kirigami.Units.gridUnit * 2.3
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Kirigami.Units.smallSpacing
                                radius: 6
                                color: root.cardColor
                                border.color: root.cardBorderColor
                                PlasmaComponents3.Label {
                                    anchors.centerIn: parent
                                    text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Y-")
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: jog("Y", -plasmoid.configuration.jogStep)
                                }
                            }

                            Rectangle {
                                id: jogLeft
                                width: Kirigami.Units.gridUnit * 2.3
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: Kirigami.Units.smallSpacing
                                radius: 6
                                color: root.cardColor
                                border.color: root.cardBorderColor
                                PlasmaComponents3.Label {
                                    anchors.centerIn: parent
                                    text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "X-")
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: jog("X", -plasmoid.configuration.jogStep)
                                }
                            }

                            Rectangle {
                                id: jogRight
                                width: Kirigami.Units.gridUnit * 2.3
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: Kirigami.Units.smallSpacing
                                radius: 6
                                color: root.cardColor
                                border.color: root.cardBorderColor
                                PlasmaComponents3.Label {
                                    anchors.centerIn: parent
                                    text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "X+")
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: jog("X", plasmoid.configuration.jogStep)
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.6
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 6
                            radius: 8
                            color: root.cardColor
                            border.color: root.cardBorderColor

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing
                                PlasmaComponents3.Label { text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Z") }
                                Rectangle {
                                    width: Kirigami.Units.gridUnit * 2.0
                                    height: Kirigami.Units.gridUnit * 2.0
                                    radius: 6
                                    color: root.colorWithAlpha(root.accentColor, 0.10)
                                    border.color: root.cardBorderColor
                                    PlasmaComponents3.Label { anchors.centerIn: parent; text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Z+") }
                                    MouseArea { anchors.fill: parent; onClicked: jog("Z", plasmoid.configuration.jogStep) }
                                }
                                Rectangle {
                                    width: Kirigami.Units.gridUnit * 2.0
                                    height: Kirigami.Units.gridUnit * 2.0
                                    radius: 6
                                    color: root.cardColor
                                    border.color: root.cardBorderColor
                                    PlasmaComponents3.Label { anchors.centerIn: parent; text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Z-") }
                                    MouseArea { anchors.fill: parent; onClicked: jog("Z", -plasmoid.configuration.jogStep) }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: Kirigami.Units.smallSpacing

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.2
                                radius: 8
                                color: root.colorWithAlpha(root.accentColor, 0.15)
                                border.color: root.cardBorderColor

                                PlasmaComponents3.Label {
                                    anchors.centerIn: parent
                                    text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Home All")
                                    font.weight: Font.Medium
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: homeAll()
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.0
                                    radius: 8
                                    color: root.cardColor
                                    border.color: root.cardBorderColor
                                    PlasmaComponents3.Label { anchors.centerIn: parent; text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Home X") }
                                    MouseArea { anchors.fill: parent; onClicked: homeAxis("X") }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.0
                                    radius: 8
                                    color: root.cardColor
                                    border.color: root.cardBorderColor
                                    PlasmaComponents3.Label { anchors.centerIn: parent; text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Home Y") }
                                    MouseArea { anchors.fill: parent; onClicked: homeAxis("Y") }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.0
                                    radius: 8
                                    color: root.cardColor
                                    border.color: root.cardBorderColor
                                    PlasmaComponents3.Label { anchors.centerIn: parent; text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Home Z") }
                                    MouseArea { anchors.fill: parent; onClicked: homeAxis("Z") }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents3.Label {
                                text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Steps")
                                opacity: 0.7
                            }

                            Repeater {
                                model: [0.1, 1, 10, 25, 50, 100]
                                delegate: PlasmaComponents3.Button {
                                    text: modelData.toString()
                                    checkable: true
                                    checked: Math.abs(plasmoid.configuration.jogStep - modelData) < 0.001
                                    onClicked: plasmoid.configuration.jogStep = modelData
                                }
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            PlasmaComponents3.Label {
                                text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Speed: %1%",
                                    (speedFactor * 100).toFixed(0))
                            }
                            PlasmaComponents3.Label {
                                text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Flow: %1%",
                                    (flowFactor * 100).toFixed(0))
                            }
                            PlasmaComponents3.Label {
                                text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Fan: %1%",
                                    (fanSpeed * 100).toFixed(0))
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


                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents3.Label {
                            text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Files")
                            opacity: 0.7
                        }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents3.Button {
                            text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Refresh files")
                            icon.name: "view-refresh"
                            onClicked: refreshFiles()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        PlasmaComponents3.ComboBox {
                            id: fileCombo
                            Layout.fillWidth: true
                            model: gcodeFiles
                            currentIndex: gcodeFiles.indexOf(selectedFile)
                            onActivated: selectedFile = gcodeFiles[currentIndex]
                            enabled: gcodeFiles.length > 0
                        }

                        PlasmaComponents3.Button {
                            text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Start")
                            icon.name: "media-playback-start"
                            enabled: gcodeFiles.length > 0
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
                        visible: gcodeFiles.length === 0
                        text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "No files found on virtual SD card.")
                        opacity: 0.7
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
                enabled: isEnabled()
                opacity: isEnabled() ? 1.0 : 0.35
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
