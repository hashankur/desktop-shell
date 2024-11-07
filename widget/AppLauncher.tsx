import { bind, Variable } from "astal";
import { App, Astal, Gdk, Gtk, Widget } from "astal/gtk3";
import Apps from "gi://AstalApps";

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
        <box hexpand={false}>
          <icon className="AppIcon" icon={app.iconName || ""} />
          <box className="AppText" vertical valign={Gtk.Align.CENTER}>
            <label className="AppName" label={app.name} xalign={0} truncate />
            {app.description && (
              <label
                className="AppDescription"
                label={app.description}
                xalign={0}
                truncate
              />
            )}
          </box>
        </box>
      </button>
    ));
  });

  const Entry = new Widget.Entry({
    text: bind(query),
    hexpand: true,
    canFocus: true,
    placeholderText: "Search",
    className: "AppLauncher-Input",
    // primaryIconName: "edit-find",
    onActivate: () => {
      appData[0]?.launch();
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
          <box className="AppLauncher-ItemName" vertical spacing={5}>
            {items}
          </box>
        </scrollable>
      </box>
    </window>
  );
}
