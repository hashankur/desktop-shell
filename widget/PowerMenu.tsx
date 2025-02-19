import Window from "@/common/window";
import icons from "@/util/icons";
import { exec } from "astal";
import { App } from "astal/gtk4";

const WINDOW_NAME = "power-menu";

const options = [
  {
    name: "Shutdown",
    icon: icons.powermenu.shutdown,
    command: "systemctl poweroff",
  },
  {
    name: "Reboot",
    icon: icons.powermenu.reboot,
    command: "systemctl reboot",
  },
  {
    name: "Suspend",
    icon: icons.powermenu.sleep,
    command: "systemctl suspend",
  },
];

export default function PowerMenu() {
  return (
    <Window name={WINDOW_NAME}>
      <box cssClasses={["bg-base", "rounded-xl", "p-3"]} spacing={10}>
        {options.map((option) => (
          <button
            on_Clicked={() => {
              App.toggle_window(WINDOW_NAME);
              exec(option.command);
            }}
            cssClasses={[
              "rounded-lg",
              "bg-base1",
              "hover:bg-base",
              "transition",
            ]}
          >
            <image cssClasses={["p-10", "icon-xl"]} iconName={option.icon} />
          </button>
        ))}
      </box>
    </Window>
  );
}
