pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: root

    property int pollInterval: 3000  // milliseconds
    property int refCount: 0  // Track active UI components for reference counting

    property real cpuUsage: 0
    property real memoryUsage: 0
    property real gpuUsage: 0
    property real temperature: 0

    property var prevCpuStats: null

    // Discovered hardware paths
    property string _gpuBusyPath: ""
    property string _thermalTempPath: ""

    // Reference Counting: Only monitor when UI is visible
    function addRef() {
        refCount++;
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1);
    }

    // Discover hardware paths at startup
    Process {
        id: discoverProc
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ -f \"$d/device/gpu_busy_percent\" ] && echo \"$d/device/gpu_busy_percent\" && break; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim();
                if (path.length > 0) {
                    root._gpuBusyPath = path;
                    gpuStat.reload();
                }
            }
        }
    }

    Process {
        id: discoverThermalProc
        command: ["sh", "-c", "for d in /sys/class/thermal/thermal_zone*/temp; do [ -f \"$d\" ] && echo \"$d\" && break; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim();
                if (path.length > 0) {
                    root._thermalTempPath = path;
                    tempStat.reload();
                }
            }
        }
    }

    // CPU Monitoring
    FileView {
        id: cpuStat
        path: "/proc/stat"

        onLoaded: {
            const lines = cpuStat.text().split("\n");
            if (lines.length > 0 && lines[0].startsWith("cpu ")) {
                const parts = lines[0].trim().split(/\s+/);
                if (parts.length >= 8) {
                    const user = parseInt(parts[1]);
                    const nice = parseInt(parts[2]);
                    const system = parseInt(parts[3]);
                    const idle = parseInt(parts[4]);
                    const iowait = parseInt(parts[5]) || 0;
                    const irq = parseInt(parts[6]) || 0;
                    const softirq = parseInt(parts[7]) || 0;

                    const totalTime = user + nice + system + idle + iowait + irq + softirq;
                    const activeTime = user + nice + system + irq + softirq;

                    if (root.prevCpuStats !== null) {
                        const totalDelta = totalTime - root.prevCpuStats.total;
                        const activeDelta = activeTime - root.prevCpuStats.active;

                        if (totalDelta > 0) {
                            root.cpuUsage = Math.max(0, Math.min(1, activeDelta / totalDelta));
                        }
                    }

                    root.prevCpuStats = {
                        total: totalTime,
                        active: activeTime
                    };
                }
            }
        }
    }

    // Memory Monitoring
    FileView {
        id: memStat
        path: "/proc/meminfo"

        onLoaded: {
            const lines = memStat.text().split("\n");
            let memTotal = 0;
            let memAvailable = 0;

            for (const line of lines) {
                if (line.startsWith("MemTotal:")) {
                    memTotal = parseInt(line.split(/\s+/)[1]);
                } else if (line.startsWith("MemAvailable:")) {
                    memAvailable = parseInt(line.split(/\s+/)[1]);
                }
            }

            if (memTotal > 0 && memAvailable >= 0) {
                root.memoryUsage = Math.max(0, Math.min(1, (memTotal - memAvailable) / memTotal));
            }
        }
    }

    FileView {
        id: gpuStat
        path: root._gpuBusyPath

        onLoaded: {
            if (root._gpuBusyPath === "") return;
            const gpuRaw = parseInt(gpuStat.text().trim());
            root.gpuUsage = gpuRaw / 100;
        }
    }

    FileView {
        id: tempStat
        path: root._thermalTempPath

        onLoaded: {
            if (root._thermalTempPath === "") return;
            const tempRaw = parseInt(tempStat.text().trim());
            root.temperature = tempRaw / 1000 / 100;
        }
    }

    // Polling Timer: Only active when UI components are present
    Timer {
        id: pollTimer
        running: root.refCount > 0
        interval: root.pollInterval
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            cpuStat.reload();
            memStat.reload();
            if (root._gpuBusyPath !== "") gpuStat.reload();
            if (root._thermalTempPath !== "") tempStat.reload();
        }
    }
}
