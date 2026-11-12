//@ pragma IconTheme MoreWaita
//@ pragma DropExpensiveFonts

import QtQuick
import Quickshell

import qs.modules.bar
import qs.modules.console
import qs.modules.notifications
import qs.modules.osd
import qs.modules.screenshot
import qs.modules.settings

ShellRoot {
    id: root

    Bar {}

    ConsoleWindow {}

    SettingsWindow {}

    Osd {}

    ScreenshotOverlay {}

    NotificationHost {}
}
