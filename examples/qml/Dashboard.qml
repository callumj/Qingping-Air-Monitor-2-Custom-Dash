import QtQuick 2.12
import QtQuick.Window 2.12
import "."

Window {
    id: root
    visible: true
    width: 720
    height: 720
    color: "#050505"

    property string stateFile: "file:///userdata/qt-kiosk/state.json"
    property string currentTime: Qt.formatTime(new Date(), "h:mm AP")
    property string roomTemp: "--"
    property string humidity: "--"
    property string co2: "--"
    property string outdoorTemp: "--"
    property string outdoorHumidity: "--"
    property string waterTemp: "--"
    property string weather: "unknown"
    property string lightState: "unknown"
    property string forecast1Label: "Evening"
    property string forecast1Temp: "--"
    property string forecast1Condition: "cloudy"
    property string forecast2Label: "Morning"
    property string forecast2Temp: "--"
    property string forecast2Condition: "cloudy"
    property string forecast3Label: "Midday"
    property string forecast3Temp: "--"
    property string forecast3Condition: "cloudy"
    property bool snapshotAvailable: false
    property bool showSnapshot: false
    property string snapshotCapturedLocal: ""
    property string snapshotSource: ""

    readonly property color paper: "#f4efe4"
    readonly property color muted: "#9e988b"
    readonly property color line: "#2b2a24"
    readonly property color brass: "#c49a45"
    readonly property color moss: "#9ca36d"
    readonly property color panel: "#0d0d0a"

    function loadState() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    roomTemp = String(data.roomTemp || roomTemp);
                    humidity = String(data.humidity || humidity);
                    co2 = String(data.co2 || co2);
                    outdoorTemp = String(data.outdoorTemp || outdoorTemp);
                    outdoorHumidity = String(data.outdoorHumidity || outdoorHumidity);
                    waterTemp = String(data.waterTemp || waterTemp);
                    weather = String(data.weather || weather);
                    lightState = String(data.lightState || lightState);
                    forecast1Label = String(data.forecast1Label || forecast1Label);
                    forecast1Temp = String(data.forecast1Temp || forecast1Temp);
                    forecast1Condition = String(data.forecast1Condition || forecast1Condition);
                    forecast2Label = String(data.forecast2Label || forecast2Label);
                    forecast2Temp = String(data.forecast2Temp || forecast2Temp);
                    forecast2Condition = String(data.forecast2Condition || forecast2Condition);
                    forecast3Label = String(data.forecast3Label || forecast3Label);
                    forecast3Temp = String(data.forecast3Temp || forecast3Temp);
                    forecast3Condition = String(data.forecast3Condition || forecast3Condition);
                    snapshotAvailable = data.snapshotAvailable === true;
                    snapshotCapturedLocal = String(data.snapshotCapturedLocal || snapshotCapturedLocal);
                    snapshotSource = snapshotAvailable ? "file:///userdata/qt-kiosk/garden-latest.jpg" : "";
                } catch (e) {
                    // Keep previous values if the updater is mid-write.
                }
            }
        };
        xhr.open("GET", stateFile + "?ts=" + Date.now(), true);
        xhr.send();
    }

    Component.onCompleted: loadState()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: currentTime = Qt.formatTime(new Date(), "h:mm AP")
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: loadState()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: showSnapshot = snapshotAvailable ? !showSnapshot : false
    }

    Rectangle {
        visible: !showSnapshot || !snapshotAvailable
        anchors.fill: parent
        color: "#050505"

        Item {
            anchors.fill: parent
            anchors.margins: 18

            Rectangle {
                id: clockBox
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 128
                radius: 4
                color: "#0b0b08"
                border.color: line
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: currentTime
                    color: paper
                    font.pixelSize: 104
                    font.bold: true
                }
            }

            Row {
                id: mainRow
                anchors.top: clockBox.bottom
                anchors.topMargin: 18
                anchors.left: parent.left
                anchors.right: parent.right
                height: 352
                spacing: 18

                Rectangle {
                    width: 328
                    height: parent.height
                    radius: 6
                    color: panel
                    border.color: line
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 16

                        Text { text: "ROOM"; color: moss; font.pixelSize: 14; font.bold: true }
                        Row {
                            spacing: 6
                            Text { text: roomTemp; color: paper; font.pixelSize: 106; font.family: "serif" }
                            Text { text: "\u00b0"; color: paper; font.pixelSize: 42; y: 14 }
                        }
                        Rectangle { width: parent.width; height: 1; color: line }
                        Row {
                            spacing: 12
                            Metric { label: "HUMIDITY"; value: humidity + "%"; accent: root.moss }
                            Metric { label: "CO2"; value: co2 + " ppm"; accent: root.brass }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - 346
                    height: parent.height
                    radius: 6
                    color: "#0a0a08"
                    border.color: line
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 16

                        Text { text: "OUTSIDE"; color: brass; font.pixelSize: 17; font.bold: true }
                        Row {
                            width: parent.width
                            height: 126
                            spacing: 16
                            WeatherGlyph {
                                width: 104
                                height: 104
                                anchors.verticalCenter: parent.verticalCenter
                                    condition: weather
                                    ink: paper
                                    accent: brass
                                    muted: root.muted
                                }
                            Column {
                                width: parent.width - 120
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Text { width: parent.width; text: outdoorTemp + "\u00b0"; color: paper; font.pixelSize: 78; font.bold: true }
                                Text { width: parent.width; text: outdoorHumidity + "% humidity"; color: muted; font.pixelSize: 24; font.bold: true }
                            }
                        }
                        ForecastRow { label: forecast1Label; temp: forecast1Temp; condition: forecast1Condition; paper: root.paper; muted: root.muted; brass: root.brass }
                        ForecastRow { label: forecast2Label; temp: forecast2Temp; condition: forecast2Condition; paper: root.paper; muted: root.muted; brass: root.brass }
                        ForecastRow { label: forecast3Label; temp: forecast3Temp; condition: forecast3Condition; paper: root.paper; muted: root.muted; brass: root.brass }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: mainRow.bottom
                anchors.topMargin: 18
                height: 152
                radius: 6
                color: "#0c0c09"
                border.color: line
                border.width: 1

                Row {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 6
                        Text { text: "LIGHTS"; color: muted; font.pixelSize: 18; font.bold: true }
                        Text { text: lightState; color: paper; font.pixelSize: 45; font.bold: true }
                    }
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 6
                        Text { text: "WATER"; color: muted; font.pixelSize: 18; font.bold: true }
                        Text { text: waterTemp + "\u00b0"; color: paper; font.pixelSize: 45; font.bold: true }
                    }
                }
            }
        }
    }

    Rectangle {
        visible: showSnapshot && snapshotAvailable
        anchors.fill: parent
        color: "#050505"

        Image {
            anchors.fill: parent
            source: snapshotSource
            sourceSize.height: 720
            cache: false
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 84
            color: "#b3050505"

            Text {
                anchors.centerIn: parent
                text: snapshotCapturedLocal
                color: paper
                font.pixelSize: 24
                font.bold: true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 10
        onClicked: {
            if (snapshotAvailable) showSnapshot = !showSnapshot;
        }
    }

}
