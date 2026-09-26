pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Spotify serves cover art from a remote CDN, so every track change and
    // every shell restart would otherwise pay a 1-3 s network fetch. Art is
    // downloaded once via XMLHttpRequest (arraybuffer) and persisted with
    // FileView.setData; the Image then loads from file://. Requests are
    // serialized so probe/download callbacks can never be misattributed to a
    // newer track. No pruning (art is ~160 KB per unique album).
    readonly property string cacheDir: `${Quickshell.env("HOME")}/.cache/neue/mpris-art/`
    property string resolvedUrl: ""

    property int _seq: 0
    property bool _busy: false
    property int _activeId: 0
    property string _activeUrl: ""
    property string _activeFile: ""
    property var _queued: null
    property var _memo: ({})
    property var _evicted: ({})
    property bool _dirReady: false
    property bool _dirQueued: false
    property var _pendingWrite: null

    function _hash(s) {
        let h1 = 5381;
        let h2 = 52711;
        for (let i = 0; i < s.length; i++) {
            const c = s.charCodeAt(i);
            h1 = ((h1 << 5) + h1 + c) | 0;
            h2 = (c + (h2 << 6) + (h2 << 16) - h2) | 0;
        }
        return (h1 >>> 0).toString(36) + (h2 >>> 0).toString(36);
    }

    function resolve(url) {
        root._seq++;
        if (!url || (!url.startsWith("http://") && !url.startsWith("https://"))) {
            root._queued = null;
            root.resolvedUrl = url ?? "";
            return;
        }
        if (root._memo[url]) {
            root._queued = null;
            root.resolvedUrl = root._memo[url];
            return;
        }
        const entry = {
            id: root._seq,
            url: url
        };
        if (root._busy)
            root._queued = entry;
        else
            root._start(entry);
    }

    function _start(entry) {
        root._busy = true;
        root._activeId = entry.id;
        root._activeUrl = entry.url;
        root._activeFile = root.cacheDir + root._hash(entry.url) + ".img";
        if (probe.path === root._activeFile)
            probe.reload();
        else
            probe.path = root._activeFile;
    }

    function _done() {
        root._busy = false;
        if (root._queued) {
            const next = root._queued;
            root._queued = null;
            root._start(next);
        }
    }

    function _settle(fileUrl) {
        root._memo[root._activeUrl] = fileUrl;
        if (root._activeId === root._seq)
            root.resolvedUrl = fileUrl;
        root._done();
    }

    function _settleRemote() {
        if (root._activeId === root._seq)
            root.resolvedUrl = root._activeUrl;
        root._done();
    }

    function _download() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", root._activeUrl, true);
        xhr.responseType = "arraybuffer";
        xhr.timeout = 5000;
        xhr.onload = function () {
            if (xhr.status === 200 && xhr.response && xhr.response.byteLength > 0) {
                root._write(xhr.response);
            } else {
                console.error("ArtCache: unexpected status", xhr.status, "for", root._activeUrl);
                root._settleRemote();
            }
        };
        xhr.onerror = function () {
            console.error("ArtCache: download failed for", root._activeUrl);
            root._settleRemote();
        };
        xhr.ontimeout = function () {
            console.error("ArtCache: download timed out for", root._activeUrl);
            root._settleRemote();
        };
        xhr.send();
    }

    function _write(buf) {
        root._pendingWrite = buf;
        if (root._dirReady) {
            root._save(buf);
            return;
        }
        if (!root._dirQueued) {
            root._dirQueued = true;
            mkdirProc.running = true;
        }
    }

    function _save(buf) {
        writer.path = root._activeFile;
        writer.setData(buf);
    }

    // Called from the art Image when a file:// source fails to decode, e.g.
    // after the cache was wiped externally. Re-downloads once per URL; a
    // second failure falls back to the remote URL instead of looping.
    function notifyImageError(source) {
        if (!source.startsWith("file://"))
            return;
        for (const url in root._memo) {
            if (root._memo[url] !== source)
                continue;
            delete root._memo[url];
            if (root._evicted[url])
                return;
            root._evicted[url] = true;
            resolve(url);
            return;
        }
    }

    FileView {
        id: probe
        // A cache miss (missing file) is the normal path, not an error.
        printErrors: false

        onLoaded: {
            if (root._busy)
                root._settle("file://" + root._activeFile);
        }

        onLoadFailed: {
            if (root._busy)
                root._download();
        }
    }

    FileView {
        id: writer

        onSaved: {
            writer.path = "";
            root._settle("file://" + root._activeFile);
        }

        onSaveFailed: function (error) {
            writer.path = "";
            root._settleRemote();
        }
    }

    Process {
        id: mkdirProc
        command: ["mkdir", "-p", root.cacheDir]

        onExited: function (exitCode) {
            root._dirQueued = false;
            const buf = root._pendingWrite;
            root._pendingWrite = null;
            if (exitCode !== 0) {
                console.error("ArtCache: mkdir -p failed with exit code", exitCode);
                if (buf)
                    root._settleRemote();
                return;
            }
            root._dirReady = true;
            if (buf)
                root._save(buf);
        }
    }
}
