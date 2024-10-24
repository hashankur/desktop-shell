import style from "./css/main.css";
import { App } from "astal/gtk3";
import { monitorFile } from "astal/file";
import AppLauncher from "./widget/AppLauncher";
// import Bar from "./widget/Bar"
import Clipboard from "./widget/Clipboard";
import Media from "./widget/Media";
import OSD from "./widget/OSD";
import PowerMenu from "./widget/PowerMenu";

App.start({
  css: style,
  main() {
    AppLauncher();
    // Bar(0)
    // Bar(1) // initialize other monitors
    Clipboard();
    Media();
    OSD();
    PowerMenu();
  },
});

const CSS_DIR = `${SRC}/css`;

monitorFile(CSS_DIR, () => {
  App.apply_css(`${CSS_DIR}/main.css`, true);
});
