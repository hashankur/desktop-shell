//@ pragma IconTheme MoreWaita

import QtQuick
import Quickshell

import qs.components
import qs.modules
import qs.modules.bar
import qs.modules.launcher

ShellRoot {
    id: root

    GlobalFrame {}

    Bar {}

    Launcher {}

    LazyLoader {
        active: true
        component: Osd {}
    }
}
