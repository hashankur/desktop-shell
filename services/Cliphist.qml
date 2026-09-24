pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property list<var> entries: []
    property bool loading: false

    function refresh() {
        if (root.loading)
            return;
        root.loading = true;
        cliphistProc.exec(["cliphist", "list"]);
    }

    function copyEntry(id) {
        if (!/^\d+$/.test(String(id)))
            return;
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + String(id) + " | wl-copy"]);
    }

    property var _parsedList: null

    function _parseEntries(raw) {
        if (raw === "") {
            return [];
        }
        const list = [];
        const lines = raw.split("\n").filter(l => l.length > 0);
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const tabIdx = line.indexOf("\t");
            if (tabIdx < 0)
                continue;
            const id = line.substring(0, tabIdx);
            // Only trust numeric ids: everything derived from them (decode
            // commands, temp file paths) must never see arbitrary strings.
            if (!/^\d+$/.test(id))
                continue;
            const preview = line.substring(tabIdx + 1);
            const entry = {
                id: id,
                preview: preview,
                type: "text",
                imageFormat: "",
                imageWidth: 0,
                imageHeight: 0
            };
            const imgMatch = preview.match(/^\[\[ binary data [\d.]+ (?:KiB|B) (\w+) (\d+)x(\d+) \]\]$/);
            if (imgMatch) {
                entry.type = "image";
                entry.imageFormat = imgMatch[1];
                entry.imageWidth = parseInt(imgMatch[2]);
                entry.imageHeight = parseInt(imgMatch[3]);
            }
            list.push(entry);
        }
        return list;
    }

    Process {
        id: cliphistProc
        stdout: StdioCollector {
            id: listCollector
            onStreamFinished: {
                root._parsedList = root._parseEntries(listCollector.text);
            }
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0 && root._parsedList !== null) {
                root.entries = root._parsedList;
            } else if (exitCode !== 0) {
                console.error("Cliphist: `cliphist list` failed with exit code", exitCode);
            }
            root._parsedList = null;
            root.loading = false;
        }
    }
}
