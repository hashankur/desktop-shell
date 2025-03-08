import { Gtk } from "astal/gtk4";
import { GLib } from "astal";
import Pango from "gi://Pango";
import AstalNotifd from "gi://AstalNotifd";

const time = (time: number, format = "%I:%M %p") =>
  GLib.DateTime.new_from_unix_local(time).format(format);

const isIcon = (icon: string) => {
  const iconTheme = new Gtk.IconTheme();
  return iconTheme.has_icon(icon);
};

const fileExists = (path: string) => GLib.file_test(path, GLib.FileTest.EXISTS);

const urgency = (n: AstalNotifd.Notification) => {
  const { LOW, NORMAL, CRITICAL } = AstalNotifd.Urgency;

  switch (n.urgency) {
    case LOW:
      return "low";
    case CRITICAL:
      return "critical";
    case NORMAL:
    default:
      return "normal";
  }
};

export default function Notification({
  n,
  showActions = true,
}: {
  n: AstalNotifd.Notification;
  showActions?: boolean;
}) {
  return (
    <box
      name={n.id.toString()}
      cssClasses={[
        "bg-surface_container_high",
        "p-5",
        "rounded-xl",
        "min-w-[435px]",
        "min-h-[10px]",
        urgency(n),
      ]}
      hexpand={false}
      vexpand={false}
    >
      <box vertical>
        <box cssClasses={["mb-2"]} spacing={10}>
          {(n.appIcon || n.desktopEntry) && (
            <image
              cssClasses={["app-icon"]}
              visible={!!(n.appIcon || n.desktopEntry)}
              iconName={n.appIcon || n.desktopEntry}
              type="symbolic" // TODO
            />
          )}
          <label
            cssClasses={["app-name"]}
            halign={Gtk.Align.START}
            label={n.appName || "Unknown"}
          />
          <label
            cssClasses={["time"]}
            hexpand
            halign={Gtk.Align.END}
            label={time(n.time)!}
          />
          <button onClicked={() => n.dismiss()}>
            <image iconName={"window-close-symbolic"} />
          </button>
        </box>
        <Gtk.Separator visible orientation={Gtk.Orientation.HORIZONTAL} />
        <box cssClasses={["content"]} spacing={10}>
          {n.image && fileExists(n.image) && (
            <box valign={Gtk.Align.START} cssClasses={["image"]}>
              <image
                file={n.image}
                overflow={Gtk.Overflow.HIDDEN}
                cssClasses={["icon-2xl", "rounded-md"]}
              />
            </box>
          )}
          {n.image && isIcon(n.image) && (
            <box cssClasses={["icon-xl"]} valign={Gtk.Align.START}>
              <image
                iconName={n.image}
                // iconSize={Gtk.IconSize.LARGE}
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.CENTER}
                cssClasses={["icon-2xl"]}
              />
            </box>
          )}
          <box hexpand vertical>
            <label
              ellipsize={Pango.EllipsizeMode.END}
              maxWidthChars={30}
              cssClasses={["text-xl", "mb-1", "font-bold"]}
              halign={Gtk.Align.START}
              xalign={0}
              label={n.summary}
            />
            {n.body && (
              <label
                cssClasses={[
                  "text-[15px]",
                  "font-medium",
                  "text-on_surface_variant",
                ]}
                maxWidthChars={30}
                wrap
                halign={Gtk.Align.START}
                xalign={0}
                label={n.body}
                tooltipMarkup={n.body}
                ellipsize={Pango.EllipsizeMode.END}
              />
            )}
          </box>
        </box>
        {showActions && n.get_actions().length > 0 && (
          <box cssClasses={["actions"]} spacing={6}>
            {n.get_actions().map(({ label, id }) => (
              <button
                hexpand
                onClicked={() => n.invoke(id)}
                cssClasses={["bg-gray-900", "rounded-lg", "p-2", "m-2"]}
              >
                <label label={label} halign={Gtk.Align.CENTER} hexpand />
              </button>
            ))}
          </box>
        )}
      </box>
    </box>
  );
}
