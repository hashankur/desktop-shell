import Brightness from "@/lib/brightness";
import Network from "gi://AstalNetwork";
import Wp from "gi://AstalWp";
import { StackBtn, ToggleBtn } from "@/widget/sidebar/buttons";
import { App, Gtk } from "astal/gtk4";
import Button from "@/common/Button";
import Util from "@/util/util";
import icons from "@/util/icons";
import { bind, execAsync, type Variable } from "astal";
import { warpStatus, warpToggle } from "../warp";

const audio = Wp.get_default()?.audio.defaultSpeaker!;
const brightness = Brightness.get_default();
const network = Network.get_default().wifi;
const connected = network.activeAccessPoint?.ssid ?? "Disabled";

type MainPage = {
  currentView: Variable<string>;
  windowName: string;
};

function MainPage({ currentView, windowName }: MainPage) {
  return (
    <box name="main" spacing={10} vertical cssClasses={["px-5"]}>
      <box halign={Gtk.Align.END}>
        <Button
          cssClasses={["bg-transparent"]}
          onClicked={() => {
            App.toggle_window("power-menu");
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
          item={connected}
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
          icon={"network-vpn-symbolic"}
          onClicked={() => warpToggle()}
          item={warpStatus()}
        />
        <StackBtn
          name="Display"
          icon={icons.brightness.indicator}
          currentView={currentView}
        />
      </box>
      <box spacing={10} vertical cssClasses={["pt-5"]}>
        <box>
          <image iconName={bind(audio, "volumeIcon")} />
          <slider
            value={bind(audio, "volume")}
            onChangeValue={(self) => audio.set_volume(self.value)}
            hexpand
            css_classes={["*:min-h-[10px]", "unset"]}
          />
        </box>
        <box>
          <image iconName={icons.brightness.screen} />
          <slider
            value={bind(brightness, "screen")}
            // onChangeValue={(self) => (brightness.screen = self.value)}
            hexpand
            css_classes={["*:min-h-[10px]", "unset"]}
          />
        </box>
      </box>
    </box>
  );
}

export default MainPage;
