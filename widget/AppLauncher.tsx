import Window from "@/common/window";
import { hideWindow } from "@/util/util";
import { Variable } from "astal";
import { App, Gtk, hook } from "astal/gtk4";
import Apps from "gi://AstalApps";
import Pango from "gi://Pango";

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
        cssClasses={["hover:bg-base1", "px-5", "mb-1", "rounded-xl"]}
      >
        <box hexpand={false} spacing={20}>
          <image
            cssClasses={["my-5", "icon-xl"]}
            iconName={app.iconName || ""}
          />
          <box vertical valign={Gtk.Align.CENTER}>
            <label
              cssClasses={["text-xl", "font-bold"]}
              label={app.name}
              xalign={0}
              ellipsize={Pango.EllipsizeMode.END}
            />
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

  function SearchEntry() {
    const onEnter = () => {
      apps.fuzzy_query(query.get())?.[0].launch();
      hideWindow(WINDOW_NAME);
    };

    return (
      <entry
        cssClasses={["p-5", "bg-base1", "rounded-2xl"]}
        type="overlay"
        vexpand
        primaryIconName={"system-search-symbolic"}
        placeholderText="Search..."
        text={query.get()}
        setup={(self) => {
          hook(self, App, "window-toggled", (_, win) => {
            const winName = win.name;
            const visible = win.visible;

            if (winName == WINDOW_NAME && visible) {
              query.set("");
              self.set_text("");
              self.grab_focus();
            }
          });
        }}
        onChanged={(self) => query.set(self.text)}
        onActivate={onEnter}
      />
    );
  }

  return (
    <Window name={WINDOW_NAME}>
      <box
        cssClasses={["min-w-[450px]", "bg-base", "rounded-xl", "p-5"]}
        vertical
        spacing={10}
      >
        <SearchEntry />
        <Gtk.ScrolledWindow vexpand cssClasses={["min-h-[510px]"]}>
          <box vertical>{items}</box>
        </Gtk.ScrolledWindow>
      </box>
    </Window>
  );
}
