// SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string secondary: ""
    property color accent: PlasmaCore.Theme.highlightColor

    radius: Kirigami.Units.largeSpacing
    color: Qt.rgba(PlasmaCore.Theme.backgroundColor.r, PlasmaCore.Theme.backgroundColor.g, PlasmaCore.Theme.backgroundColor.b, 0.55)
    border.color: Qt.rgba(PlasmaCore.Theme.textColor.r, PlasmaCore.Theme.textColor.g, PlasmaCore.Theme.textColor.b, 0.12)
    border.width: 1

    implicitHeight: Kirigami.Units.gridUnit * 3

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: 0

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: root.label
            opacity: 0.7
            elide: Text.ElideRight
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            text: root.value
            font.weight: Font.DemiBold
            font.pointSize: PlasmaCore.Theme.defaultFont.pointSize + 1
            elide: Text.ElideRight
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            visible: root.secondary.length > 0
            text: root.secondary
            opacity: 0.65
            elide: Text.ElideRight
        }
    }
}

