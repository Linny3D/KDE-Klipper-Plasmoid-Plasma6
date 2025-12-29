// SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
// SPDX-License-Identifier: GPL-3.0-or-later
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

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Moonraker")
        }

        QQC2.TextField {
            id: hostField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Host:")
            placeholderText: "192.168.0.42"
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

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Authentication")
        }

        QQC2.TextField {
            id: apiKeyField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "API key or token:")
            echoMode: TextInput.Password
            placeholderText: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Optional")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "WebSocket")
        }

        QQC2.TextField {
            id: wsPathField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Path:")
            placeholderText: "/websocket"
        }
    }
}

