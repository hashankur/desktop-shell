import Button from "@/common/Button";
// import Brightness from "@/lib/brightness";
import icons from "@/util/icons";
import Util from "@/util/util";
import { StackBtn, ToggleBtn } from "@/widget/sidebar/buttons";
import { createBinding, createState } from "ags";
import { Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import { execAsync } from "ags/process";
import Network from "gi://AstalNetwork";
import Wp from "gi://AstalWp";
import { warpStatus, warpToggle } from "@/lib/warp";
import type { Setter } from "ags";

const audio = Wp.get_default()?.audio.defaultSpeaker!;
// const brightness = Brightness.get_default();
const network = Network.get_default().wifi;
const [inhibitStatus, setInhibitStatus] = createState(0);

type MainPageProps = {
  currentView: Setter<string>;
  windowName: string;
};

function MainPage({ currentView, windowName }: MainPageProps) {
  return (
    <box
      name="main"
      spacing={10}
      orientation={Gtk.Orientation.VERTICAL}
      cssClasses={["px-5"]}
    >
      <box halign={Gtk.Align.END}>
        <Button
          cssClasses={["bg-transparent"]}
          onClicked={() => {
            app.toggle_window("power-menu");
            Util.hideWindow(windowName);
          }}
        >
          <image cssClasses={["p-3"]} iconName={icons.powermenu.shutdown} />
        </Button>
        <Button
          cssClasses={["bg-transparent"]}
          onClicked={() => {
            execAsync([
              "sh",
              "-c",
              "XDG_CURRENT_DESKTOP=gnome gnome-control-center",
            ]);
            Util.hideWindow(windowName);
          }}
        >
          <image cssClasses={["p-3"]} iconName={icons.ui.settings} />
        </Button>
      </box>
      <box spacing={10}>
        <StackBtn
          name="Network"
          item={createBinding(
            network,
            "activeAccessPoint",
          )((ap) => ap?.ssid ?? "Disabled")}
          icon={icons.network.wireless}
          currentView={currentView}
        />
        <StackBtn
          name="Bluetooth"
          icon={icons.bluetooth.enabled}
          currentView={currentView}
        />
      </box>
      <box spacing={10}>
        <ToggleBtn
          name="WARP"
          icon={icons.network.vpn}
          onClicked={() => warpToggle()}
          item={warpStatus}
        />
        <ToggleBtn
          name="Inhibit Sleep"
          icon={icons.ui.avatar}
          onClicked={() => {
            inhibitStatus.get() === 0
              ? setInhibitStatus(
                  app.inhibit(
                    null,
                    Gtk.ApplicationInhibitFlags.SUSPEND,
                    "Inhibit Sleep",
                  ),
                )
              : app.uninhibit(inhibitStatus.get());
          }}
          item={inhibitStatus.as((v) => (v === 0 ? "Disabled" : "Enabled"))}
        />
      </box>
      <box
        spacing={10}
        orientation={Gtk.Orientation.VERTICAL}
        cssClasses={["pt-5"]}
      >
        <box>
          <image iconName={createBinding(audio, "volumeIcon")} />
          <slider
            value={createBinding(audio, "volume")}
            onChangeValue={(self) => audio.set_volume(self.value)}
            hexpand
            css_classes={["*:min-h-[10px]", "unset"]}
          />
        </box>
        {/* <box>
          <image iconName={icons.brightness.screen} />
          <slider
            value={createBinding(brightness, "screen")}
            // onChangeValue={(self) => (brightness.screen = self.value)}
            hexpand
            css_classes={["*:min-h-[10px]", "unset"]}
          />
        </box> */}
      </box>
    </box>
  );
}

export default MainPage;
