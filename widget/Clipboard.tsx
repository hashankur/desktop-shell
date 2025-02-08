import Window from "@/common/window";
import { bind, Variable } from "astal";
import { App, Gtk, hook } from "astal/gtk4";
import { exec, execAsync } from "astal/process";
import Pango from "gi://Pango";

const WINDOW_NAME = "clipboard";

const cliphist = Variable<string>("");

export default function Clipboard() {
  return (
    <Window
      name={WINDOW_NAME}
      setup={(self) => {
        hook(self, self, "notify::visible", () => {
          if (!self.get_visible()) {
            // query.set("");
            // TODO: reset scroll
          } else {
            cliphist.set(exec("cliphist list"));
            // Entry.grab_focus();
          }
        });
      }}
    >
      <box cssClasses={["bg-base", "min-h-[500px]", "min-w-[500px]", "p-5", "rounded-2xl"]} vertical>
        <Gtk.ScrolledWindow vexpand>
          <box vertical spacing={5}>
            {bind(cliphist).as((str) =>
              str.split("\n").map((item) => (
                <button
                  cssClasses={["hover:bg-base1", "rounded-lg", "p-3"]}
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
                  <label label={item} ellipsize={Pango.EllipsizeMode.END} halign={Gtk.Align.START} />
                  {/* )} */}
                </button>
              )),
            )}
          </box>
        </Gtk.ScrolledWindow>
      </box>
    </Window>
  );
}
