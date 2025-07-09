import Battery from "gi://AstalBattery";
import Mpris from "gi://AstalMpris";
import Network from "gi://AstalNetwork";
import Bluetooth from "gi://AstalBluetooth";
import Tray from "gi://AstalTray";
import Niri from "gi://AstalNiri";
import Wp from "gi://AstalWp";
import Button from "@/common/Button";
import Window from "@/common/window";
import icons from "@/util/icons";
import { GLib, Variable, bind, execAsync } from "astal";
import { App, Astal, Gtk, hook } from "astal/gtk4";
import Pango from "gi://Pango";

const WINDOW_NAME = "bar";
const MAX_WIDTH_CHARS = 50;

const time = Variable("").poll(
  1000,
  () => GLib.DateTime.new_now_local().format("%a %d %b  •  %I:%M %p") ?? "",
);

function Workspaces() {
  const niri = Niri.get_default();
  const workspaces = Variable.derive(
    [bind(niri, "workspaces"), bind(niri, "focused_workspace")],
    (ws, fws) =>
      ws.map((w) => (
        <button
          onClicked={() =>
            execAsync(`niri msg action focus-workspace ${w.id}`).catch(printerr)
          }
          hexpand
          cssClasses={[
            "min-h-1",
            "p-0",
            "rounded-none",
            ...(fws.id === w.id
              ? ["text-on_primary", "bg-primary"]
              : w.activeWindowId < 1_000 // Num overflow?
                ? ["bg-primary_container"]
                : ["bg-surface_container"]),
          ]}
        />
      )),
  );

  return <box spacing={3}>{workspaces()}</box>;
}

function Active() {
  const niri = Niri.get_default();

  return (
    <>
      {bind(niri, "focusedWindow").as((v) => (
        <box spacing={5}>
          <image iconName={`${v?.appId ?? "user-desktop"}-symbolic`} />
          <label
            label={v?.title ?? "Desktop"}
            maxWidthChars={MAX_WIDTH_CHARS}
            ellipsize={Pango.EllipsizeMode.END}
          />
        </box>
      ))}
    </>
  );
}

function SysTray() {
  const tray = Tray.get_default();

  return (
    <box spacing={5}>
      {bind(tray, "items").as((items) =>
        items.map((item) => (
          <menubutton
            tooltipMarkup={bind(item, "tooltipMarkup")}
            menuModel={bind(item, "menuModel")}
            setup={(self) =>
              hook(self, item, "notify::action-group", () =>
                self.insert_action_group("dbusmenu", item.action_group),
              )
            }
            cssClasses={["hover:bg-surface_container_low", "rounded-lg"]}
          >
            <image gicon={bind(item, "gicon")} />
          </menubutton>
        )),
      )}
    </box>
  );
}

function Wifi() {
  const { wifi } = Network.get_default();

  return (
    <image
      tooltipText={bind(wifi, "ssid").as((v) => v ?? "Disabled")}
      iconName={bind(wifi, "iconName")}
    />
  );
}

function BluetoothStatus() {
  const { devices } = Bluetooth.get_default();
  const device = devices[0];

  return (
    <>
      {bind(device, "connected").as((v) => (
        <image
          tooltipText={v ? bind(device, "name").as(String) : "Not Connected"}
          iconName={v ? icons.bluetooth.enabled : icons.bluetooth.disabled}
        />
      ))}
    </>
  );
}

function AudioLevel() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!;

  return <image iconName={bind(speaker, "volumeIcon")} />;
}

function secondsToHoursMinutes(time: number, verb: string): string {
  const seconds = Math.round(time / 60);
  return `${Math.floor(seconds / 60)}h ${Math.floor(seconds % 60)}m ${verb}`;
}

function BatteryLevel() {
  const bat = Battery.get_default();

  const batteryTooltip = Variable.derive(
    [bind(bat, "charging"), bind(bat, "timeToEmpty"), bind(bat, "timeToFull")],
    (charging, empty, full) => {
      return charging
        ? full === 0
          ? "Charged"
          : secondsToHoursMinutes(full, "to full")
        : secondsToHoursMinutes(empty, "remaining");
    },
  );

  return (
    <box
      visible={bind(bat, "isPresent")}
      spacing={5}
      tooltipText={batteryTooltip()}
    >
      <image iconName={bind(bat, "batteryIconName")} />
      <label
        label={bind(bat, "percentage").as((p) => {
          const level = Math.floor(p * 100);
          return level === 100 ? "Full" : `${level}%`;
        })}
      />
    </box>
  );
}

