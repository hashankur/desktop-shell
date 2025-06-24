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
import Util from "@/util/util";
import { exec } from "ags/process";

// https://github.com/Aiz0/dotless
const style = exec("bunx tailwindcss -i styles/main.css")
  .replace(/::backdrop.*?}\n{2}/s, "") // remove backdrop pseudoclass
  .replace(", ::before, ::after", ""); // remove before & after psudoclasses

app.start({
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
    Calendar();
    Desktop();
    SideBar();

    Util.notifyLowBattery();
  },
});
