import Window from "@/common/window";
import icons from "@/util/icons";
import { createState, For } from "ags";
import { Astal, Gtk } from "ags/gtk4";
import { execAsync } from "ags/process";
import Pango from "gi://Pango";

const WINDOW_NAME = "clipboard";
const THUMB_DIR = "/tmp/cliphist/thumbs";

interface ClipboardItem {
  id: string;
  content: string;
  isImage: boolean;
  imagePath?: string;
}

export default function Clipboard() {
  let searchentry: Gtk.Entry;
  let win: Astal.Window;

  const [items, setItems] = createState(new Array<ClipboardItem>());
  const [filteredItems, setFilteredItems] = createState(
    new Array<ClipboardItem>(),
  );
  const [query, setQuery] = createState("");
  const [existingThumbs, setExistingThumbs] = createState<Set<string>>(
    new Set(),
  );

  // Initialize thumbnail directory
  execAsync(`mkdir -p "${THUMB_DIR}"`).then(() => {
    execAsync(`ls ${THUMB_DIR}`).then((output) => {
      setExistingThumbs(new Set(output.split("\n").filter(Boolean)));
    });
  });

  function parseClipboardItem(line: string): ClipboardItem {
    const parts = line.split("\t");
    const id = parts[0];
    const content = parts.slice(1).join("\t");

    const imageRegex = /^([0-9]+)\s(\[\[\s)?binary.*(jpg|jpeg|png|bmp)/;
    const isImage = imageRegex.test(line);

    return {
      id,
      content,
      isImage,
      imagePath: isImage ? generateImagePath(id) : undefined,
    };
  }

  function generateImagePath(id: string): string {
    const thumbs = existingThumbs.get();
    if (!thumbs.has(id)) {
      execAsync([
        "bash",
        "-c",
        `cliphist decode ${id} | magick - -resize 512x ${THUMB_DIR}/${id}.png`,
      ]).then(() => {
        setExistingThumbs(new Set([...thumbs, id]));
      });
    }
    return `${THUMB_DIR}/${id}.png`;
  }

  function loadClipboardHistory() {
    execAsync("cliphist list").then((output) => {
      const clipboardItems = output
        .split("\n")
        .filter(Boolean)
        .slice(0, 150)
        .map(parseClipboardItem);

      setItems(clipboardItems);
      setFilteredItems(clipboardItems);
    });
  }

  function copyToClipboard(item: ClipboardItem) {
    execAsync(["sh", "-c", `cliphist decode ${item.id} | wl-copy`]).then(() => {
      win.hide();
    });
  }

  function updateFilteredItems(searchQuery: string) {
    if (!searchQuery.trim()) {
      setFilteredItems(items.get());
    } else {
      setFilteredItems(
        items
          .get()
          .filter((item) =>
            item.content.toLowerCase().includes(searchQuery.toLowerCase()),
          ),
      );
    }
  }

  function SearchEntry() {
    return (
      <entry
        $={(ref) => (searchentry = ref)}
        onNotifyText={({ text }) => {
          setQuery(text);
          updateFilteredItems(text);
        }}
        class="px-5 py-2 bg-surface_container_low rounded-3xl mb-3"
        primaryIconName={icons.ui.search}
        placeholderText="Search clipboard history..."
      />
    );
  }

  function ClipboardItemWidget({ item }: { item: ClipboardItem }) {
    return (
      <button
        onClicked={() => copyToClipboard(item)}
        class="hover:bg-surface_container rounded-lg p-3 mb-2"
      >
        {item.isImage && item.imagePath ? (
          <image file={item.imagePath} class="min-h-[200px] max-h-[300px]" />
        ) : (
          <label
            label={item.content}
            xalign={0}
            wrap
            wrapMode={Pango.WrapMode.WORD_CHAR}
            maxWidthChars={80}
            ellipsize={Pango.EllipsizeMode.END}
            class="text-on_surface"
          />
        )}
      </button>
    );
  }

  return (
    <Window
      name={WINDOW_NAME}
      $={(ref) => (win = ref)}
      keymode={Astal.Keymode.EXCLUSIVE}
      layer={Astal.Layer.OVERLAY}
      onNotifyVisible={({ visible }) => {
        if (visible) {
          loadClipboardHistory();
          searchentry.grab_focus();
          setQuery("");
          updateFilteredItems("");
        } else {
          setQuery("");
        }
      }}
    >
      <box
        orientation={Gtk.Orientation.VERTICAL}
        class="bg-surface min-h-[500px] min-w-[500px] max-w-[800px] p-5 rounded-2xl"
        hexpand={false}
      >
        <SearchEntry />

        <scrolledwindow
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
          vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
          hexpand={false}
          vexpand
        >
          <box
            orientation={Gtk.Orientation.VERTICAL}
            spacing={0}
            hexpand={false}
          >
            <For each={filteredItems}>
              {(item) => <ClipboardItemWidget item={item} />}
            </For>
          </box>
        </scrolledwindow>
      </box>
    </Window>
  );
}
