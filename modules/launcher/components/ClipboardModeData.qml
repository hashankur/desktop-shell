import QtQuick
import Quickshell
import Quickshell.Io

import qs.config
import qs.services

Item {
    id: root
    visible: false

    readonly property string modeName: "clipboard"
    readonly property string iconSource: "edit-paste-symbolic"
    readonly property string placeholderText: "Search clipboard history..."
    readonly property int maxVisibleEntries: 8

    property var foundEntries: []

    property var _decodeQueue: []
    property var _decoding: false
    property var _allEntries: []

    function refresh() {
        Cliphist.refresh();
    }

    function onEntriesChanged() {
        root._allEntries = Cliphist.entries;
        root.filter(searchQuery);
    }

    property string searchQuery: ""

    function filter(query) {
        root.searchQuery = query;
        var trimmed = query.toLowerCase().trim();

        if (trimmed === "") {
            root.foundEntries = root._allEntries.map(function (e) {
                return root._toDisplayEntry(e);
            });
        } else {
            var filtered = [];
            for (var i = 0; i < root._allEntries.length; i++) {
                var e = root._allEntries[i];
                if (e.preview.toLowerCase().includes(trimmed)) {
                    filtered.push(e);
                    if (filtered.length >= root.maxVisibleEntries)
                        break;
                }
            }
            root.foundEntries = filtered.map(function (e) {
                return root._toDisplayEntry(e);
            });
        }

        root._decodeQueue = [];
        root._decoding = false;

        for (var j = 0; j < root.foundEntries.length; j++) {
            var entry = root.foundEntries[j];
            if (entry._rawType === "image") {
                root._decodeQueue.push(entry);
            }
        }
        root._processDecodeQueue();
    }

    function _toDisplayEntry(raw) {
        if (raw.type === "image") {
            return {
                primaryText: `${raw.imageFormat.toUpperCase()} Image — ${raw.imageWidth}×${raw.imageHeight}`,
                secondaryText: raw.preview,
                iconSource: "",
                thumbnailSource: "",
                hintText: "",
                _rawId: raw.id,
                _rawType: raw.type,
                _rawFormat: raw.imageFormat
            };
        }

        return {
            primaryText: raw.preview,
            iconSource: "edit-paste-symbolic",
            thumbnailSource: "",
            hintText: "",
            _rawId: raw.id,
            _rawType: raw.type,
            _rawFormat: raw.imageFormat
        };
    }

    function _processDecodeQueue() {
        if (root._decoding || root._decodeQueue.length === 0)
            return;
        root._decoding = true;
        var entry = root._decodeQueue.shift();
        var path = `/tmp/qs-cliphist-${entry._rawId}.${entry._rawFormat}`;
        entry._tempPath = path;
        imageDecoder._pendingEntry = entry;
        imageDecoder.exec(["sh", "-c", `cliphist decode ${entry._rawId} > ${path}`]);
    }

    Process {
        id: imageDecoder
        property var _pendingEntry: null

        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0 && imageDecoder._pendingEntry) {
                var entry = imageDecoder._pendingEntry;
                for (var i = 0; i < root.foundEntries.length; i++) {
                    if (root.foundEntries[i]._rawId === entry._rawId) {
                        root.foundEntries[i].thumbnailSource = `file://${entry._tempPath}`;
                        break;
                    }
                }
            }
            imageDecoder._pendingEntry = null;
            root._decoding = false;
            root._processDecodeQueue();
        }
    }

    function activate(index) {
        if (index < 0 || index >= root.foundEntries.length)
            return;
        var entry = root.foundEntries[index];
        Cliphist.copyEntry(entry._rawId);
    }

    function reset() {
        root.foundEntries = [];
        root._decodeQueue = [];
        root._decoding = false;
        root.searchQuery = "";
    }

    function cleanTempFiles() {
        for (var i = 0; i < root._allEntries.length; i++) {
            var raw = root._allEntries[i];
            if (raw.type === "image") {
                Quickshell.execDetached(["sh", "-c", `rm -f /tmp/qs-cliphist-${raw.id}.${raw.imageFormat}`]);
            }
        }
    }
}
