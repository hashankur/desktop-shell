import { App, Astal, Gtk } from "astal/gtk3";
import { bind, timeout } from "astal";
import Brightness from "../lib/brightness";
import Wp from "gi://AstalWp";

const WINDOW_NAME = "osd";

function BrightnessSlider() {
  const brightness = Brightness.get_default();

  return (
    <revealer
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={125}
      setup={(self) => {
        let i = 0;

        self.hook(brightness, "notify::screen", () => {
          self.set_reveal_child(true);
          i++;
          timeout(1000, () => {
            i--;

            if (i === 0) self.set_reveal_child(false);
          });
        });
      }}
    >
      <box className="Osd-Base" vertical>
        <slider
          className="Osd-Slider"
          vertical
          value={bind(brightness, "screen")}
          onDragged={({ value }) => (brightness.screen = value)}
          drawValue={false}
          inverted
        />
        <icon icon="display-brightness-symbolic" />
      </box>
    </revealer>
  );
}

function VolumeSlider() {
  const audio = Wp.get_default().audio;

  const icons = {
    101: "overamplified",
    67: "high",
    34: "medium",
    1: "low",
    0: "muted",
  };

  function getIcon(vol) {
    const icon =
      vol === 0
        ? 0
        : [101, 67, 34, 1, 0].find(
            (threshold) => threshold <= audio.defaultSpeaker.volume * 100,
          );

    return `audio-volume-${icons[icon]}-symbolic`;
  }

  return (
    <revealer
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={125}
      setup={(self) => {
        let i = 0;

        self.hook(bind(audio.defaultSpeaker, "volume"), () => {
          self.set_reveal_child(true);
          i++;
          timeout(1000, () => {
            i--;

            if (i === 0) self.set_reveal_child(false);
          });
        });
      }}
    >
      <box className="Osd-Base" vertical>
        <slider
          className="Osd-Slider"
          vertical
          value={bind(audio.defaultSpeaker, "volume")}
          onDragged={({ value }) => (audio.defaultSpeaker.volume = value)}
          drawValue={false}
          inverted
        />
        <icon
          icon={bind(audio.defaultSpeaker, "volume").as((vol) => getIcon(vol))}
        />
      </box>
    </revealer>
  );
}

export default function OSD() {
  return (
    <window
      name={WINDOW_NAME}
      application={App}
      className="Osd"
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      anchor={Astal.WindowAnchor.RIGHT}
    >
      <box>
        <BrightnessSlider />
        <VolumeSlider />
      </box>
    </window>
  );
}
