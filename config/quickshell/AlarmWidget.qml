import QtQuick
import QtQuick.Layouts

// Alarm list: set the time with the arrows (hold to repeat), switch on/off, daily or once.
Rectangle {
    id: w
    required property var shell
    Layout.alignment: Qt.AlignTop
    radius: 28
    color: shell.container
    implicitHeight: col.implicitHeight + 32

    // arrow that repeats while held
    component Hold: Rectangle {
        id: h
        property bool up: true
        signal fire()
        implicitWidth: 44; implicitHeight: 22; radius: 11
        color: hm.pressed ? w.shell.tileActive : "transparent"
        Glyph { anchors.centerIn: parent; shell: w.shell; name: "expand_more"; size: 20; color: w.shell.textColor; rotation: h.up ? 180 : 0 }
        MouseArea {
            id: hm
            anchors.fill: parent
            onPressed: { h.fire(); first.restart() }
            onReleased: { first.stop(); rep.stop() }
            onCanceled: { first.stop(); rep.stop() }
        }
        Timer { id: first; interval: 420; onTriggered: rep.start() }
        Timer { id: rep; interval: 80; repeat: true; onTriggered: h.fire() }
    }
    component Digits: ColumnLayout {
        id: d
        property int value: 0
        property int max: 24
        signal changed(int v)
        spacing: 0
        Hold { up: true; onFire: d.changed((d.value + 1) % d.max) }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: w.shell.pad2(d.value)
            color: w.shell.textColor
            font.family: w.shell.cv("bar.clockFont", w.shell.fontFamily)
            font.pixelSize: 30
            font.weight: Font.Bold
        }
        Hold { up: false; onFire: d.changed((d.value + d.max - 1) % d.max) }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            spacing: 10
            Glyph { shell: w.shell; name: "alarm"; size: 22; color: w.shell.textColor }
            Text { text: "Alarms"; color: w.shell.textColor; font.family: w.shell.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            Text {
                readonly property string nx: w.shell.nextAlarmText(w.shell.nowDate)
                text: nx !== "" ? "Next " + nx : "None set"
                color: w.shell.textColor
                font.family: w.shell.fontFamily
                font.pixelSize: 13
            }
        }

        Repeater {
            model: w.shell.alarms
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property int hh: parseInt(modelData.time.split(":")[0])
                readonly property int mm: parseInt(modelData.time.split(":")[1])
                Layout.fillWidth: true
                implicitHeight: 82
                radius: 24
                color: w.shell.containerHigh
                opacity: modelData.enabled ? 1 : 0.6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 6
                    Digits { value: row.hh; max: 24; onChanged: v => w.shell.updateAlarm(row.modelData.id, { time: w.shell.pad2(v) + ":" + w.shell.pad2(row.mm), lastFired: "" }) }
                    Text { text: ":"; color: w.shell.textColor; font.pixelSize: 28; font.weight: Font.Bold }
                    Digits { value: row.mm; max: 60; onChanged: v => w.shell.updateAlarm(row.modelData.id, { time: w.shell.pad2(row.hh) + ":" + w.shell.pad2(v), lastFired: "" }) }
                    Item { Layout.fillWidth: true }

                    // daily / once
                    Rectangle {
                        implicitHeight: 32
                        implicitWidth: dl.implicitWidth + 24
                        radius: 16
                        color: row.modelData.daily ? w.shell.tileActive : "#5A5F6B"
                        Text { id: dl; anchors.centerIn: parent; text: row.modelData.daily ? "Daily" : "Once"; color: w.shell.textColor; font.family: w.shell.fontFamily; font.pixelSize: 13; font.weight: Font.Medium }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.shell.updateAlarm(row.modelData.id, { daily: !row.modelData.daily }) }
                    }
                    // on / off switch
                    Rectangle {
                        implicitWidth: 56; implicitHeight: 32; radius: 16
                        color: row.modelData.enabled ? w.shell.tileActive : "#5A5F6B"
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Rectangle {
                            width: 24; height: 24; radius: 12; color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                            x: row.modelData.enabled ? parent.width - width - 4 : 4
                            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.shell.updateAlarm(row.modelData.id, { enabled: !row.modelData.enabled, lastFired: "" }) }
                    }
                    // delete
                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34; radius: 17
                        color: dm.pressed ? "#B3261E" : "transparent"
                        Glyph { anchors.centerIn: parent; shell: w.shell; name: "close"; size: 18; color: w.shell.textColor }
                        MouseArea { id: dm; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.shell.removeAlarm(row.modelData.id) }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 46
            radius: addM.pressed ? 14 : 23
            Behavior on radius { NumberAnimation { duration: 160 } }
            color: w.shell.tileActive
            RowLayout {
                anchors.centerIn: parent
                spacing: 8
                Glyph { shell: w.shell; name: "add"; size: 20; color: w.shell.textColor }
                Text { text: "Add alarm"; color: w.shell.textColor; font.family: w.shell.fontFamily; font.pixelSize: 15; font.weight: Font.Medium }
            }
            MouseArea {
                id: addM
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const d = new Date(Date.now() + 3600000)
                    w.shell.addAlarm(w.shell.pad2(d.getHours()) + ":00", "", false, false)
                }
            }
        }
    }
}
