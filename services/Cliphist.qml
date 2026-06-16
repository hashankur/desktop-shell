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
    cliphistProc.exec(["sh", "-c", "cliphist list > /tmp/qs-cliphist-list.txt"]);
  }

  function copyEntry(id) {
    Quickshell.execDetached(["sh", "-c", `cliphist decode ${id} | wl-copy`]);
  }

  Process {
    id: cliphistProc
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0) {
        root.loading = false;
        return;
      }
      historyFile.path = "/tmp/qs-cliphist-list.txt";
      historyFile.reload();
    }
  }

  FileView {
    id: historyFile
    onLoaded: {
      root.loading = false;
      var raw = historyFile.text();
      if (raw === "") {
        root.entries = [];
        return;
      }
      var list = [];
      var lines = raw.split("\n").filter(l => l.length > 0);
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var tabIdx = line.indexOf("\t");
        if (tabIdx < 0) continue;
        var id = line.substring(0, tabIdx);
        var preview = line.substring(tabIdx + 1);
        var entry = {
          id: id,
          preview: preview,
          type: "text",
          imageFormat: "",
          imageWidth: 0,
          imageHeight: 0
        };
        var imgMatch = preview.match(/^\[\[ binary data [\d.]+ (?:KiB|B) (\w+) (\d+)x(\d+) \]\]$/);
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
  }
}
