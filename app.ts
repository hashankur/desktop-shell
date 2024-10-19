import { App } from "astal/gtk3";
import style from "./style.css";
// import Bar from "./widget/Bar"
import AppLauncher from "./widget/AppLauncher";
import Dashboard from "./widget/Dashboard";

App.start({
    css: style,
    main() {
        AppLauncher();
        Dashboard();
        // Bar(0)
        // Bar(1) // initialize other monitors
    },
});

