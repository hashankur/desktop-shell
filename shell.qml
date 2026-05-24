//@ pragma IconTheme MoreWaita

import QtQuick
import Quickshell

import qs.modules.bar
import qs.modules.frame
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.osd
import qs.modules.dashboard
import qs.services

ShellRoot {
    id: root

    GlobalFrame {}

    Bar {}

    LazyLoader {
        active: true
        component: Launcher {}
    }

    Osd {}

    LazyLoader {
        active: true
        component: NotificationHost {}
    }

    LazyLoader {
        active: true
        component: DashboardWindow {}
    }
}
