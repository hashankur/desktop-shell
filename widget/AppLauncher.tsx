import { App, Astal, Gdk, Gtk, Widget } from "astal/gtk3";
import { bind, Variable } from "astal";
import AstalApps from "gi://AstalApps";

const WINDOW_NAME = "app-launcher";

const apps = new AstalApps.Apps({
  includeEntry: true,
  includeExecutable: true,
});

const query = Variable<string>("");

export default function AppLauncher() {
  const items = query((query) =>
    apps.fuzzy_query(query).map((app: AstalApps.Application) => (
      <button
        on_Clicked={() => {
          App.toggle_window(WINDOW_NAME);
          app.launch();
        }}
      >
        <box hexpand={false}>
          <icon className="AppIcon" icon={app.iconName || ""} />
          <box className="AppText" vertical valign={Gtk.Align.CENTER}>
            <label
              className="AppName"
              label={app.name}
              halign={Gtk.Align.START}
              truncate
            />
            {app.description && (
              <label
                className="AppDescription"
                label={app.description}
                halign={Gtk.Align.START}
                truncate
              />
            )}
          </box>
        </box>
      </button>
    )),
  );

  const Entry = new Widget.Entry({
    text: bind(query),
    hexpand: true,
    canFocus: true,
    placeholderText: "Search",
    className: "AppLauncher-Input",
    // primaryIconName: "edit-find",
    onActivate: () => {
      // items.get()[0]?.app.launch(); // TODO: fix launch first item on press enter
      App.toggle_window(WINDOW_NAME);
    },
    setup: (self) => {
      self.hook(self, "notify::text", () => {
        query.set(self.get_text());
      });
    },
  });

  return (
    <window
      name={WINDOW_NAME}
      application={App}
      visible={false}
      keymode={Astal.Keymode.EXCLUSIVE}
      layer={Astal.Layer.OVERLAY}
      vexpand={true}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          if (self.visible) {
            query.set("");
            Entry.grab_focus();
            self.visible = false;
          }
        }
      }}
      setup={(self) => {
        self.hook(self, "notify::visible", () => {
          if (!self.get_visible()) {
            query.set("");
            // TODO: reset scroll
          } else {
            Entry.grab_focus();
          }
        });
      }}
    >
      <box className="AppLauncher base" vertical>
        {Entry}
        <scrollable vexpand>
          <box className="AppLauncher-ItemName" vertical spacing={10}>
            {items}
          </box>
        </scrollable>
      </box>
    </window>
  );
}
