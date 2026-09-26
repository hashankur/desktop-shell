pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components
import qs.config

ColumnLayout {
    id: root

    property string label: ""
    property real value: 0 // 0-1, current value shown in the header
    property var history: [] // 0-1 samples, oldest first
    property string detail: `${Math.round(root.value * 100)}%`
    property bool available: true
    property color lineColor: Appearance.colors.primary

    // Visible sample window. Spacing is derived ONLY from this constant and
    // the plot width, never from the current sample count — lines scroll in
    // from the right instead of rescaling on every sample (Ambxst pattern).
    readonly property int windowSize: 60

    visible: available
    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            text: root.label
            font.pixelSize: Appearance.fontSize.base
            font.weight: Font.DemiBold
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            text: root.detail
            color: Appearance.colors.on_surface_variant
            font.pixelSize: Appearance.fontSize.sm
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 88
        radius: Appearance.rounding.normal
        color: Appearance.colors.surface_container

        Canvas {
            id: canvas
            anchors.fill: parent

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                const w = width;
                const h = height;
                ctx.clearRect(0, 0, w, h);

                const pad = 8;
                const plotW = w - 2 * pad;
                const plotH = h - 2 * pad;
                if (plotW <= 0 || plotH <= 0)
                    return;

                // Static grid — never moves, so scrolling data reads cleanly.
                ctx.strokeStyle = Appearance.colors.surface_container_high;
                ctx.lineWidth = 1;
                for (let g = 1; g < 4; g++) {
                    const y = Math.round(pad + (g / 4) * plotH) + 0.5;
                    ctx.beginPath();
                    ctx.moveTo(pad, y);
                    ctx.lineTo(w - pad, y);
                    ctx.stroke();
                }

                const hist = root.history;
                if (!hist || hist.length === 0)
                    return;

                const count = Math.min(hist.length, root.windowSize);
                const spacing = plotW / (root.windowSize - 1);
                const rightX = w - pad;
                const start = hist.length - count;
                const xAt = i => rightX - (count - 1 - i) * spacing;
                const yAt = v => h - pad - Math.max(0, Math.min(1, v)) * plotH;

                // First sample: a dot at the right edge.
                if (count === 1) {
                    ctx.fillStyle = root.lineColor;
                    ctx.beginPath();
                    ctx.arc(rightX, yAt(hist[start]), 3, 0, 2 * Math.PI);
                    ctx.fill();
                    return;
                }

                const c = root.lineColor;

                // Gradient area fill under the line
                const grad = ctx.createLinearGradient(0, pad, 0, h - pad);
                grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.35));
                grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.0));
                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.moveTo(xAt(0), h - pad);
                for (let i = 0; i < count; i++)
                    ctx.lineTo(xAt(i), yAt(hist[start + i]));
                ctx.lineTo(xAt(count - 1), h - pad);
                ctx.closePath();
                ctx.fill();

                // Trend line
                ctx.strokeStyle = root.lineColor;
                ctx.lineWidth = 2;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.beginPath();
                for (let i = 0; i < count; i++) {
                    const x = xAt(i);
                    const y = yAt(hist[start + i]);
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }
    }

    Behavior on value {
        NumberAnimation {
            duration: Appearance.anim.durations.large
            easing.bezierCurve: Appearance.anim.curves.standardDecel
        }
    }

    onHistoryChanged: if (root.visible) canvas.requestPaint()
    onVisibleChanged: if (root.visible) canvas.requestPaint()
}
