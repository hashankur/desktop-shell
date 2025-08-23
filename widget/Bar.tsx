import Button from "@/widget/common/Button";
import icons from "@/constants/icons";
import { createBinding, createComputed, For, With } from "ags";
import { Astal, Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import { execAsync } from "ags/process";
import { createPoll } from "ags/time";
import Battery from "gi://AstalBattery";
import Bluetooth from "gi://AstalBluetooth";
import Mpris from "gi://AstalMpris";
import Network from "gi://AstalNetwork";
import Niri from "gi://AstalNiri";
import Tray from "gi://AstalTray";
import Wp from "gi://AstalWp";
import GLib from "gi://GLib";
import Pango from "gi://Pango";
import Calendar from "@/widget/calendar";

const WINDOW_NAME = "bar";
const MAX_WIDTH_CHARS = 50;

function Workspaces() {
  const niri = Niri.get_default();
  const workspaces = createBinding(niri, "workspaces");
  const focusedWorkspace = createBinding(niri, "focusedWorkspace");

  return (
    <box>
      <With value={focusedWorkspace}>
        {(fws) => (
          <box spacing={3}>
            <For each={workspaces}>
              {(w) => {
                return (
                  <button
                    onClicked={() =>
                      execAsync(
                        `niri msg action focus-workspace ${w.id}`,
                      ).catch(printerr)
                    }
                    hexpand
                    cssClasses={[
                      "min-h-1",
                      "p-0",
                      "rounded-none",
                      ...(fws?.id === w?.id
                        ? ["text-on_primary", "bg-primary"]
                        : w?.activeWindowId !== 0
                          ? ["bg-primary_container"]
                          : ["bg-surface_container"]),
                    ]}
                  />
                );
              }}
            </For>
          </box>
        )}
      </With>
    </box>
  );
}

function Active() {
  const niri = Niri.get_default();
  const activeWindow = createBinding(niri, "focusedWindow");

  return (
    <With value={activeWindow}>
      {(activeWindow) => (
        <box spacing={5}>
          <image
            iconName={`${activeWindow?.appId ?? "user-desktop"}-symbolic`}
          />
          <label
            label={activeWindow?.title ?? "Desktop"}
            maxWidthChars={MAX_WIDTH_CHARS}
            ellipsize={Pango.EllipsizeMode.END}
          />
        </box>
      )}
    </With>
  );
}

function SysTray() {
  const tray = Tray.get_default();

  const items = createBinding(tray, "items");

  const init = (btn: Gtk.MenuButton, item: Tray.TrayItem) => {
    btn.menuModel = item.menuModel;
    btn.insert_action_group("dbusmenu", item.actionGroup);
    item.connect("notify::action-group", () => {
      btn.insert_action_group("dbusmenu", item.actionGroup);
    });
  };

  return (
    <box>
      <For each={items}>
        {(item) => (
          <menubutton $={(self) => init(self, item)}>
            <image gicon={createBinding(item, "gicon")} />
          </menubutton>
        )}
      </For>
    </box>
  );
}

function Wifi() {
  const { wifi } = Network.get_default();

  return (
    <image
      tooltipText={createBinding(wifi, "ssid")((v) => v ?? "Disabled")}
      iconName={createBinding(wifi, "iconName")}
    />
  );
}

function BluetoothStatus() {
  const { devices } = Bluetooth.get_default();
  const device = devices[0];

  return (
    <box>
      <With value={createBinding(device, "connected")}>
        {(v) => (
          <image
            tooltipText={
              v ? createBinding(device, "name").as(String) : "Not Connected"
            }
            iconName={v ? icons.bluetooth.enabled : icons.bluetooth.disabled}
          />
        )}
      </With>
    </box>
  );
}

function AudioLevel() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!;

  return <image iconName={createBinding(speaker, "volumeIcon")} />;
}

function secondsToHoursMinutes(time: number, verb: string): string {
  const seconds = Math.round(time / 60);
  return `${Math.floor(seconds / 60)}h ${Math.floor(seconds % 60)}m ${verb}`;
}

