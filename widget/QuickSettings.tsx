import AstalBluetooth from "gi://AstalBluetooth";
import Network from "gi://AstalNetwork";
import Button from "@/common/Button";
import Window from "@/common/window";
import icons from "@/util/icons";
import { hideWindow } from "@/util/util";
import { Variable, bind, execAsync } from "astal";
import { App, Astal, Gtk } from "astal/gtk4";

const WINDOW_NAME = "quick-settings";
const currentView = Variable("main");

function QSButton({ name, icon }: { name: string; icon: string }) {
  return (
    <button
      onClicked={() => currentView.set(name)}
      cssClasses={["px-5", "py-3", "bg-cyan-800", "rounded-lg", "min-w-28"]}
    >
      <box>
        <box hexpand spacing={10}>
          <image iconName={icon} />
          {name}
        </box>
        <image iconName={icons.ui.arrow.right} />
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
      <Gtk.ScrolledWindow cssClasses={["min-h-40"]}>{child}</Gtk.ScrolledWindow>
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
  return (
    <box name="main" spacing={10} vertical>
      <box halign={Gtk.Align.END}>
        <Button
          onClicked={() => {
            App.toggle_window("power-menu");
            hideWindow(WINDOW_NAME);
          }}
        >
          <image cssClasses={["p-3"]} iconName={icons.powermenu.shutdown} />
        </Button>
        <Button
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
    </box>
  );
}

function Wifi() {
  const network = Network.get_default().wifi;

  return (
    <StackPage name="Wifi">
      <box vertical spacing={5}>
        {bind(network, "accessPoints").as((ap) =>
          ap
            .filter((ap) => !!ap.ssid)
            .sort((a, b) => b.strength - a.strength)
            .map((ap) => (
              <button
                cssClasses={["px-5", "py-2", "rounded-lg", "hover:bg-base1"]}
                onClicked={() =>
                  execAsync(`nmcli device wifi connect ${ap.bssid}`)
                }
              >
                <box spacing={15} valign={Gtk.Align.CENTER}>
                  <image
                    cssClasses={["icon-lg"]}
                    iconName={ap.iconName || ""}
                  />
                  <label
                    cssClasses={["text-lg", "text-semibold"]}
                    label={ap.ssid}
                  />
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
              cssClasses={["px-5", "py-2", "rounded-lg", "hover:bg-base1"]}
              onClicked={() => print(device.connect_device())}
            >
              <box spacing={15} valign={Gtk.Align.CENTER}>
                <image cssClasses={["icon-lg"]} iconName={device.icon || ""} />
                <box vertical>
                  <label
                    cssClasses={["text-lg", "text-semibold"]}
                    label={device.name}
                  />
                  {bind(device, "connected").as((v) =>
                    v ? (
                      <label
                        cssClasses={["text-semibold"]}
                        label="Connected"
                        xalign={0}
                      />
                    ) : (
                      ""
                    ),
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
  return (
    <Window
      name={WINDOW_NAME}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
    >
      <box
        cssClasses={["bg-base", "min-w-96", "p-3", "rounded-xl"]}
        vertical
        spacing={10}
        valign={Gtk.Align.START}
      >
        <box cssClasses={[]} valign={Gtk.Align.START}>
          <stack
            visibleChildName={bind(currentView)}
            transitionType={Gtk.StackTransitionType.SLIDE_LEFT_RIGHT}
            transitionDuration={200}
            cssClasses={["min-w-96"]}
            // setup={(self) => {
            // const NetworkWdgt = Network();
            // if (NetworkWdgt) self.add(NetworkWdgt);
            // }}
          >
            <Main />
            <Wifi />
            <Bluetooth />
          </stack>
        </box>
      </box>
    </Window>
  );
}
