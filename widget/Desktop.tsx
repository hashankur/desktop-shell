import Window from "@/common/window";
import { GLib, Variable } from "astal";
import { Astal } from "astal/gtk4";

const WINDOW_NAME = "desktop";
const time = Variable("").poll(
  60_000,
  () => GLib.DateTime.new_now_local().format("%A\n%B %d") ?? "",
);

export default function Desktop() {
  const { LEFT, BOTTOM } = Astal.WindowAnchor;

  return (
    <Window
      name={WINDOW_NAME}
      anchor={LEFT | BOTTOM}
      visible
      keymode={Astal.Keymode.NONE}
      layer={Astal.Layer.BACKGROUND}
      namespace="astal-desktop"
      default_width={-1}
    >
      <box cssClasses={["m-8"]} vertical>
        <label
          label={time()}
          cssClasses={[
            "text-shadow",
            // "text-on_primary_container",
            "text-[100px]",
            "font-black",
          ]}
        />
      </box>
    </Window>
  );
}
