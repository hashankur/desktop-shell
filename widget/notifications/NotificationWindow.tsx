import AstalNotifd from "gi://AstalNotifd";
import { bind } from "astal";
import { Gtk } from "astal/gtk4";
import Notification from "./Notification";

export const WINDOW_NAME = "notifications";
const notifd = AstalNotifd.get_default();

function NotifsScrolledWindow() {
  const notifd = AstalNotifd.get_default();
  return (
    <Gtk.ScrolledWindow vexpand>
      <box vertical hexpand={false} spacing={8} cssClasses={["px-2"]}>
        {bind(notifd, "notifications").as((notifs) =>
          notifs
            .sort((a, b) => b.time - a.time)
            .map((e) => <Notification n={e} showActions={false} />),
        )}
        <box
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
          cssClasses={["not-found"]}
          vertical
          vexpand
          visible={bind(notifd, "notifications").as((n) => n.length === 0)}
        >
          <image
            iconName="notification-disabled-symbolic"
            iconSize={Gtk.IconSize.LARGE}
          />
          <label label="Your inbox is empty" />
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
      cssClasses={bind(notifd, "dont_disturb").as((dnd) => {
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
      sensitive={bind(notifd, "notifications").as((n) => n.length > 0)}
    >
      <image iconName={"user-trash-full-symbolic"} />
    </button>
  );
}

export function NotificationWindow() {
  return (
    <box cssClasses={["p-3", "rounded-3xl", "min-w-[475px]"]} vertical vexpand>
      <box cssClasses={["p-2"]} spacing={10}>
        <label label={"Notifications"} hexpand xalign={0} />
        <DNDButton />
        <ClearButton />
      </box>
      <NotifsScrolledWindow />
    </box>
  );
}
