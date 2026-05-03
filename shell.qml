//@ pragma IconTheme MoreWaita

import QtQuick
import Quickshell

import qs.modules.bar
import qs.modules.frame
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.osd

ShellRoot {
    id: root

    GlobalFrame {}

    Bar {}

    LazyLoader {
        active: true
        component: Launcher {}
    }

    LazyLoader {
        active: true
        component: Osd {}
    }

    LazyLoader {
        active: true
        component: NotificationHost {}
    }
}