function Media() {
  const spotify = Mpris.Player.new("spotify");

  const formattedLabel = Variable.derive(
    [bind(spotify, "artist"), bind(spotify, "title")],
    (artist: string, title: string) => `${artist} - ${title}`,
  );

  return (
    <Button
      visible={bind(spotify, "available")}
      onClicked={() => spotify.play_pause()}
    >
      <box spacing={5}>
        <image
          iconName={bind(spotify, "playbackStatus").as((status) =>
            status === Mpris.PlaybackStatus.PLAYING
              ? icons.media.playing
              : icons.media.stopped,
          )}
        />
        <label
          label={formattedLabel()}
          maxWidthChars={MAX_WIDTH_CHARS}
          ellipsize={Pango.EllipsizeMode.END}
        />
      </box>
    </Button>
  );
}

function Stats() {
  const cpu = Variable(0).poll(5000, [
    "sh",
    "-c",
    "top -bn1 | grep Cpu | sed 's/\\,/\\./g' | awk '{print $2}'",
  ]);
  const memory = Variable(0).poll(5000, [
    "sh",
    "-c",
    `free | awk '/^Mem/ {printf("%.2f\\n", ($3/$2) * 100)}'`,
  ]);
  const gpu = Variable(0).poll(
    5000,
    "cat /sys/class/hwmon/hwmon6/device/gpu_busy_percent",
  );
  const temp = Variable(0).poll(
    5000,
    "cat /sys/class/thermal/thermal_zone0/temp",
  );

  const Stat = ({ value, tooltip }) => {
    return (
      // <circularprogress
      //   value={value}
      //   startAt={0.75}
      //   endAt={0.75}
      //   tooltipText={tooltip}
      //   cssName="Stats"
      //   rounded
      // />

      // Until circular progress gets merged
      <levelbar value={value} widthRequest={40} tooltipText={tooltip} />
    );
  };

  return (
    <box spacing={5} cssClasses={["p-1"]} valign={Gtk.Align.CENTER}>
      <box spacing={5} vertical>
        <Stat
          value={cpu((val) => val / 100)}
          tooltip={cpu((val) => `CPU: ${Math.round(val)}% used`)}
        />
        <Stat
          value={memory((val) => val / 100)}
          tooltip={memory((val) => `Memory: ${Math.round(val)}% used`)}
        />
      </box>
      <box spacing={5} vertical>
        <Stat
          value={gpu((val) => val / 100)}
          tooltip={gpu((val) => `GPU: ${Math.round(val)}% used`)}
        />
        <Stat
          value={temp((val) => val / 1000 / 100)}
          tooltip={temp((val) => `Temp: ${val / 1000} °C`)}
        />
      </box>
    </box>
  );
}

function Left() {
  return (
    <box spacing={20}>
      <Stats />
      <Active />
    </box>
  );
}

function Center() {
  return (
    <menubutton hexpand halign={Gtk.Align.CENTER}>
      <label label={time()} />
      <popover>
        <Gtk.Calendar />
      </popover>
    </menubutton>
  );
}

function Right() {
  return (
    <box halign={Gtk.Align.END} spacing={5}>
      <Media />
      <SysTray />
      <Button onClicked={() => App.toggle_window("quick-settings")}>
        <box spacing={20}>
          <BluetoothStatus />
          <Wifi />
          <AudioLevel />
          <BatteryLevel />
        </box>
      </Button>
    </box>
  );
}

export default function Bar(monitor: number) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

  return (
    <Window
      name={WINDOW_NAME}
      monitor={monitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.NONE}
      anchor={TOP | LEFT | RIGHT}
      margin={0}
      visible
      namespace={"astal-bar"}
    >
      <box vertical cssClasses={["bg-surface_container_lowest"]}>
        <Workspaces />
        <centerbox cssClasses={["px-1", "min-h-10"]}>
          <Left />
          <Center />
          <Right />
        </centerbox>
      </box>
    </Window>
  );
}
