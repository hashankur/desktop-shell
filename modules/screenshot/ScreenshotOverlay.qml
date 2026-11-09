import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs.config

Scope {
    id: root

    property bool active: false
    property int shotId: 0
    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string tmp: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/neue-shot"

    function open() {
        if (root.active || grab.running)
            return;
        root.shotId++;
        grab.running = true;
    }

    function close() {
        root.active = false;
    }

    // Crops the native-resolution grim frame with ImageMagick; scale is
    // image pixels per logical pixel, so fractional output scales stay exact.
    function capture(name, x, y, w, h, scale) {
        const geo = Math.round(w * scale) + "x" + Math.round(h * scale) + "+" + Math.round(x * scale) + "+" + Math.round(y * scale);
        crop.command = ["sh", "-c", "f=\"$1/Screenshot from $(date +'%Y-%m-%d %H-%M-%S').png\"; magick \"$2\" -crop \"$3\" +repage \"$f\" && wl-copy < \"$f\" && notify-send 'Screenshot saved' \"$f\"; rm -f \"$2\"*", "sh", root.dir, root.tmp + "-" + name + ".png", geo];
        root.close();
        crop.running = true;
    }

    // Every output is grabbed before any overlay maps, so the frozen frames
    // can never contain the overlay itself.
    Process {
        id: grab
        command: ["sh", "-c", "mkdir -p \"$1\"; shift; for o in \"$@\"; do grim -o \"$o\" \"" + root.tmp + "-$o.png\" || exit 1; done", "sh", root.dir].concat(Quickshell.screens.map(s => s.name))
        onExited: code => root.active = code === 0
    }

    Process {
        id: crop
    }

    Process {
        id: full
        command: ["sh", "-c", "mkdir -p \"$1\"; f=\"$1/Screenshot from $(date +'%Y-%m-%d %H-%M-%S').png\"; grim \"$f\" && wl-copy < \"$f\" && notify-send 'Screenshot saved' \"$f\"", "sh", root.dir]
    }

    IpcHandler {
        target: "screenshot"

        function region() {
            root.open();
        }

        function screen() {
            full.running = true;
        }

        function cancel() {
            root.close();
        }
    }

    Variants {
        model: root.active ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "neue-screenshot"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            FocusScope {
                id: scope

                property real startX: 0
                property real startY: 0
                property bool dragging: false
                property rect sel: Qt.rect(0, 0, 0, 0)

                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: root.close()

                Image {
                    id: frozen
                    anchors.fill: parent
                    source: "file://" + root.tmp + "-" + win.screen.name + ".png"
                    cache: false
                    asynchronous: false
                    smooth: false
                    fillMode: Image.Stretch
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#66000000"
                    visible: !scope.dragging || scope.sel.width < 1
                }

                Repeater {
                    model: scope.dragging && scope.sel.width >= 1 ? 4 : 0

                    Rectangle {
                        required property int index
                        color: "#66000000"
                        x: index === 3 ? scope.sel.x + scope.sel.width : 0
                        y: index === 0 ? 0 : (index === 1 ? scope.sel.y + scope.sel.height : scope.sel.y)
                        width: index < 2 ? scope.width : (index === 2 ? scope.sel.x : scope.width - scope.sel.x - scope.sel.width)
                        height: index === 0 ? scope.sel.y : (index === 1 ? scope.height - scope.sel.y - scope.sel.height : scope.sel.height)
                    }
                }

                Rectangle {
                    visible: scope.dragging
                    x: scope.sel.x
                    y: scope.sel.y
                    width: scope.sel.width
                    height: scope.sel.height
                    color: "transparent"
                    border.width: 1
                    border.color: Appearance.colors.primary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            root.close();
                            return;
                        }
                        scope.startX = mouse.x;
                        scope.startY = mouse.y;
                        scope.sel = Qt.rect(mouse.x, mouse.y, 0, 0);
                        scope.dragging = true;
                    }

                    onPositionChanged: mouse => {
                        if (!scope.dragging)
                            return;
                        const x = Math.max(0, Math.min(mouse.x, scope.width));
                        const y = Math.max(0, Math.min(mouse.y, scope.height));
                        scope.sel = Qt.rect(Math.min(x, scope.startX), Math.min(y, scope.startY), Math.abs(x - scope.startX), Math.abs(y - scope.startY));
                    }

                    onReleased: mouse => {
                        if (!scope.dragging)
                            return;
                        scope.dragging = false;
                        if (scope.sel.width < 2 || scope.sel.height < 2) {
                            root.close();
                            return;
                        }
                        root.capture(win.screen.name, scope.sel.x, scope.sel.y, scope.sel.width, scope.sel.height, frozen.implicitWidth / scope.width);
                    }
                }
            }
        }
    }
}
