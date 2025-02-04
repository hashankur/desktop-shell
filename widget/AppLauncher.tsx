import Window from "@/common/window";
import { bind, Variable } from "astal";
import { App, Gtk, Widget } from "astal/gtk4";
import Apps from "gi://AstalApps";
import Pango from "gi://Pango?version=1.0";

const WINDOW_NAME = "app-launcher";

const apps = new Apps.Apps();

const query = Variable<string>("");

export default function AppLauncher() {
  let appData: Apps.Application[] = [];

  const items = query((query) => {
    appData = apps.fuzzy_query(query);
    return appData.map((app: Apps.Application) => (
      <button
        on_Clicked={() => {
          App.toggle_window(WINDOW_NAME);
          app.launch();
        }}
      >
        <box hexpand={false} spacing={20}>
          <image cssClasses={["my-5", "icon-xl"]} iconName={app.iconName || ""} />
          <box vertical valign={Gtk.Align.CENTER}>
            <label cssClasses={["text-xl", "font-bold"]} label={app.name} xalign={0} ellipsize={Pango.EllipsizeMode.END} />
            {app.description && (
              <label
                cssName="AppDescription"
                label={app.description}
                xalign={0}
                ellipsize={Pango.EllipsizeMode.END}
              />
            )}
          </box>
        </box>
      </button>
    ));
  });

  const Entry = Widget.Entry({
    text: bind(query),
    hexpand: true,
    canFocus: true,
    placeholderText: "Search",
    cssClasses: ["p-5"],
    // primaryIconName: "edit-find",
    onActivate: () => {
      appData[0]?.launch();
      App.toggle_window(WINDOW_NAME);
    },
    setup: (self) => {
      // self.hook(self, "notify::text", () => {
      //   query.set(self.get_text());
      // });
    },
  });

  return (
    <Window
      name={WINDOW_NAME}
      setup={(self) => {
        // self.hook(self, "notify::visible", () => {
        //   if (!self.get_visible()) {
        //     query.set("");
        //     // TODO: reset scroll
        //   } else {
        //     Entry.grab_focus();
        //   }
        // });
      }}
    >
      <box cssClasses={["min-w-[450px]", "bg-base", "rounded-xl", "p-5"]} vertical>
        {Entry}
        <Gtk.ScrolledWindow vexpand cssClasses={["min-h-[510px]"]}>
          <box cssClasses={["p-5"]} vertical>
            {items}
          </box>
        </Gtk.ScrolledWindow>
      </box>
    </Window>
  );
}
