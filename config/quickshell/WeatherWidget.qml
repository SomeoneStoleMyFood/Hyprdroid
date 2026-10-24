import QtQuick
import QtQuick.Layouts

// Weather from wttr.in (set the city in config.json: weather.city). Tap to refresh.
Rectangle {
    id: w
    required property var shell
    Layout.alignment: Qt.AlignTop
    radius: 28
    color: shell.primaryContainer
    implicitHeight: 112

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 16
        Glyph { shell: w.shell; name: "cloud"; size: 52; color: w.shell.textColor }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                text: w.shell.weatherTemp !== "" ? w.shell.weatherTemp : "--"
                color: w.shell.textColor
                font.family: w.shell.cv("bar.clockFont", w.shell.fontFamily)
                font.pixelSize: 42
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: w.shell.weatherDesc !== "" ? w.shell.weatherDesc : "Weather unavailable"
                elide: Text.ElideRight
                color: w.shell.textColor
                font.family: w.shell.fontFamily
                font.pixelSize: 15
            }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.shell.refreshWeather() }
}
