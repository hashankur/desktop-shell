import QtQuick
import Quickshell

import "modules/bar"

ShellRoot {
    id: root

    LazyLoader {
        active: true
        component: Bar {}
    }
}
