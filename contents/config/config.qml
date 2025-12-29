// SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Connection")
        icon: "network-connect"
        source: "configConnection.qml"
    }

    ConfigCategory {
        name: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Controls")
        icon: "input-mouse"
        source: "configControls.qml"
    }

    ConfigCategory {
        name: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Printing")
        icon: "printer"
        source: "configPrinting.qml"
    }

    ConfigCategory {
        name: i18nd("plasma_applet_org.kde.plasma.klippermonitor", "Interface")
        icon: "preferences-desktop-locale"
        source: "configInterface.qml"
    }
}
