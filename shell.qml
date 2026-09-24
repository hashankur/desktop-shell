//@ pragma IconTheme MoreWaita
//@ pragma DropExpensiveFonts

import QtQuick
import Quickshell

import qs.modules.bar
import qs.modules.frame
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.osd
import qs.modules.dashboard
import qs.modules.powermenu
import qs.services

ShellRoot {
    id: root

    GlobalFrame {}

    Bar {}

    Launcher {}

    Osd {}

    NotificationHost {}

    DashboardWindow {}

    PowerMenu {}
}
