// SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "i18n.js" as I18n

KCM.SimpleKCM {
    id: root

    property alias cfg_chartIntervalMs: chartIntervalField.value
    property string cfg_localeOverride
    property string initialLocaleOverride: ""

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

    function localeIndexForValue(value) {
        for (var i = 0; i < localeField.model.length; i++) {
            if (localeField.model[i].value === value) {
                return i
            }
        }
        return 0
    }

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Charts")
        }

        QQC2.SpinBox {
            id: chartIntervalField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Update interval (ms):")
            from: 250
            to: 10000
            stepSize: 250
            editable: true
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Language")
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
    }

    onCfg_localeOverrideChanged: {
        localeField.currentIndex = localeIndexForValue(cfg_localeOverride)
        if (typeof kcm !== "undefined" && !kcm.needsSave) {
            initialLocaleOverride = cfg_localeOverride
        }
    }
}
