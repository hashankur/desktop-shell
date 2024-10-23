import style from "./css/main.css";
import { App } from "astal/gtk3";
import { monitorFile } from "astal/file";
import AppLauncher from "./widget/AppLauncher";
// import Bar from "./widget/Bar"
import Media from "./widget/Media";
import OSD from "./widget/OSD";

App.start({
  css: style,
  main() {
    AppLauncher();
    // Bar(0)
    // Bar(1) // initialize other monitors
    Media();
    OSD();
  },
});

const CSS_DIR = `${SRC}/css`;

monitorFile(CSS_DIR, () => {
  App.apply_css(`${CSS_DIR}/main.css`, true);
});
