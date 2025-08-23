import { SIDEBAR_WIDTH } from "@/constants/spacing";
import Window from "@/widget/common/window";
import NotificationWindow from "@/widget/notifications";
import { createBinding, onCleanup } from "ags";
import { createState } from "ags";
import { Astal, Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import BluetoothPage from "./views/Bluetooth";
import MainPage from "./views/Main";
import NetworkPage from "./views/Network";

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
        class="bg-surface_container_lowest rounded-l-2xl"
        orientation={Gtk.Orientation.VERTICAL}
      >
        <stack
          transitionType={Gtk.StackTransitionType.SLIDE_LEFT_RIGHT}
          transitionDuration={200}
          vexpandSet
            class="p-5 pb-0"
          $={(self) => {
            const unsub = currentView.subscribe(() =>
                           self.set_visible_child_name(currentView.get()),
                        );
                        onCleanup(() => unsub());

                    self.connect("unmap", () => {
                      setCurrentView("main");
                    });
                }}
        >
          <MainPage setCurrentView={setCurrentView} windowName={WINDOW_NAME} />
          <NetworkPage setCurrentView={setCurrentView} />
          {/*<BluetoothPage currentView={currentView} />*/}
        </stack>
        <NotificationWindow />
      </box>
    </Window>
  );
}
