import { App, Astal, Gdk, Gtk, Widget } from "astal/gtk3";
import { bind, Variable } from "astal";
import AstalApps from "gi://AstalApps";

const WINDOW_NAME = "app-launcher"

const apps = new AstalApps.Apps({
  includeEntry: true,
  includeExecutable: true,
});

const query = Variable<string>("");

export default function AppLauncher() {
  const items = query((query) =>
    apps
      .fuzzy_query(query)
      .map((app: AstalApps.Application) => (
        <button on_Clicked={() => {
          App.toggle_window(WINDOW_NAME)
          app.launch()
        }}>
          {app.name}
        </button >
      )),
  );

  const Entry = new Widget.Entry({
    text: bind(query),
    hexpand: true,
    canFocus: true,
    placeholderText: "Search",
    className: "AppLauncher-Input",
    onActivate: () => {
      items.get()[0]?.app.launch();
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
      className="AppLauncher"
      keymode={Astal.Keymode.EXCLUSIVE}
      exclusivity={Astal.Exclusivity.NORMAL}
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
    // setup={(self) => {
    //   self.hook(self, "notify::visible", () => {
    //     if (!self.get_visible()) {
    //       query.set("");
    //     } else {
    //       Entry.grab_focus();
    //     }
    //   });
    // }}
    >
      <box className="AppLauncher-Base" vertical>
        {Entry}
        <scrollable vexpand>
          <box className="AppLauncher-ItemName" vertical>
            {items}
          </box>
        </scrollable>
      </box>
    </window>
  );
}
