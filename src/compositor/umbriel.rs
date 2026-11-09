use amane::Service;

use super::{Desktop, Focused, Space};

/*
 * umbriel streams full snapshots as json lines:
 * {"event":"workspaces","data":[...]} and {"event":"windows","data":[...]}.
 * an amane shell has no json crate, so jq flattens each snapshot into one
 * line: "W" plus tab-separated workspaces split by \x1e, or "T" plus the
 * focused window's app id and title. @tsv escapes tabs and newlines in titles
 */
const STREAM: &str = r#"umbriel subscribe workspaces,windows | jq --unbuffered -r '
  if .event == "workspaces" then
    "W\t" + ([.data[] | [
      (.index | tostring), (.name // ""), (.output // ""),
      (if .active then "1" else "0" end),
      (if .focused then "1" else "0" end),
      (if .occupied then "1" else "0" end)
    ] | @tsv] | join("\u001e"))
  elif .event == "windows" then
    "T\t" + ((.data | map(select(.focused)) | first) // {} | [.app_id // "", .title // ""] | @tsv)
  else empty end'"#;

// reads the stream until it ends; says whether anything arrived, for the reconnect backoff
pub fn follow() -> bool {
    let mut heard = false;

    for line in amane::lines(STREAM) {
        heard = true;

        if let Some(body) = line.strip_prefix("W\t") {
            let spaces = body.split('\u{1e}').filter_map(space).collect();

            // a write redraws every window that reads Desktop, so only write a real change
            if Desktop::read().spaces != spaces {
                Desktop::write().spaces = spaces;
            }
        } else if let Some(body) = line.strip_prefix("T\t") {
            let mut fields = body.split('\t').map(unescape);

            let app_id = fields.next().unwrap_or_default();
            let title = fields.next().unwrap_or_default();

            let focused = (!app_id.is_empty() || !title.is_empty()).then_some(Focused { app_id, title });

            // a title change on an unfocused window is an event too, and changes nothing shown
            if Desktop::read().focused != focused {
                Desktop::write().focused = focused;
            }
        }
    }

    heard
}

fn space(record: &str) -> Option<Space> {
    let fields: Vec<String> = record.split('\t').map(unescape).collect();

    let [index, name, output, active, focused, occupied] = fields.as_slice() else {
        return None;
    };

    Some(Space {
        index: index.parse().ok()?,
        name: name.clone(),
        output: output.clone(),
        active: active == "1",
        focused: focused == "1",
        occupied: occupied == "1",
    })
}

// undoes jq's @tsv escapes: \t \n \r \\
fn unescape(field: &str) -> String {
    let mut out = String::with_capacity(field.len());
    let mut chars = field.chars();

    while let Some(c) = chars.next() {
        if c != '\\' {
            out.push(c);
            continue;
        }

        match chars.next() {
            Some('t') => out.push(' '),
            Some('n') | Some('r') => out.push(' '),
            Some('\\') => out.push('\\'),
            Some(other) => {
                out.push('\\');
                out.push(other);
            }
            None => out.push('\\'),
        }
    }

    out
}

pub fn switch_to(space: &Space) {
    // names and outputs come from umbriel's own config, but quote them anyway
    let target = format!("{}/{}", space.index, space.output).replace('\'', "");

    amane::spawn(&format!("umbriel msg 'workspace-switch:{target}'"));
}
