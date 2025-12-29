// SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property real cfg_jogStep
    property alias cfg_jogFeedXY: jogFeedXYField.value
    property alias cfg_jogFeedZ: jogFeedZField.value

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Jogging")
        }

        QQC2.SpinBox {
            id: jogStepField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Step (mm):")
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
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Feedrate XY (mm/min):")
            from: 0
            to: 30000
            stepSize: 100
            editable: true
        }

        QQC2.SpinBox {
            id: jogFeedZField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Feedrate Z (mm/min):")
            from: 0
            to: 6000
            stepSize: 50
            editable: true
        }
    }

    onCfg_jogStepChanged: {
        if (isNaN(cfg_jogStep)) {
            return
        }
        jogStepField.value = Math.round(cfg_jogStep * 10)
    }
}

