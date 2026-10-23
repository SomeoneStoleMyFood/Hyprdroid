import QtQuick
import QtQuick.Shapes

// Icon for the shade: icons/<name>.svg if it exists, otherwise vector shapes drawn by QML.
Item {
    id: g
    required property var shell
    property string name: ""
    property int level: 4              // wifi only: 0..4
    property int size: 22
    property color color: "white"
    implicitWidth: size
    implicitHeight: size

    readonly property var extra: ({
        "brightness": "M20 8.69V4h-4.69L12 .69 8.69 4H4v4.69L.69 12 4 15.31V20h4.69L12 23.31 15.31 20H20v-4.69L23.31 12 20 8.69zM12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6 6 2.69 6 6-2.69 6-6 6zm0-10c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4z",
        "volume_up": "M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z",
        "play": "M8 5v14l11-7z",
        "pause": "M6 19h4V5H6v14zm8-14v14h4V5h-4z",
        "skip_next": "M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z",
        "skip_prev": "M6 6h2v12H6zm3.5 6l8.5 6V6z",
        "saver": "M16 4h-2V2h-4v2H8C7.45 4 7 4.45 7 5v16c0 .55.45 1 1 1h8c.55 0 1-.45 1-1V5c0-.55-.45-1-1-1zm-1 9h-2v2h-2v-2H9v-2h2V9h2v2h2v2z",
        "close": "M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z",
        "clear_all": "M5 13h14v-2H5v2zm-2 4h14v-2H3v2zM7 7v2h14V7H7z",
        "lock": "M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z",
        "sleep": "M12 3c-4.97 0-9 4.03-9 9s4.03 9 9 9 9-4.03 9-9c0-.46-.04-.92-.1-1.36-.98 1.37-2.58 2.26-4.4 2.26-2.98 0-5.4-2.42-5.4-5.4 0-1.81.89-3.42 2.26-4.4-.44-.06-.9-.1-1.36-.1z",
        "restart": "M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z",
        "logout": "M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z",
        "timer": "M15 1H9v2h6V1zm-4 13h2V8h-2v6zm8.03-6.61l1.42-1.42c-.43-.51-.9-.99-1.41-1.41l-1.42 1.42C16.07 4.74 14.12 4 12 4c-4.97 0-9 4.03-9 9s4.02 9 9 9 9-4.03 9-9c0-2.12-.74-4.07-1.97-5.61zM12 20c-3.87 0-7-3.13-7-7s3.13-7 7-7 7 3.13 7 7-3.13 7-7 7z",
        "add": "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z",
        "cloud": "M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96z",
        "speed": "M20.38 8.57l-1.23 1.85a8 8 0 0 1-.22 7.58H5.07A8 8 0 0 1 15.58 6.85l1.85-1.23A10 10 0 0 0 3.35 19a2 2 0 0 0 1.72 1h13.85a2 2 0 0 0 1.74-1 10 10 0 0 0-.27-10.44zm-9.79 6.84a2 2 0 0 0 2.83 0l5.66-8.49-8.49 5.66a2 2 0 0 0 0 2.83z",
        "arrow_forward": "M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8z",
        "expand_more": "M16.59 8.59L12 13.17 7.41 8.59 6 10l6 6 6-6z",
        "power": "M13 3h-2v10h2V3zm4.83 2.17l-1.42 1.42C17.99 7.86 19 9.81 19 12c0 3.87-3.13 7-7 7s-7-3.13-7-7c0-2.19 1.01-4.14 2.58-5.42L6.17 5.17C4.23 6.82 3 9.26 3 12c0 4.97 4.03 9 9 9s9-4.03 9-9c0-2.74-1.23-5.18-3.17-6.83z",
        "settings": "M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"
    })
    readonly property string pathData: g.shell.iconPaths[g.name] || g.extra[g.name] || g.shell.iconPaths["notification"]

    Image {
        id: img
        anchors.fill: parent
        source: Qt.resolvedUrl("icons/" + (g.name === "wifi" ? "wifi_" + g.level : g.name) + ".svg")
        sourceSize: Qt.size(g.size * 2, g.size * 2)
        visible: status === Image.Ready
    }

    Item {
        visible: img.status !== Image.Ready
        width: 24; height: 24
        scale: g.size / 24
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.samples: 4
        layer.textureSize: Qt.size(48, 48)

        Shape {
            visible: g.name !== "wifi"
            width: 24; height: 24
            ShapePath {
                fillColor: g.color
                strokeColor: "transparent"
                fillRule: ShapePath.WindingFill
                PathSvg { path: g.pathData }
            }
        }
        Repeater {
            model: (g.name === "wifi" || g.name === "wifi_off") ? 4 : 0
            delegate: Shape {
                required property int index
                width: 24; height: 24
                opacity: (g.name === "wifi" && index < g.level) ? 1 : 0.3
                ShapePath {
                    fillColor: g.color
                    strokeColor: "transparent"
                    PathSvg { path: g.shell.wifiPaths[index] }
                }
            }
        }
    }
}