function BatteryLevel() {
  const bat = Battery.get_default();

  const batteryTooltip = createComputed(
    [
      createBinding(bat, "charging"),
      createBinding(bat, "timeToEmpty"),
      createBinding(bat, "timeToFull"),
    ],
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
      visible={createBinding(bat, "isPresent")}
      spacing={5}
      tooltipText={batteryTooltip}
    >
      <image iconName={createBinding(bat, "batteryIconName")} />
      <label
        label={createBinding(
          bat,
          "percentage",
        )((p) => {
          const level = Math.floor(p * 100);
          return level === 100 ? "Full" : `${level}%`;
        })}
      />
    </box>
  );
}

function Media() {
  const spotify = Mpris.Player.new("spotify");
  const currentSong = createComputed(
    [createBinding(spotify, "artist"), createBinding(spotify, "title")],
    (artist, title) => `${artist} - ${title}`,
  );

  return (
    <Button
      visible={createBinding(spotify, "available")}
      onClicked={() => spotify.play_pause()}
    >
      <box spacing={5}>
        <image
          iconName={createBinding(
            spotify,
            "playbackStatus",
          )((status) =>
            status === Mpris.PlaybackStatus.PLAYING
              ? icons.media.playing
              : icons.media.stopped,
          )}
        />
        <label
          label={currentSong}
          maxWidthChars={MAX_WIDTH_CHARS}
          ellipsize={Pango.EllipsizeMode.END}
        />
      </box>
    </Button>
  );
}

function Stats() {
  const cpu = createPoll("", 5000, [
    "sh",
    "-c",
    "top -bn1 | grep Cpu | sed 's/\\,/\\./g' | awk '{print $2}'",
  ]);
  const memory = createPoll("", 5000, [
    "sh",
    "-c",
    `free | awk '/^Mem/ {printf("%.2f\\n", ($3/$2) * 100)}'`,
  ]);
  const gpu = createPoll(
    "",
    5000,
    "cat /sys/class/hwmon/hwmon6/device/gpu_busy_percent",
  );
  const temp = createPoll(
    "",
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
      <levelbar
        value={value}
        heightRequest={25}
        tooltipText={tooltip}
        orientation={Gtk.Orientation.VERTICAL}
        inverted
      />
    );
  };

  return (
    <box spacing={5} class="p-1" valign={Gtk.Align.CENTER}>
      <Stat
        value={cpu((val) => val / 100)}
        tooltip={cpu((val) => `CPU: ${Math.round(val)}% used`)}
      />
      <Stat
        value={memory((val) => val / 100)}
        tooltip={memory((val) => `Memory: ${Math.round(val)}% used`)}
      />
      <Stat
        value={gpu((val) => val / 100)}
        tooltip={gpu((val) => `GPU: ${Math.round(val)}% used`)}
      />
      <Stat
        value={temp((val) => val / 1000 / 100)}
        tooltip={temp((val) => `Temp: ${val / 1000} °C`)}
      />
    </box>
  );
}

function Left() {
  return (
    <box $type="start" spacing={20}>
      <Stats />
      <Active />
    </box>
  );
}

function Center() {
  const time = createPoll("", 1000, () => {
    return GLib.DateTime.new_now_local().format("%a %d %b  •  %I:%M %p") ?? "";
  });

  return (
    <menubutton $type="center" hexpand halign={Gtk.Align.CENTER}>
      <label label={time} />
      <popover>
        <Calendar />
      </popover>
    </menubutton>
  );
}

function Right() {
  return (
    <box $type="end" halign={Gtk.Align.END} spacing={5}>
      <Media />
      <SysTray />
      <Button onClicked={() => app.toggle_window("sidebar")}>
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
    <window
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
      <box
        orientation={Gtk.Orientation.VERTICAL}
        class="bg-surface_container_lowest"
      >
        <Workspaces />
        <centerbox class="px-1 min-h-10">
          <Left />
          <Center />
          <Right />
        </centerbox>
      </box>
    </window>
  );
}
