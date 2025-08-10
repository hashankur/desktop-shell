import AppLauncher from "@/widget/AppLauncher";
import Bar from "@/widget/Bar";
import Clipboard from "@/widget/Clipboard";
// import Desktop from "@/widget/Desktop";
import { notifyLowBattery } from "@/lib/battery";
import Media from "@/widget/Media";
import NotificationPopups from "@/widget/notifications/NotificationPopups";
import OSD from "@/widget/OSD";
import PowerMenu from "@/widget/PowerMenu";
import SideBar from "@/widget/sidebar";
import app from "ags/gtk4/app";
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
    // Desktop();
    Media();
    OSD();
    PowerMenu();
    // App.get_monitors().map(NotificationPopups);
    NotificationPopups();
    SideBar();

    notifyLowBattery();
  },
});
