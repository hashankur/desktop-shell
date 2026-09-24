pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs.config
import qs.services
import "FuzzyMatcher.js" as Fuzzy

QtObject {
    id: root

    readonly property string modeName: "apps"
    readonly property string iconSource: "system-search-symbolic"
    readonly property string placeholderText: "Search applications..."
    readonly property int maxVisibleEntries: 5
    readonly property int entryHeight: 64

    property var foundEntries: []

    function refresh() {
    }

    function _toDisplayEntry(app) {
        return {
            primaryText: app.name,
            secondaryText: app.comment ?? app.name,
            iconSource: app.icon ?? "",
            thumbnailSource: "",
            hintText: "",
            _desktopEntry: app,
            _desktopId: app.id ?? "",
            _pinned: AppLibrary.isPinned(app.id ?? "")
        };
    }

    function filter(query) {
        var trimmed = query.toLowerCase().trim();
        if (trimmed === "") {
            // Empty query: pinned apps first, then recents.
            root.foundEntries = AppLibrary.pinnedEntries().concat(AppLibrary.recentEntries()).map(function (app) {
                return root._toDisplayEntry(app);
            });
            return;
        }
        var all = DesktopEntries.applications.values;
        var scored = [];
        for (var i = 0; i < all.length; i++) {
            var app = all[i];
            var nameScore = Fuzzy.fuzzyScore(trimmed, app.name);
            var commentScore = Fuzzy.fuzzyScore(trimmed, app.comment ?? "");
            var best = Math.max(nameScore, commentScore);
            if (best >= 0) {
                scored.push({
                    app: app,
                    score: best
                });
            }
        }
        scored.sort(function (a, b) {
            return b.score - a.score;
        });
        var filtered = scored.slice(0, root.maxVisibleEntries);
        root.foundEntries = filtered.map(function (item) {
            return root._toDisplayEntry(item.app);
        });
    }

    function activate(index) {
        if (index < 0 || index >= root.foundEntries.length)
            return;
        const entry = root.foundEntries[index];
        AppLibrary.recordLaunch(entry._desktopId);
        entry._desktopEntry.execute();
    }

    function reset() {
        root.foundEntries = [];
    }
}
