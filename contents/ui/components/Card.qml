// SPDX-FileCopyrightText: 2025 Marco Gaib - mgdev72@gmail.com
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami

Rectangle {
    id: root

    default property alias contentData: content.data

    property alias title: titleLabel.text
    property bool titleVisible: titleLabel.text.length > 0
    property int padding: Kirigami.Units.mediumSpacing
    property Item contentItem: content

    radius: Kirigami.Units.largeSpacing
    color: Qt.rgba(PlasmaCore.Theme.backgroundColor.r, PlasmaCore.Theme.backgroundColor.g, PlasmaCore.Theme.backgroundColor.b, 0.85)
    border.color: Qt.rgba(PlasmaCore.Theme.textColor.r, PlasmaCore.Theme.textColor.g, PlasmaCore.Theme.textColor.b, 0.12)
    border.width: 1

    implicitHeight: layout.implicitHeight + padding * 2

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents3.Label {
            id: titleLabel
            Layout.fillWidth: true
            visible: root.titleVisible
            font.weight: Font.DemiBold
            opacity: 0.85
            elide: Text.ElideRight
        }

        ColumnLayout {
            id: content
            Layout.fillWidth: true
            spacing: 0
        }
    }
}
