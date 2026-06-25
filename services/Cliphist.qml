pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property list<var> entries: []
  property bool loading: false

  function refresh() {
    if (root.loading) return;
    root.loading = true;
    cliphistProc.exec(["cliphist", "list"]);
  }

  function copyEntry(id) {
    if (!/^\d+$/.test(String(id))) return;
    Quickshell.execDetached(["sh", "-c", "cliphist decode " + String(id) + " | wl-copy"]);
  }

  function _parseEntries(raw) {
    if (raw === "") {
      root.entries = [];
      return;
    }
    const list = [];
    const lines = raw.split("\n").filter(l => l.length > 0);
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const tabIdx = line.indexOf("\t");
      if (tabIdx < 0) continue;
      const id = line.substring(0, tabIdx);
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
    root.entries = list;
  }

  Process {
    id: cliphistProc
    stdout: StdioCollector {
      id: listCollector
      onStreamFinished: {
        root._parseEntries(listCollector.text);
        root.loading = false;
      }
    }
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0) {
        root.loading = false;
      }
    }
  }
}
