pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import qs.services
import "FuzzyMatcher.js" as Fuzzy

Item {
    id: root
    visible: false

    readonly property string modeName: "clipboard"
    readonly property string iconSource: "edit-paste-symbolic"
    readonly property string placeholderText: "Search clipboard history..."
    readonly property int maxVisibleEntries: 8
    // Taller rows so 48px image previews fit with normal padding.
    readonly property int entryHeight: 76

    property var foundEntries: []

    // Emitted once per decode batch (not per image) so the launcher can
    // refresh the list without rebuilding delegates for every thumbnail.
    signal thumbnailsUpdated

    property var _decodeQueue: []
    property bool _decoding: false
    property var _allEntries: []
    property int _generation: 0
    property int _appliedSinceFlush: 0

    property string searchQuery: ""

    function refresh() {
        Cliphist.refresh();
        // Decoded images are cached indefinitely (cliphist ids are permanent);
        // only prune week-old leftovers. Fire-and-forget.
        Quickshell.execDetached(["sh", "-c", "find /tmp -maxdepth 1 -name 'qs-cliphist-*' -mtime +7 -delete"]);
    }

    function onEntriesChanged() {
        root._allEntries = Cliphist.entries;
        root.filter(root.searchQuery);
    }

    function filter(query) {
        root.searchQuery = query;
        root._generation++;
        root._appliedSinceFlush = 0;
        var trimmed = query.toLowerCase().trim();

        if (trimmed === "") {
            root.foundEntries = root._allEntries.map(function (e) {
                return root._toDisplayEntry(e);
            });
        } else {
            var scored = [];
            for (var i = 0; i < root._allEntries.length; i++) {
                var e = root._allEntries[i];
                var s = Fuzzy.fuzzyScore(trimmed, e.preview);
                if (s >= 0) {
                    scored.push({
                        entry: e,
                        score: s
                    });
                }
            }
            scored.sort(function (a, b) {
                return b.score - a.score;
            });
            var limited = scored.slice(0, root.maxVisibleEntries);
            root.foundEntries = limited.map(function (item) {
                return root._toDisplayEntry(item.entry);
            });
        }

        // Rebuild the queue from the fresh results. A decode left in flight
        // from the previous generation finishes harmlessly: its completion is
        // discarded by generation check before the queue resumes.
        root._decodeQueue = [];
        for (var j = 0; j < root.foundEntries.length; j++) {
            var entry = root.foundEntries[j];
            if (entry._rawType === "image") {
                root._decodeQueue.push(entry);
            }
        }
        root._pump();
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
            secondaryText: "",
            iconSource: "edit-paste-symbolic",
            thumbnailSource: "",
            hintText: "",
            _rawId: raw.id,
            _rawType: raw.type,
            _rawFormat: raw.imageFormat
        };
    }

    function _pump() {
        if (root._decoding)
            return;

        if (root._decodeQueue.length === 0) {
            if (root._appliedSinceFlush > 0) {
                root._appliedSinceFlush = 0;
                root.thumbnailsUpdated();
            }
            return;
        }

        var entry = root._decodeQueue.shift();
        var id = String(entry._rawId);
        var format = String(entry._rawFormat);
        // Defense in depth: both values end up in a `sh -c` command line and
        // in a temp file path, so reject anything not produced by our parser.
        if (!/^\d+$/.test(id) || !/^[A-Za-z0-9]+$/.test(format)) {
            root._pump();
            return;
        }
        root._decoding = true;
        entry._tempPath = `/tmp/qs-cliphist-${id}.${format}`;
        imageDecoder._gen = root._generation;
        imageDecoder._entry = entry;
        // Self-caching: skip the (comparatively expensive) decode when a valid
        // file from a previous session already exists.
        imageDecoder.exec(["sh", "-c", `[ -s '${entry._tempPath}' ] || cliphist decode ${id} > '${entry._tempPath}'`]);
    }

    Process {
        id: imageDecoder
        property int _gen: -1
        property var _entry: null

        onExited: function (exitCode, exitStatus) {
            var stale = imageDecoder._gen !== root._generation;
            var entry = imageDecoder._entry;
            imageDecoder._entry = null;
            root._decoding = false;

            if (!stale && exitCode === 0 && entry !== null) {
                for (var i = 0; i < root.foundEntries.length; i++) {
                    if (root.foundEntries[i]._rawId === entry._rawId) {
                        root.foundEntries[i].thumbnailSource = `file://${entry._tempPath}`;
                        root._appliedSinceFlush++;
                        break;
                    }
                }
            }
            root._pump();
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
        root.searchQuery = "";
    }
}
