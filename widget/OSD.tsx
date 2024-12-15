import Window from "@/common/window";
import Brightness from "@/lib/brightness";
import icons from "@/utils/icons";
import { bind, timeout } from "astal";
import { Astal, Gtk } from "astal/gtk3";
import Wp from "gi://AstalWp";

const WINDOW_NAME = "osd";
const TIMEOUT = 2000;
const TRANSITION = Gtk.RevealerTransitionType.SLIDE_LEFT;

function BrightnessSlider() {
  const brightness = Brightness.get_default();

  return (
    <revealer
      transitionType={TRANSITION}
      setup={(self) => {
        let i = 0;

        self.hook(brightness, "notify::screen", () => {
          self.set_reveal_child(true);
          i++;
          timeout(TIMEOUT, () => {
            i--;

            if (i === 0) self.set_reveal_child(false);
          });
        });
      }}
    >
      <box className="Osd base" vertical>
        <slider
          className="Osd-Slider"
          vertical
          value={bind(brightness, "screen")}
          onDragged={({ value }) => (brightness.screen = value)}
          drawValue={false}
          inverted
        />
        <icon icon={icons.brightness.screen} />
      </box>
    </revealer>
  );
}

function VolumeSlider() {
  const audio = Wp.get_default()?.audio.defaultSpeaker!;

  return (
    <revealer
      transitionType={TRANSITION}
      setup={(self) => {
        let i = 0;

        self.hook(bind(audio, "volume"), () => {
          self.set_reveal_child(true);
          i++;
          timeout(TIMEOUT, () => {
            i--;

            if (i === 0) self.set_reveal_child(false);
          });
        });
      }}
    >
      <box className="Osd base" vertical>
        <slider
          className="Osd-Slider"
          vertical
          value={bind(audio, "volume")}
          onDragged={({ value }) => (audio.volume = value)}
          drawValue={false}
          inverted
        />
        <icon icon={bind(audio, "volumeIcon")} />
      </box>
    </revealer>
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
    >
      <box>
        <BrightnessSlider />
        <VolumeSlider />
      </box>
    </Window>
  );
}
