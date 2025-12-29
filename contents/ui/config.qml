// SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "i18n.js" as I18n

KCM.SimpleKCM {
    id: root
    function tr(msgid, arg1, arg2, arg3) {
        var override = cfg_localeOverride
        if (!override) {
            if (arg3 !== undefined) {
                return i18nd("plasma_applet_org.kde.plasma.klippermonitor", msgid, arg1, arg2, arg3)
            }
            if (arg2 !== undefined) {
                return i18nd("plasma_applet_org.kde.plasma.klippermonitor", msgid, arg1, arg2)
            }
            if (arg1 !== undefined) {
                return i18nd("plasma_applet_org.kde.plasma.klippermonitor", msgid, arg1)
            }
            return i18nd("plasma_applet_org.kde.plasma.klippermonitor", msgid)
        }
        return I18n.tr(override, msgid, [arg1, arg2, arg3])
    }

    property alias cfg_host: hostField.text
    property alias cfg_port: portField.value
    property alias cfg_useTls: tlsCheckBox.checked
    property alias cfg_apiKey: apiKeyField.text
    property alias cfg_wsPath: wsPathField.text
    property alias cfg_chartIntervalMs: chartIntervalField.value
    property real cfg_jogStep
    property alias cfg_jogFeedXY: jogFeedXYField.value
    property alias cfg_jogFeedZ: jogFeedZField.value
    property alias cfg_defaultFile: defaultFileField.text
    property string cfg_localeOverride
    property bool cfg_enableConnections
    property string cfg_hostDefault
    property int cfg_portDefault
    property bool cfg_useTlsDefault
    property string cfg_apiKeyDefault
    property string cfg_wsPathDefault
    property int cfg_chartIntervalMsDefault
    property real cfg_jogStepDefault
    property int cfg_jogFeedXYDefault
    property int cfg_jogFeedZDefault
    property string cfg_defaultFileDefault
    property string cfg_localeOverrideDefault
    property bool cfg_enableConnectionsDefault
    property string initialLocaleOverride: ""

    function localeIndexForValue(value) {
        for (var i = 0; i < localeField.model.length; i++) {
            if (localeField.model[i].value === value) {
                return i
            }
        }
        return 0
    }

    Kirigami.FormLayout {
        QQC2.TextField {
            id: hostField
            Kirigami.FormData.label: tr("Moonraker host:")
            placeholderText: tr("192.168.0.42")
        }

        QQC2.SpinBox {
            id: portField
            Kirigami.FormData.label: tr("Port:")
            from: 0
            to: 65535
            editable: true
        }

        QQC2.CheckBox {
            id: tlsCheckBox
            Kirigami.FormData.label: tr("TLS:")
            text: tr("Use TLS (wss)")
        }

        QQC2.TextField {
            id: apiKeyField
            Kirigami.FormData.label: tr("API key or token:")
            echoMode: TextInput.Password
            placeholderText: tr("Optional")
        }

        QQC2.TextField {
            id: wsPathField
            Kirigami.FormData.label: tr("WebSocket path:")
            placeholderText: tr("/websocket")
        }

        QQC2.SpinBox {
            id: chartIntervalField
            Kirigami.FormData.label: tr("Chart interval (ms):")
            from: 250
            to: 10000
            stepSize: 250
            editable: true
        }

        QQC2.SpinBox {
            id: jogStepField
            Kirigami.FormData.label: tr("Jog step (mm):")
            from: 1
            to: 1000
            stepSize: 1
            editable: true
            value: 100
            textFromValue: function(value) {
                return (value / 10).toFixed(1)
            }
            valueFromText: function(text) {
                var parsed = parseFloat(text)
                if (isNaN(parsed)) {
                    return value
                }
                return Math.round(parsed * 10)
            }
            onValueModified: {
                cfg_jogStep = value / 10.0
            }
        }

        QQC2.SpinBox {
            id: jogFeedXYField
            Kirigami.FormData.label: tr("Jog feedrate XY (mm/min):")
            from: 0
            to: 30000
            stepSize: 100
            editable: true
        }

        QQC2.SpinBox {
            id: jogFeedZField
            Kirigami.FormData.label: tr("Jog feedrate Z (mm/min):")
            from: 0
            to: 6000
            stepSize: 50
            editable: true
        }

        QQC2.TextField {
            id: defaultFileField
            Kirigami.FormData.label: tr("Default file to start:")
            placeholderText: tr("filename.gcode")
        }

        QQC2.ComboBox {
            id: localeField
            Kirigami.FormData.label: tr("Language:")
            textRole: "label"
            valueRole: "value"
            model: [
                { label: tr("System language"), value: "" },
                { label: tr("English"), value: "en" },
                { label: tr("German"), value: "de" },
                { label: tr("French"), value: "fr" },
                { label: tr("Italian"), value: "it" },
                { label: tr("Spanish"), value: "es" },
                { label: tr("Dutch"), value: "nl" },
                { label: tr("Portuguese (Brazil)"), value: "pt_BR" }
            ]
            onActivated: {
                cfg_localeOverride = currentValue
                if (typeof kcm !== "undefined" && cfg_localeOverride !== initialLocaleOverride) {
                    kcm.needsSave = true
                }
            }
            Component.onCompleted: {
                currentIndex = localeIndexForValue(cfg_localeOverride)
                initialLocaleOverride = cfg_localeOverride
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Button {
            text: tr("Clear settings")
            onClicked: {
                hostField.text = ""
                portField.value = 0
                tlsCheckBox.checked = false
                apiKeyField.text = ""
                wsPathField.text = "/websocket"
                chartIntervalField.value = 1000
                jogStepField.value = 100
                jogFeedXYField.value = 0
                jogFeedZField.value = 0
                defaultFileField.text = ""
                localeField.currentIndex = 0
                cfg_localeOverride = ""
            }
        }
    }

    onCfg_jogStepChanged: {
        if (isNaN(cfg_jogStep)) {
            return
        }
        jogStepField.value = Math.round(cfg_jogStep * 10)
    }

    onCfg_jogFeedXYChanged: {
        jogFeedXYField.value = cfg_jogFeedXY
    }

    onCfg_jogFeedZChanged: {
        jogFeedZField.value = cfg_jogFeedZ
    }

    onCfg_localeOverrideChanged: {
        localeField.currentIndex = localeIndexForValue(cfg_localeOverride)
    }
}
