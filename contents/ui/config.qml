import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property alias cfg_host: hostField.text
    property alias cfg_port: portField.value
    property alias cfg_useTls: tlsCheckBox.checked
    property alias cfg_apiKey: apiKeyField.text
    property alias cfg_wsPath: wsPathField.text
    property alias cfg_chartIntervalMs: chartIntervalField.value
    property alias cfg_defaultFile: defaultFileField.text
    property string cfg_hostDefault
    property int cfg_portDefault
    property bool cfg_useTlsDefault
    property string cfg_apiKeyDefault
    property string cfg_wsPathDefault
    property int cfg_chartIntervalMsDefault
    property string cfg_defaultFileDefault

    Kirigami.FormLayout {
        QQC2.TextField {
            id: hostField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Moonraker host:")
            placeholderText: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "192.168.0.42")
        }

        QQC2.SpinBox {
            id: portField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Port:")
            from: 0
            to: 65535
            editable: true
        }

        QQC2.CheckBox {
            id: tlsCheckBox
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "TLS:")
            text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Use TLS (wss)")
        }

        QQC2.TextField {
            id: apiKeyField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "API key or token:")
            echoMode: TextInput.Password
            placeholderText: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Optional")
        }

        QQC2.TextField {
            id: wsPathField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "WebSocket path:")
            placeholderText: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "/websocket")
        }

        QQC2.SpinBox {
            id: chartIntervalField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Chart interval (ms):")
            from: 250
            to: 10000
            stepSize: 250
            editable: true
        }

        QQC2.TextField {
            id: defaultFileField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Default file to start:")
            placeholderText: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "filename.gcode")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.Button {
            text: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Clear settings")
            onClicked: {
                hostField.text = ""
                portField.value = 0
                tlsCheckBox.checked = false
                apiKeyField.text = ""
                wsPathField.text = "/websocket"
                chartIntervalField.value = 1000
                defaultFileField.text = ""
            }
        }
    }
}
