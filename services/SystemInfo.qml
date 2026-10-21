pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Slow-moving system readouts for the Status tab. Everything here is
// gated on `active` (the tab being on screen): `top` is a 1 s child
// process and nothing else in the shell needs these numbers.
Singleton {
    id: root

    property bool active: false

    property real netDown: 0
    property real netUp: 0
    property real uptimeSeconds: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property var topProcesses: []

    readonly property real diskUsage: diskTotal > 0 ? diskUsed / diskTotal : 0

    property var _prevNet: null
    property int _tick: 0

    onActiveChanged: {
        // A stale baseline would turn the gap since the last visit into one
        // enormous bogus rate.
        root._prevNet = null;
        root._tick = 0;
    }

    function _poll() {
        netFile.reload();
        uptimeFile.reload();
        if (!topProc.running)
            topProc.running = true;
        if (root._tick % 10 === 0 && !dfProc.running)
            dfProc.running = true;
        root._tick++;
    }

    Timer {
        running: root.active
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: root._poll()
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"

        onLoaded: {
            let rx = 0;
            let tx = 0;
            for (const line of netFile.text().split("\n").slice(2)) {
                const parts = line.trim().split(/[:\s]+/);
                if (parts.length < 10 || parts[0] === "lo")
                    continue;
                rx += parseInt(parts[1]) || 0;
                tx += parseInt(parts[9]) || 0;
            }
            const now = Date.now();
            const prev = root._prevNet;
            if (prev && now > prev.t) {
                const dt = (now - prev.t) / 1000;
                root.netDown = Math.max(0, (rx - prev.rx) / dt);
                root.netUp = Math.max(0, (tx - prev.tx) / dt);
            }
            root._prevNet = {
                rx: rx,
                tx: tx,
                t: now
            };
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptimeSeconds = parseFloat(uptimeFile.text().split(" ")[0]) || 0
    }

    Process {
        id: dfProc
        command: ["df", "-P", "-B1", "/"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                if (lines.length < 2)
                    return;
                const f = lines[1].trim().split(/\s+/);
                root.diskTotal = parseFloat(f[1]) || 0;
                root.diskUsed = parseFloat(f[2]) || 0;
            }
        }
    }

    // Two iterations: the first one reports lifetime averages, only the
    // second is a real instantaneous %CPU. LC_ALL=C pins the decimal point.
    Process {
        id: topProc
        command: ["sh", "-c", "LC_ALL=C top -b -n 2 -d 1 -w 512 -o %CPU"]

        stdout: StdioCollector {
            onStreamFinished: {
                const chunks = this.text.split(/^top - /m);
                const lines = chunks[chunks.length - 1].split("\n");
                const head = lines.findIndex(l => /^\s*PID\s/.test(l));
                if (head < 0)
                    return;
                const rows = [];
                for (const line of lines.slice(head + 1)) {
                    const f = line.trim().split(/\s+/);
                    if (f.length < 12)
                        continue;
                    const name = f.slice(11).join(" ");
                    if (name === "top")
                        continue;
                    rows.push({
                        name: name,
                        cpu: parseFloat(f[8]) || 0,
                        mem: parseFloat(f[9]) || 0
                    });
                    if (rows.length === 4)
                        break;
                }
                root.topProcesses = rows;
            }
        }
    }
}
