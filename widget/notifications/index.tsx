import { useNotificationHandler } from "@/lib/notification";
import icons from "@/util/icons";
import { createBinding, createState, For, onCleanup } from "ags";
import { Gtk } from "ags/gtk4";
import AstalNotifd from "gi://AstalNotifd";
import Notification from "./Notification";

export const WINDOW_NAME = "notifications";

const notifd = AstalNotifd.get_default();
const [notifications, setNotifications] = createState(
  new Array<AstalNotifd.Notification>(),
);

setNotifications(notifd.notifications);

onCleanup(useNotificationHandler(notifd, notifications, setNotifications));

function NotifsScrolledWindow() {
  return (
    <Gtk.ScrolledWindow vexpand>
      <box
        orientation={Gtk.Orientation.VERTICAL}
        hexpand={false}
        spacing={8}
        cssClasses={["px-2"]}
      >
        <For each={notifications}>
          {(notification) => <Notification notification={notification} />}
        </For>
        <box
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
          orientation={Gtk.Orientation.VERTICAL}
          vexpand
          visible={notifications((ns) => ns.length === 0)}
          spacing={10}
        >
          <image
            iconName={icons.notifications.empty}
            cssClasses={["icon-3xl"]}
          />
          <label label="Your inbox is empty" cssClasses={["text-xl"]} />
        </box>
      </box>
    </Gtk.ScrolledWindow>
  );
}

function DNDButton() {
  return (
    <button
      tooltipText={"Do Not Disturb"}
      onClicked={() => {
        notifd.set_dont_disturb(!notifd.get_dont_disturb());
      }}
      cssClasses={createBinding(notifd, "dont_disturb").as((dnd) => {
        const classes = [
          "hover:bg-surface_container_high",
          "px-2",
          "py-1",
          "rounded-lg",
        ];
        dnd && classes.push("bg-secondary_container");
        return classes;
      })}
      label={"DND"}
    />
  );
}

function ClearButton() {
  return (
    <button
      cssClasses={["hover:bg-error_container", "p-2", "rounded-lg"]}
      onClicked={() => {
        notifd.notifications.forEach((n) => n.dismiss());
      }}
      sensitive={createBinding(notifd, "notifications").as((n) => n.length > 0)}
    >
      <image iconName={"user-trash-full-symbolic"} />
    </button>
  );
}

export default function Notifications() {
  return (
    <box
      cssClasses={["p-3", "rounded-3xl", "min-w-[475px]"]}
      orientation={Gtk.Orientation.VERTICAL}
      vexpand
    >
      <box cssClasses={["p-2"]} spacing={10}>
        <label label={"Notifications"} hexpand xalign={0} />
        <DNDButton />
        <ClearButton />
      </box>
      <NotifsScrolledWindow />
    </box>
  );
}
