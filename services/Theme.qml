pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

import "../config/palette.js" as Palette

// Theme and wallpaper control, as two independent halves:
//
//   colors     the default scheme, or a matugen scheme derived from a
//              wallpaper; persisted to appearance.json, which Appearance
//              watches, so applying a scheme repaints the shell live
//   wallpaper  the desktop background, handed to awww
//
// They are independent on purpose: browsing wallpapers does not have to
// repaint the shell, and a failing matugen run cannot change the desktop.
Singleton {
    id: root

    readonly property string appearancePath: Quickshell.env("HOME") + "/.config/quickshell/appearance.json"
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    readonly property bool wallpaperColors: Appearance.themeMode === "wallpaper"

    // matugen is interactive unless given a preference (without one it
    // fails with "a terminal was not detected"), and -j hex is what makes
    // it print the scheme to stdout instead of running templates.
    readonly property string matugenPrefer: "darkness"

    property bool matugenPresent: false
    property bool generating: false
    property bool listing: false
    property bool _regenQueued: false
    property string status: ""
    property var wallpapers: []

    // Writer for appearance.json. Not Appearance.writeAdapter(): that
    // serialises every adapter group, which would park geometry, fonts and
    // curves in the file and freeze any later edit to those tokens. The
    // theme file carries colors and theme state only, and Appearance
    // reloads it in place through watchChanges.
    FileView {
        id: themeFile
        path: root.appearancePath
        atomicWrites: true
        printErrors: false
        onSaveFailed: (e) => {
            root.status = "save failed";
            console.warn("Theme: could not write appearance.json:", e);
        }
    }

    // Reads the live tokens by name rather than iterating the object: the
    // palette key set is the same 50 names setColors() writes, so it is the
    // authoritative list.
    function snapshotColors() {
        const out = {};
        const src = Appearance.colors;
        for (const key in Palette.cobalt.colors)
            out[key] = src[key];
        return out;
    }

    function persist() {
        saveTimer.restart();
    }

    function _persistNow() {
        // Writing before Appearance's file has loaded would flush the
        // declared defaults over whatever the user already had saved.
        if (!Appearance.settled) {
            root.status = "theme file still loading";
            return;
        }
        themeFile.setText(JSON.stringify({
            colors: snapshotColors(),
            themeMode: Appearance.themeMode,
            wallpaper: Appearance.wallpaper
        }, null, 4));
    }

    function useDefault() {
        // JsonAdapter keeps whatever it last loaded, so returning to the
        // default has to push the cobalt palette in explicitly; writing a
        // file without a "colors" key would reset nothing.
        Appearance.setColors(Palette.cobalt.colors);
        Appearance.themeMode = "default";
        root.persist();
        root.status = "default scheme";
    }

    function useWallpaperColors() {
        if (Appearance.wallpaper === "") {
            root.status = "pick a wallpaper first";
            return;
        }
        if (root.generating) {
            root._regenQueued = true;
            return;
        }
        root.generating = true;
        root.status = "generating";
        matugenProc.exec(["matugen", "image", "-m", "dark", "--prefer", matugenPrefer, "-j", "hex", Appearance.wallpaper]);
    }

    function setWallpaper(path) {
        Appearance.wallpaper = path;
        root.persist();
        awwwProc.exec(["awww", "img", path, "--transition-type", "fade"]);
        if (root.wallpaperColors)
            root.useWallpaperColors();
    }

    function refreshWallpapers() {
        if (listing)
            return;
        listing = true;
        listProc.exec(["sh", "-c", 'find "' + wallpaperDir + '" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) 2>/dev/null | sort']);
    }

    // Coalesces the burst of persist() calls a wallpaper click makes (path
    // first, scheme again once matugen answers) into one write.
    Timer {
        id: saveTimer
        interval: 500
        onTriggered: root._persistNow()
    }

    Process {
        id: whichMatugen
        command: ["which", "matugen"]
        running: true
        onExited: (exitCode, exitStatus) => {
            root.matugenPresent = exitCode === 0;
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                const next = listOut.text.split("\n").filter(l => l.length > 0);
                if (next.join("\n") !== root.wallpapers.join("\n"))
                    root.wallpapers = next;
            }
        }
        onExited: {
            root.listing = false;
        }
    }

    // awww failing means the wallpaper stays as it was; not worth surfacing
    // beyond the status line and a log warning.
    Process {
        id: awwwProc
        stdout: StdioCollector {
            id: awwwOut
            onStreamFinished: {
                if (awwwOut.text.trim() !== "")
                    root.status = awwwOut.text.trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.status = "awww failed (" + exitCode + ")";
                console.warn("Theme: awww img failed with exit code", exitCode);
            }
        }
    }

    // One-shot generator. Its stdout carries the whole scheme, so a failed
    // run applies nothing: the palette is only pushed once every token
    // parsed.
    Process {
        id: matugenProc
        stdout: StdioCollector {
            id: matugenOut
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(matugenOut.text);
                    const src = parsed.colors || {};
                    const out = {};
                    for (const key in src) {
                        // -j hex yields colors.<key>.default.color; the
                        // --old-json-output shape is the bare string.
                        const entry = src[key].default;
                        const hex = typeof entry === "string" ? entry : (entry ? entry.color : undefined);
                        if (typeof hex === "string" && hex.startsWith("#"))
                            out[key] = hex;
                    }
                    if (Object.keys(out).length === 0)
                        throw new Error("no color tokens parsed");
                    Appearance.setColors(out);
                    Appearance.themeMode = "wallpaper";
                    root.persist();
                    root.status = "wallpaper scheme";
                } catch (e) {
                    root.status = "matugen output unusable";
                    console.warn("Theme: matugen output unusable:", e);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.generating = false;
            if (root._regenQueued) {
                root._regenQueued = false;
                root.useWallpaperColors();
                return;
            }
            if (exitCode !== 0) {
                root.status = "matugen failed (" + exitCode + ")";
                console.warn("Theme: matugen failed with exit code", exitCode);
            }
        }
    }
}
