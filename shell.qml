//@ pragma IconTheme MoreWaita
//@ pragma DropExpensiveFonts

import QtQuick
import Quickshell

import qs.modules.bar
import qs.modules.console
import qs.modules.notifications
import qs.modules.osd

ShellRoot {
    id: root

    Bar {}

    ConsoleWindow {}

    Osd {}

    NotificationHost {}
}
