//@ pragma IconTheme MoreWaita

import QtQuick
import Quickshell

import qs.modules
import qs.modules.bar
import qs.modules.launcher

ShellRoot {
    id: root

    Bar {}

    Launcher {}

    LazyLoader {
        active: true
        component: Osd {}
    }
}
