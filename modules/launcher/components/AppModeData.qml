pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs.config

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
    var filtered = [];
    for (var i = 0; i < all.length; i++) {
      var app = all[i];
      if (app.name.toLowerCase().includes(trimmed) ||
          ((app.comment?.toLowerCase().includes(trimmed)) ?? false)) {
        filtered.push(app);
        if (filtered.length >= root.maxVisibleEntries) break;
      }
    }
    root.foundEntries = filtered.map(function (app) {
      return {
        primaryText: app.name,
        secondaryText: app.comment ?? app.name,
        iconSource: app.icon ?? "",
        thumbnailSource: "",
        hintText: "",
        _desktopEntry: app
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
