import AstalBluetooth from "gi://AstalBluetooth";
import Network from "gi://AstalNetwork";
import Wp from "gi://AstalWp";
import Button from "@/common/Button";
import Window from "@/common/window";
import Brightness from "@/lib/brightness";
import icons from "@/util/icons";
import { hideWindow } from "@/util/util";
import { Variable, bind, execAsync } from "astal";
import { App, Astal, Gtk, hook } from "astal/gtk4";
import { NotificationWindow } from "./notifications/NotificationWindow";

const WINDOW_NAME = "quick-settings";
const currentView = Variable("main");

function QSButton({ name, icon }: { name: string; icon: string }) {
  return (
    <button
      onClicked={() => currentView.set(name)}
      cssClasses={[
        "px-5",
        "py-3",
        "bg-primary_container",
        "rounded-3xl",
        "min-w-28",
      ]}
    >
      <box>
        <box hexpand spacing={10}>
          <image cssClasses={["text-on_primary_container"]} iconName={icon} />
          <label label={name} cssClasses={["text-on_primary_container"]} />
        </box>
        <image
          cssClasses={["text-on_primary_container"]}
          iconName={icons.ui.arrow.right}
        />
      </box>
    </button>
  );
}

type StackPageProps = {
  child?: JSX.Element;
  name: string;
};

function StackPage({ child, name }: StackPageProps) {
  return (
    <box name={name} vertical>
      <BackButton name={name} />
      <Gtk.ScrolledWindow vexpand>{child}</Gtk.ScrolledWindow>
    </box>
  );
}

function BackButton({ name }: { name: string }) {
  return (
    <button onClicked={() => currentView.set("main")} cssClasses={["mb-3"]}>
      <box>
        <image cssClasses={["p-3"]} iconName={icons.ui.arrow.left} />
        <label cssClasses={["text-2xl"]} label={name} />
      </box>
    </button>
  );
}

function Main() {
  const audio = Wp.get_default()?.audio.defaultSpeaker!;
  const brightness = Brightness.get_default();

  return (
    <box name="main" spacing={10} vertical cssClasses={["px-5"]}>
      <box halign={Gtk.Align.END}>
        <Button
          cssClasses={["bg-transparent"]}
          onClicked={() => {
            App.toggle_window("power-menu");
            hideWindow(WINDOW_NAME);
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
            hideWindow(WINDOW_NAME);
          }}
        >
          <image cssClasses={["p-3"]} iconName={icons.ui.settings} />
        </Button>
      </box>
      <box spacing={10}>
        <QSButton name="Wifi" icon={icons.network.wireless} />
        <QSButton name="Bluetooth" icon={icons.bluetooth.enabled} />
      </box>
      <box spacing={10}>
        <QSButton name="Audio" icon={icons.audio.type.speaker} />
        <QSButton name="Display" icon={icons.brightness.indicator} />
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

function Wifi() {
  const network = Network.get_default().wifi;
  const connected = network.activeAccessPoint;

  return (
    <StackPage name="Wifi">
      <box vertical spacing={5}>
        {bind(network, "accessPoints").as((ap) =>
          ap
            .filter((ap) => !!ap.ssid)
            .sort((a, b) => b.strength - a.strength)
            .map((ap) => (
              <button
                cssClasses={[
                  "px-5",
                  "py-2",
                  "rounded-lg",
                  "hover:bg-surface_container_low",
                ]}
                onClicked={() =>
                  execAsync(`nmcli device wifi connect ${ap.bssid}`)
                }
              >
                <box spacing={15} valign={Gtk.Align.CENTER}>
                  <image
                    cssClasses={["icon-lg"]}
                    iconName={ap.iconName || ""}
                  />
                  <box vertical valign={Gtk.Align.CENTER}>
                    <label
                      cssClasses={["text-lg", "text-semibold"]}
                      label={ap.ssid}
                      xalign={0}
                    />
                    {connected.ssid == ap.ssid && (
                      <label
                        cssClasses={["text-sm", "text-semibold"]}
                        label="Connected"
                      />
                    )}
                  </box>
                </box>
              </button>
            )),
        )}
      </box>
    </StackPage>
  );
}

function Bluetooth() {
  const bluetooth = AstalBluetooth.get_default();

  return (
    <StackPage name="Bluetooth">
      <box vertical spacing={5}>
        {bind(bluetooth, "devices").as((device) =>
          device.map((device) => (
            <button
              cssClasses={[
                "px-5",
                "py-2",
                "rounded-lg",
                "hover:bg-surface_container_low",
              ]}
              onClicked={() => print(device.connect_device())}
            >
              <box spacing={15} valign={Gtk.Align.CENTER}>
                <image cssClasses={["icon-lg"]} iconName={device.icon || ""} />
                <box vertical valign={Gtk.Align.CENTER}>
                  <label
                    cssClasses={["text-lg", "text-semibold"]}
                    label={device.name}
                    xalign={0}
                  />
                  {device.connected && (
                    <label
                      cssClasses={["text-sm", "text-semibold"]}
                      label="Connected"
                    />
                  )}
                </box>
              </box>
            </button>
          )),
        )}
      </box>
    </StackPage>
  );
}

export default function QuickSettings() {
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
            <Main />
            <Wifi />
            <Bluetooth />
          </stack>
        </box>
        <NotificationWindow />
      </box>
    </Window>
  );
}
