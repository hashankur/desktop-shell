import Adw from "gi://Adw?version=1";
import Network from "gi://AstalNetwork";
import Wp from "gi://AstalWp";
import icons from "@/constants/icons";
import Brightness from "@/lib/brightness";
import { hideWindow } from "@/lib/utils";
import { warpStatus, warpToggle } from "@/lib/warp";
import Button from "@/widget/common/Button";
import { StackBtn, ToggleBtn } from "@/widget/sidebar/buttons";
import { createBinding, createState } from "ags";
import type { Setter } from "ags";
import { Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import { execAsync } from "ags/process";

const audio = Wp.get_default()?.audio.defaultSpeaker!;
const brightness = Brightness.get_default();
const network = Network.get_default().wifi;
const [inhibitStatus, setInhibitStatus] = createState(0);

type MainPageProps = {
  setCurrentView: Setter<string>;
  windowName: string;
};

function MainPage({ setCurrentView, windowName }: MainPageProps) {
  return (
    <box
      $type="named"
      name="main"
      spacing={10}
      orientation={Gtk.Orientation.VERTICAL}
      class="mx-5"
    >
      <box halign={Gtk.Align.END}>
        <Button
          size="icon"
          onClicked={() => {
            app.toggle_window("power-menu");
            hideWindow(windowName);
          }}
        >
          <image class="p-3" iconName={icons.powermenu.shutdown} />
        </Button>
        <Button
          size="icon"
          onClicked={() => {
            execAsync([
              "sh",
              "-c",
              "XDG_CURRENT_DESKTOP=gnome gnome-control-center",
            ]);
            hideWindow(windowName);
          }}
        >
          <image class="p-3" iconName={icons.ui.settings} />
        </Button>
      </box>

      <Adw.WrapBox naturalLineLength={400} childSpacing={10} lineSpacing={10}>
        <StackBtn
          name="Network"
          item={createBinding(
            network,
            "activeAccessPoint",
          )((ap) => ap?.ssid ?? "Disabled")}
          icon={icons.network.wireless}
          setCurrentView={setCurrentView}
        />
        <StackBtn
          name="Bluetooth"
          icon={icons.bluetooth.enabled}
          setCurrentView={setCurrentView}
        />
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
      </Adw.WrapBox>

      <box spacing={10} orientation={Gtk.Orientation.VERTICAL} class="pt-5">
        <box>
          <image iconName={createBinding(audio, "volumeIcon")} />
          <slider
            value={createBinding(audio, "volume")}
            onChangeValue={(self) => audio.set_volume(self.value)}
            hexpand
            class="*:min-h-[10px] unset"
          />
        </box>
        <box>
          <image iconName={icons.brightness.screen} />
          <slider
            value={createBinding(brightness, "screen")}
            // onChangeValue={(self) => (brightness.screen = self.value)}
            hexpand
            class="*:min-h-[10px] unset"
          />
        </box>
      </box>
    </box>
  );
}

export default MainPage;
