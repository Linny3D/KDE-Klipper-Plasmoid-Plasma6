// SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property alias cfg_defaultFile: defaultFileField.text

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Start File")
        }

        QQC2.TextField {
            id: defaultFileField
            Kirigami.FormData.label: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Default file to start:")
            placeholderText: "filename.gcode"
        }
    }
}

