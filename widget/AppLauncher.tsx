import Window from "@/widget/common/window";
import icons from "@/constants/icons";
import { createComputed } from "ags";
import { createState, For } from "ags";
import { Astal, Gdk, Gtk } from "ags/gtk4";
import Adw from "gi://Adw";
import AstalApps from "gi://AstalApps";
import Pango from "gi://Pango";

const WINDOW_NAME = "app-launcher";

export default function AppLauncher() {
  let searchentry: Gtk.Entry;
  let win: Astal.Window;

  const apps = new AstalApps.Apps();
  const [list, setList] = createState(new Array<AstalApps.Application>());

  function search(text: string) {
    if (text === "") setList([]);
    else setList(apps.fuzzy_query(text).slice(0, 5));
  }

  function launch(app?: AstalApps.Application) {
    if (app) {
      win.hide();
      app.launch();
    }
  }

  // handle alt + number key
  function onKey(
    _e: Gtk.EventControllerKey,
    keyval: number,
    _: number,
    mod: number,
  ) {
    if (mod === Gdk.ModifierType.ALT_MASK) {
      for (const i of [1, 2, 3, 4, 5, 6, 7, 8, 9] as const) {
        if (keyval === Gdk[`KEY_${i}`]) {
          return launch(list.get()[i - 1]);
        }
      }
    }
  }

  function SearchEntry() {
    return (
      <entry
        $={(ref) => (searchentry = ref)}
        onNotifyText={({ text }) => search(text)}
        class="px-5 py-2 bg-surface_container_low rounded-3xl my-1"
        primaryIconName={icons.ui.search}
        placeholderText="Start typing to search"
      />
    );
  }

  const { BOTTOM } = Astal.WindowAnchor;

  return (
    <Window
      name={WINDOW_NAME}
      $={(ref) => (win = ref)}
      anchor={BOTTOM}
      onNotifyVisible={({ visible }) => {
        if (visible) searchentry.grab_focus();
        else searchentry.set_text("");
      }}
    >
      <Gtk.EventControllerKey onKeyPressed={onKey} />
      <Adw.Clamp maximumSize={600}>
        <box
          widthRequest={600}
          name="launcher-content"
          class="bg-surface rounded-2xl p-4"
          orientation={Gtk.Orientation.VERTICAL}
          valign={Gtk.Align.CENTER}
        >
          <SearchEntry />
          <box orientation={Gtk.Orientation.VERTICAL}>
            <For each={list}>
              {(app, index) => (
                <button
                  onClicked={() => launch(app)}
                  class="hover:bg-surface_container px-4 mt-1 rounded-xl"
                >
                  <box spacing={20}>
                    <image class="my-2 icon-xl" iconName={app.iconName} />
                    <box>
                      <box
                        orientation={Gtk.Orientation.VERTICAL}
                        valign={Gtk.Align.CENTER}
                      >
                        <label
                          class="text-xl font-bold text-on_surface"
                          label={app.name}
                          xalign={0}
                          ellipsize={Pango.EllipsizeMode.END}
                        />
                        {app.description && (
                          <label
                            class="font-medium text-on_surface_variant"
                            label={app.description}
                            xalign={0}
                            ellipsize={Pango.EllipsizeMode.END}
                          />
                        )}
                      </box>
                    </box>
                    <label
                      hexpand
                      halign={Gtk.Align.END}
                      label={index((i) => `Alt ${i + 1}`)}
                    />
                  </box>
                </button>
              )}
            </For>
          </box>
        </box>
      </Adw.Clamp>
    </Window>
  );
}
