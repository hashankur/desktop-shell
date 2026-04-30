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

    // Reference Counting: Only monitor when UI is visible
    function addRef() {
        refCount++;
    }

    function removeRef() {
        refCount = Math.max(0, refCount - 1);
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
        path: "/sys/class/hwmon/hwmon6/device/gpu_busy_percent"

        onLoaded: {
            const gpuRaw = parseInt(gpuStat.text().trim());
            root.gpuUsage = gpuRaw / 100;
        }
    }

    FileView {
        id: tempStat
        path: "/sys/class/thermal/thermal_zone0/temp"

        onLoaded: {
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
            gpuStat.reload();
            tempStat.reload();
        }
    }
}
