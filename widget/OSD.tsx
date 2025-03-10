import Wp from "gi://AstalWp";
import Window from "@/common/window";
import Brightness from "@/lib/brightness";
import icons from "@/util/icons";
import { bind, type Binding, timeout } from "astal";
import { Astal, Gtk, hook } from "astal/gtk4";

const WINDOW_NAME = "osd";
const TIMEOUT = 2000;
// BUG: artifacts remain on hide https://github.com/wmww/gtk4-layer-shell/issues/60
const TRANSITION = Gtk.RevealerTransitionType.SLIDE_LEFT;

function createSlider(
  bindable: Brightness | Wp.Endpoint,
  iconName: string | Binding<string>,
  hookProperty,
  cssClasses = [],
  onDragged = null,
) {
  return (
    <revealer
      transitionType={TRANSITION}
      setup={(self) => {
        let i = 0;
        hook(self, bind(bindable, hookProperty), () => {
          self.set_reveal_child(true);
          self.set_opacity(1);

          i++;
          timeout(TIMEOUT, () => {
            i--;
            if (i === 0) {
              self.set_reveal_child(false);
              self.set_opacity(0.1); // 1px artifact workaround
            }
          });
        });
      }}
    >
      <box
        cssClasses={["bg-surface", "p-2", "rounded-xl", ...cssClasses]}
        vertical
        spacing={5}
      >
        <slider
          cssClasses={[
            "min-h-[300px]",
            "*:min-w-[50px]",
            "rounded-[7px]",
            "unset",
          ]}
          orientation={Gtk.Orientation.VERTICAL}
          value={bind(bindable, hookProperty)}
          drawValue={false}
          inverted
        />
        <image iconName={iconName} cssClasses={["p-3"]} />
      </box>
    </revealer>
  );
}

function BrightnessSlider() {
  const brightness = Brightness.get_default();

  return createSlider(
    brightness,
    icons.brightness.screen,
    "screen",
    [],
    null, // onDragged can be added here if needed
  );
}

function VolumeSlider() {
  const audio = Wp.get_default()?.audio.defaultSpeaker!;

  return createSlider(
    audio,
    bind(audio, "volumeIcon"),
    "volume",
    [],
    null, // onDragged can be added here if needed
  );
}

export default function OSD() {
  return (
    <Window
      name={WINDOW_NAME}
      exclusivity={Astal.Exclusivity.IGNORE}
      anchor={Astal.WindowAnchor.RIGHT}
      keymode={Astal.Keymode.NONE}
      visible
      defaultWidth={-1}
      margin={10}
    >
      <box cssClasses={["bg-transparent"]}>
        <BrightnessSlider />
        <VolumeSlider />
      </box>
    </Window>
  );
}
