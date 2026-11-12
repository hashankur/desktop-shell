pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import qs.components
import qs.config

Item {
    id: root

    property string placeholderText: "Search..."
    property string iconSource: "system-search-symbolic"
    property string text: ""
    property int maxVisibleEntries: 5

    signal accepted()
    signal searchChanged(string text)
    signal upPressed()
    signal downPressed()
    signal escapePressed()
    signal altNumberPressed(int index)

    implicitHeight: 48
    implicitWidth: 200

    function clear() {
        searchField.text = "";
    }

    // Focus the inner TextField, never this wrapper Item: forceActiveFocus
    // on the wrapper steals activeFocus from the TextField and typed keys
    // then go nowhere (clicking the field used to be the only fix).
    function focusField() {
        searchField.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.surface_container
        border.width: 1
        border.color: Appearance.colors.outline_variant

        // Tinted, not raw: a symbolic glyph straight from the theme is
        // near-black and disappears against the dark field background.
        Icon {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 16
            implicitSize: 18
            tint: Appearance.colors.on_surface_variant
            tintAmount: 1
            source: Quickshell.iconPath(root.iconSource, true)
        }

        TextField {
            id: searchField
            anchors.fill: parent
            anchors.leftMargin: 42
            anchors.rightMargin: 12
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            background: Rectangle {
                color: "transparent"
            }
            placeholderText: root.placeholderText
            font.family: Appearance.font.mono
            font.letterSpacing: Appearance.tracking.label
            font.pixelSize: Appearance.fontSize.sm
            color: Appearance.colors.on_surface
            placeholderTextColor: Appearance.colors.on_surface_variant
            focus: true
            activeFocusOnTab: true

            onTextChanged: {
                root.text = text;
                root.searchChanged(text);
            }

            // Enter is handled exclusively in Keys.onPressed below so
            // `accepted` can never fire twice for one keypress.

            Keys.onPressed: function (event) {
                if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    var targetIndex = event.key - Qt.Key_1;
                    if (targetIndex < root.maxVisibleEntries) {
                        root.altNumberPressed(targetIndex);
                        event.accepted = true;
                    }
                    return;
                }
                switch (event.key) {
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.accepted();
                    event.accepted = true;
                    break;
                case Qt.Key_Down:
                    root.downPressed();
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                    root.upPressed();
                    event.accepted = true;
                    break;
                case Qt.Key_Escape:
                    root.escapePressed();
                    event.accepted = true;
                    break;
                }
            }
        }
    }
}
