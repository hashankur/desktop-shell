pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs.config
import "FuzzyMatcher.js" as Fuzzy

QtObject {
  id: root

  readonly property string modeName: "apps"
  readonly property string iconSource: "system-search-symbolic"
  readonly property string placeholderText: "Search applications..."
  readonly property int maxVisibleEntries: 5

  property var foundEntries: []

  function refresh() {
  }

  function filter(query) {
    var trimmed = query.toLowerCase().trim();
    if (trimmed === "") {
      root.foundEntries = [];
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
        scored.push({ app: app, score: best });
      }
    }
    scored.sort(function (a, b) { return b.score - a.score; });
    var filtered = scored.slice(0, root.maxVisibleEntries);
    root.foundEntries = filtered.map(function (item) {
      return {
        primaryText: item.app.name,
        secondaryText: item.app.comment ?? item.app.name,
        iconSource: item.app.icon ?? "",
        thumbnailSource: "",
        hintText: "",
        _desktopEntry: item.app
      };
    });
  }

  function activate(index) {
    if (index < 0 || index >= root.foundEntries.length) return;
    root.foundEntries[index]._desktopEntry.execute();
  }

  function reset() {
    root.foundEntries = [];
  }
}
