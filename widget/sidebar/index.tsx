import Window from "@/common/window";
import NotificationWindow from "@/widget/notifications";
import NetworkPage from "./views/Network";
import MainPage from "./views/Main";
import BluetoothPage from "./views/Bluetooth";
import { createBinding } from "ags";
import { Astal, Gtk } from "ags/gtk4";
import { createState } from "ags";

const WINDOW_NAME = "sidebar";
const [currentView, setCurrentView] = createState("main");

export default function SideBar() {
  const { TOP, RIGHT, BOTTOM } = Astal.WindowAnchor;

  return (
    <Window
      name={WINDOW_NAME}
      anchor={TOP | RIGHT | BOTTOM}
      marginRight={0}
      marginLeft={0}
    >
      <box
        cssClasses={[
          "bg-surface_container_lowest",
          "min-w-96",
          "rounded-l-2xl",
        ]}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <box vexpandSet={true}>
          <stack
            visibleChildName={currentView}
            transitionType={Gtk.StackTransitionType.SLIDE_LEFT_RIGHT}
            transitionDuration={200}
            cssClasses={["min-w-96", "p-5", "pb-0"]}
            // setup={(self) => {
            //   hook(self, App, "window-toggled", (_) => {
            //     currentView.set("main");
            //   });
            // }}
          >
            <MainPage currentView={setCurrentView} windowName={WINDOW_NAME} />
            {/* <NetworkPage currentView={currentView} />
            <BluetoothPage currentView={currentView} /> */}
          </stack>
        </box>
        <NotificationWindow />
      </box>
    </Window>
  );
}
