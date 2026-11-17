use std::path::Path;
use std::thread;
use std::time::Duration;

use amane::{Apps, Service};

/*
 * whether the screen is being shared, and which apps are watching. umbriel's
 * ipc only carries the commands that pick a cast's target, not whether a share
 * is running, so this asks pipewire instead: a portal share publishes a video
 * source node for as long as it runs (a camera's node always carries a
 * device.api, so it's left out), and whoever watches it is linked to it.
 * a viewer's stream often carries no app of its own (zen's webrtc stream
 * doesn't), so then its client's is used. pw-dump -m streams the graph's
 * changes; jq keeps the sources, nodes, clients and links, and prints only
 * when the result changes: "<sources>\t<binary>\x1f<name>\x1e<binary>\x1f<name>".
 * capture that skips the portal (grim, wf-recorder) has no node and isn't seen
 */
const STREAM: &str = r#"pw-dump -m -N | jq --unbuffered -rn '
  def app($props):
    [$props["application.process.binary"] // "", $props["application.name"] // ""]
    | map(gsub("[\t\n\u001e\u001f]"; " ")) | join("\u001f");
  foreach (inputs | .[]) as $object ({sources: {}, nodes: {}, clients: {}, links: {}, last: null, out: null};
    ($object.id | tostring) as $id
    | if $object.info == null then
        del(.sources[$id], .nodes[$id], .clients[$id], .links[$id])
      elif $object.type == "PipeWire:Interface:Node" and ($object.info.props | type) == "object" then
        $object.info.props as $props
        | (if $props["media.class"] == "Video/Source" and $props["device.api"] == null
            then .sources[$id] = true
            else del(.sources[$id]) end)
        | .nodes[$id] = {app: app($props), client: ($props["client.id"] | tostring)}
      elif $object.type == "PipeWire:Interface:Client" and ($object.info.props | type) == "object" then
        .clients[$id] = app($object.info.props)
      elif $object.type == "PipeWire:Interface:Link" and $object.info["output-node-id"] != null then
        .links[$id] = [($object.info["output-node-id"] | tostring), ($object.info["input-node-id"] | tostring)]
      else . end
    | .last = .out
    | .sources as $sources
    | .nodes as $nodes
    | .clients as $clients
    | .out = ("\($sources | length)\t" + ([.links[] | select($sources[.[0]]) | $nodes[.[1]] // empty
        | if .app != "\u001f" then .app else ($clients[.client] // "\u001f") end
        | select(. != "\u001f")] | unique | join("\u001e")));
    select(.out != .last) | .out)'"#;

// an app linked to a shared source, as pipewire names it
#[derive(Debug, Clone, PartialEq)]
struct Viewer {
    // the process, "slack"; what a desktop entry's Exec runs
    binary: String,

    // what the app told pipewire it's called, "Slack", or sometimes a stream's name
    name: String,
}

#[derive(Default)]
pub struct Cast {
    // video sources being published right now; more than one when two shares run
    sources: usize,

    viewers: Vec<Viewer>,
}

impl Service for Cast {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        // the stream ends when pipewire restarts; never give up on it
        let mut wait = Duration::from_millis(500);

        loop {
            let heard = follow();

            // a share can't outlive the pipewire it ran on, and the next stream starts from a fresh snapshot
            set(0, Vec::new());

            wait = if heard {
                Duration::from_millis(500)
            } else {
                (wait * 2).min(Duration::from_secs(10))
            };

            thread::sleep(wait);
        }
    }
}

impl Cast {
    pub fn sharing(&self) -> bool {
        self.sources > 0
    }
}

/*
 * what to call each app watching the share: the name of the desktop entry that
 * runs its binary, else what it told pipewire. empty while the share has no
 * one linked yet. called from a view, so it subscribes to Cast and Apps
 */
pub fn viewers() -> Vec<String> {
    let viewers = Cast::read().viewers.clone();

    if viewers.is_empty() {
        return Vec::new();
    }

    let apps = Apps::read();
    let entries: Vec<(&str, &str)> = apps.list().iter().map(|app| (app.name(), app.exec())).collect();

    let mut names: Vec<String> = viewers.iter().map(|viewer| label(viewer, &entries)).collect();

    // two streams from one app are one viewer
    names.sort();
    names.dedup();

    names
}

// reads the stream until it ends; says whether anything arrived, for the reconnect backoff
fn follow() -> bool {
    let mut heard = false;

    for line in amane::lines(STREAM) {
        heard = true;

        if let Some((sources, viewers)) = parse(&line) {
            set(sources, viewers);
        }
    }

    heard
}

// a write redraws every window that reads Cast, so only write a real change
fn set(sources: usize, viewers: Vec<Viewer>) {
    let cast = Cast::read();
    let same = cast.sources == sources && cast.viewers == viewers;
    drop(cast);

    if !same {
        let mut cast = Cast::write();

        cast.sources = sources;
        cast.viewers = viewers;
    }
}

fn parse(line: &str) -> Option<(usize, Vec<Viewer>)> {
    let (count, rest) = line.split_once('\t')?;
    let sources = count.parse().ok()?;

    let viewers = rest
        .split('\u{1e}')
        .filter(|record| !record.is_empty())
        .map(|record| {
            let (binary, name) = record.split_once('\u{1f}').unwrap_or((record, ""));

            Viewer {
                binary: binary.trim().to_string(),
                name: name.trim().to_string(),
            }
        })
        .collect();

    Some((sources, viewers))
}

/*
 * entries are (name, exec) pairs from the desktop files. an entry that runs
 * the binary itself wins; failing that, one that runs a variant of it, since
 * zen's entry runs "zen-beta" and the browser's process is "zen"
 */
fn label(viewer: &Viewer, entries: &[(&str, &str)]) -> String {
    let binary = unwrapped(&viewer.binary);
    let variant = format!("{binary}-");

    let entry = (!binary.is_empty())
        .then(|| {
            entries
                .iter()
                .find(|(_, exec)| runs(exec) == binary)
                .or_else(|| entries.iter().find(|(_, exec)| runs(exec).starts_with(&variant)))
        })
        .flatten();

    match entry {
        Some((name, _)) => name.to_string(),
        None if !viewer.name.is_empty() => viewer.name.clone(),
        None => binary.to_string(),
    }
}

// the program an Exec line starts, by file name: "/nix/store/…/bin/slack -s %U" -> "slack"
fn runs(exec: &str) -> &str {
    let program = exec.split_whitespace().next().unwrap_or_default();

    let name = Path::new(program)
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or(program);

    unwrapped(name)
}

// nix wraps programs, so the process can be ".slack-wrapped" for an entry that runs "slack"
fn unwrapped(binary: &str) -> &str {
    binary
        .strip_prefix('.')
        .and_then(|name| name.strip_suffix("-wrapped"))
        .unwrap_or(binary)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn viewer(binary: &str, name: &str) -> Viewer {
        Viewer {
            binary: binary.to_string(),
            name: name.to_string(),
        }
    }

    #[test]
    fn reads_sources_and_viewers() {
        let (sources, viewers) = parse("1\tslack\u{1f}Slack\u{1e}obs\u{1f}OBS").unwrap_or_default();

        assert_eq!(sources, 1);
        assert_eq!(viewers, vec![viewer("slack", "Slack"), viewer("obs", "OBS")]);
    }

    #[test]
    fn a_share_no_one_watches_yet_has_no_viewers() {
        assert_eq!(parse("1\t"), Some((1, Vec::new())));
        assert_eq!(parse("0\t"), Some((0, Vec::new())));
    }

    #[test]
    fn ignores_anything_else() {
        assert_eq!(parse(""), None);
        assert_eq!(parse("error: pipewire"), None);
    }

    #[test]
    fn names_a_viewer_by_the_entry_that_runs_it() {
        let entries = [("Helium", "/nix/store/abc-helium/bin/helium %U"), ("Slack", "slack -s %U")];

        assert_eq!(label(&viewer("helium", "Helium input"), &entries), "Helium");
        assert_eq!(label(&viewer(".slack-wrapped", ""), &entries), "Slack");
    }

    #[test]
    fn an_entry_for_the_binary_beats_one_for_a_variant() {
        let entries = [("Zen Browser (Beta)", "zen-beta --name zen-beta %U"), ("Zen", "zen %U")];

        assert_eq!(label(&viewer("zen", "zen"), &entries), "Zen");
        assert_eq!(label(&viewer("zen", "zen"), &entries[..1]), "Zen Browser (Beta)");
    }

    #[test]
    fn falls_back_to_what_pipewire_was_told() {
        let entries = [("Slack", "slack -s %U")];

        assert_eq!(label(&viewer("obs", "OBS"), &entries), "OBS");
        assert_eq!(label(&viewer("obs", ""), &entries), "obs");
    }
}
