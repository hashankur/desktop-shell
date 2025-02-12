import { App } from "astal/gtk4";
import AppLauncher from "@/widget/AppLauncher";
import Bar from "@/widget/Bar";
import Clipboard from "@/widget/Clipboard";
import Media from "@/widget/Media";
import OSD from "@/widget/OSD";
import PowerMenu from "@/widget/PowerMenu";
import NotificationPopups from "@/widget/notifications/NotificationPopups";
import Calendar from "@/widget/Calendar";
import QuickSettings from "@/widget/QuickSettings";
import { exec } from "astal";
import NotificationWindow from "@/widget/notifications/NotificationWindow";

// https://github.com/Aiz0/dotless
const style = exec("bunx tailwindcss -i main.css")
  .replace(/::backdrop.*?}\n{2}/s, "") // remove backdrop pseudoclass
  .replace(", ::before, ::after", ""); // remove before & after psudoclasses


App.start({
  css: style,
  main() {
    AppLauncher();
    Bar(0);
    // Bar(1) // initialize other monitors
    Clipboard();
    Media();
    OSD();
    PowerMenu();
    // App.get_monitors().map(NotificationPopups);
    NotificationPopups();
    NotificationWindow();
    Calendar();
    QuickSettings();
  },
});
