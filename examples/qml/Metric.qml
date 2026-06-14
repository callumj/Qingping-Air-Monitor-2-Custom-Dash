import QtQuick 2.12

Rectangle {
    property string label: ""
    property string value: ""
    property color accent: "#c49a45"
    property color paper: "#f4efe4"

    width: 132
    height: 92
    radius: 4
    color: "#090908"
    border.color: "#1b1a16"
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 7

        Text {
            text: label
            color: accent
            font.pixelSize: 16
            font.bold: true
        }

        Text {
            text: value
            color: paper
            font.pixelSize: 31
            font.bold: true
        }
    }
}

