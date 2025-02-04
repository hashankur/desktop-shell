// import style from "./styles/main.scss";
import { App } from "astal/gtk4";
import { monitorFile } from "astal/file";
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

// https://github.com/Aiz0/dotless
const style = exec("bunx tailwindcss -i main.css")
  .replace(/::backdrop.*?}\n{2}/s, "") // remove backdrop pseudoclass
  .replace(", ::before, ::after", ""); // remove before & after psudoclasses

App.start({
  css: style,
  main() {
    // AppLauncher();
    Bar(0);
    // Bar(1) // initialize other monitors
    // Clipboard();
    Media();
    // OSD();
    // PowerMenu();
    // App.get_monitors().map(NotificationPopups);
    Calendar();
    // QuickSettings();
  },
});

// const CSS_DIR = `${SRC}/css`;

// monitorFile(CSS_DIR, () => {
//     App.apply_css(`${CSS_DIR}/main.css`, true);
// });
