import AppLauncher from "@/widget/AppLauncher";
import Bar from "@/widget/Bar";
import Calendar from "@/widget/Calendar";
import Clipboard from "@/widget/Clipboard";
import Desktop from "@/widget/Desktop";
import Media from "@/widget/Media";
import OSD from "@/widget/OSD";
import PowerMenu from "@/widget/PowerMenu";
import SideBar from "@/widget/sidebar";
import NotificationPopups from "@/widget/notifications/NotificationPopups";
import app from "ags/gtk4/app";
import { exec } from "ags/process";
import type { Gtk } from "ags/gtk4";
import GLib from "gi://GLib";
import { notifyLowBattery } from "@/lib/battery";

let applauncher: Gtk.Window;

// https://github.com/Aiz0/dotless
const style = exec("bunx tailwindcss -i styles/main.css")
  .replace(/::backdrop.*?}\n{2}/s, "") // remove backdrop pseudoclass
  .replace(", ::before, ::after", ""); // remove before & after psudoclasses

app.start({
  css: style,
  requestHandler(request, res) {
    const [, argv] = GLib.shell_parse_argv(request);
    if (!argv) return res("argv parse error");

    switch (argv[0]) {
      case "toggle":
        applauncher.visible = !applauncher.visible;
        return res("ok");
      default:
        return res("unknown command");
    }
  },
  main() {
    applauncher = AppLauncher() as Gtk.Window;
    app.add_window(applauncher);
    applauncher.present();
    // AppLauncher();
    Bar(0);
    // Bar(1) // initialize other monitors
    Clipboard();
    Media();
    OSD();
    PowerMenu();
    // App.get_monitors().map(NotificationPopups);
    NotificationPopups();
    Calendar();
    Desktop();
    SideBar();

    notifyLowBattery();
  },
});
