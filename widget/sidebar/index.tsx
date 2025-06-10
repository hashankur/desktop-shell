import Window from "@/common/window";
import { Variable, bind } from "astal";
import { App, Astal, Gtk, hook } from "astal/gtk4";
import NotificationWindow from "@/widget/notifications";
import NetworkPage from "./views/Network";
import MainPage from "./views/Main";
import BluetoothPage from "./views/Bluetooth";

const WINDOW_NAME = "quick-settings";
const currentView = Variable("main");

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
        vertical
      >
        <box vexpandSet={true}>
          <stack
            visibleChildName={bind(currentView)}
            transitionType={Gtk.StackTransitionType.SLIDE_LEFT_RIGHT}
            transitionDuration={200}
            cssClasses={["min-w-96", "p-5", "pb-0"]}
            setup={(self) => {
              hook(self, App, "window-toggled", (_) => {
                currentView.set("main");
              });
            }}
          >
            <MainPage currentView={currentView} windowName={WINDOW_NAME} />
            <NetworkPage currentView={currentView} />
            <BluetoothPage currentView={currentView} />
          </stack>
        </box>
        <NotificationWindow />
      </box>
    </Window>
  );
}
