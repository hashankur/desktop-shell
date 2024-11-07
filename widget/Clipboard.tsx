import { bind, Variable } from "astal";
import { App, Astal, Gdk, Gtk, Widget } from "astal/gtk3";
import { exec, execAsync } from "astal/process";

const WINDOW_NAME = "clipboard";

const cliphist = Variable<string>("");
const query = Variable<string>("");

export default function Clipboard() {
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
            cliphist.set(exec("cliphist list"));
            // Entry.grab_focus();
          }
        });
      }}
    >
      <box className="AppLauncher base" vertical>
        {/* {Entry} */}
        <scrollable vexpand>
          <box vertical spacing={10}>
            {bind(cliphist).as((str) =>
              str.split("\n").map((item) => (
                <button
                  className="Clipboard-Item"
                  on_Clicked={() => {
                    execAsync([
                      "sh",
                      "-c",
                      `cliphist decode ${(item.match("[0-9]+") ?? [""])[0]} | wl-copy`,
                    ]);
                    App.toggle_window(WINDOW_NAME);
                  }}
                >
                  {/* {item.match("binary.*(jpg|jpeg|png|bmp)") ? (
                  <box
                    className="Cover"
                    valign={Gtk.Align.CENTER}
                    css={`
                      background-image: url("data:image/png;base64,${execAsync([
                        "sh",
                        "-c",
                        `cliphist decode ${(item.match("[0-9]+") ?? [""])[0]} | base64 -w 0`,
                      ])}");
                    `}
                  />
                ) : ( */}
                  <label label={item} truncate halign={Gtk.Align.START} />
                  {/* )} */}
                </button>
              )),
            )}
          </box>
        </scrollable>
      </box>
    </window>
  );
}
