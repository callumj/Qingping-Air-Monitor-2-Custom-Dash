import QtQuick 2.12
import "."

Row {
    property string label: ""
    property string temp: ""
    property string condition: ""
    property color paper: "#f4efe4"
    property color muted: "#9e988b"
    property color brass: "#c49a45"

    width: parent ? parent.width : 300
    height: 54
    spacing: 10

    WeatherGlyph {
        width: 42
        height: 42
        condition: parent.condition
        ink: paper
        accent: brass
        muted: parent.muted
    }

    Text {
        width: parent.width - 110
        text: label.toUpperCase()
        color: muted
        font.pixelSize: 15
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: temp + "\u00b0"
        color: paper
        font.pixelSize: 28
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
    }
}
