import Window from "@/common/window";
import { bind, Variable } from "astal";
import { App, Astal, Gtk, hook, Widget } from "astal/gtk4";
import { execAsync } from "astal/process";
import Pango from "gi://Pango";

const WINDOW_NAME = "clipboard";

const cliphist = Variable<string[]>([]);
const changes = Variable<string[]>([]);
const query = Variable<string>(" ");
const init = Variable<boolean>(true);

const thumb_dir = "/tmp/cliphist/thumbs";
let existingThumbs = "";

execAsync(`mkdir -p "${thumb_dir}"`).then(() => {
  execAsync(`ls ${thumb_dir}`).then((output) => {
    existingThumbs = output;
  });
});

function differences<T>(list1: T[], list2: T[]): T[] {
  return list1.filter((item) => !list2.includes(item));
}

function decodeImage(index: string) {
  if (!existingThumbs.includes(index)) {
    execAsync([
      "bash",
      "-c",
      `cliphist decode ${index} | magick - -resize 512x ${thumb_dir}/${index}.png`,
    ]).then(() => {
      existingThumbs += index;
    });
  }
  return `${thumb_dir}/${index}.png`;
}

const itemWidget = (item: string, image: any) => (
  <button
    hexpand={false}
    vexpand
    visible={item.match(query.get()) != null}
    on_Clicked={() => {
      execAsync([
        "sh",
        "-c",
        `cliphist decode ${(item.match("[0-9]+") ?? [""])[0]} | wl-copy`,
      ]);
      App.toggle_window(WINDOW_NAME);
    }}
    cssClasses={["hover:bg-surface_container", "rounded-lg", "p-3"]}
  >
    {image ? (
      <image
        file={item}
        cssClasses={["min-h-[450px]"]}
        keepAspectRatio={true}
        contentFit={Gtk.ContentFit.COVER}
      />
    ) : (
      <label
        label={item.split("\t").slice(1).join("\t")}
        xalign={0}
        wrap
        wrapMode={Pango.WrapMode.WORD_CHAR}
        vexpand
        hexpand={false}
      />
    )}
  </button>
);

export default function Clipboard() {
  const Entry = Widget.Entry({
    text: bind(query),
    hexpand: true,
    canFocus: true,
    placeholderText: "Search",
    onActivate: () => {
      App.toggle_window(WINDOW_NAME);
    },
    setup: (self) => {
      hook(self, self, "notify::text", () => {
        query.set(self.get_text());
      });
    },
  });

  const Items: Variable<Gtk.Widget[]> = Variable([]);

  const ItemsWatcher = Variable.derive([changes], (changes) => {
    for (let item of changes.slice(0, 150)) {
      itemHolder.set(item);
    }
  });

  const itemHolder = Variable("");

  const regex = /^([0-9]+)\s(\[\[\s)?binary.*(jpg|jpeg|png|bmp)/;

  const watcher = Variable.derive([itemHolder], (item) => {
    const image = item.match(regex);

    if (image) {
      // print(decodeImage(item.split("\t")[0]));
      item = decodeImage(item.split("\t")[0]);
      // console.info(item);
    }

    // print(item);
    init.get()
      ? Items.set([...Items.get(), itemWidget(item, image)])
      : Items.set([itemWidget(item, image), ...Items.get()]);
  });

  return (
    <Window
      name={WINDOW_NAME}
      className={WINDOW_NAME}
      application={App}
      visible={false}
      keymode={Astal.Keymode.EXCLUSIVE}
      layer={Astal.Layer.OVERLAY}
      vexpand={true}
      hexpand={false}
      setup={(self) => {
        hook(self, self, "notify::visible", () => {
          if (!self.get_visible()) {
            query.set(" ");
          } else {
            execAsync("cliphist list").then((output) => {
              changes.set(differences(output.split("\n"), cliphist.get()));
              cliphist.set(output.split("\n"));
              init.set(false);
            });
            query.set("");
            Entry.grab_focus();
          }
        });
      }}
    >
      <box
        vertical
        hexpand={false}
        cssClasses={[
          "bg-surface",
          "min-h-[500px]",
          "min-w-[500px]",
          "p-5",
          "rounded-2xl",
        ]}
      >
        {Entry}
        <Gtk.ScrolledWindow hexpand={false}>
          <box vertical spacing={5} vexpand hexpand={false}>
            {bind(Items)}
          </box>
        </Gtk.ScrolledWindow>
      </box>
    </Window>
  );
}
