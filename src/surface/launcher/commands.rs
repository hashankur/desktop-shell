use crate::surface::list::{Entry, Group};
use crate::surface::{Kind, Surface, power, search};

// what typing it before a query does: the launcher lists commands instead of apps
pub const PREFIX: char = '>';

/*
 * the commands, in the order they show before anything is typed: the
 * power surface first, then its actions. more join here as they come
 * (screenshot, wallpaper, ...)
 */
fn all() -> Vec<Entry> {
    let mut entries = vec![entry("power", "the power surface")];

    entries.extend(power::commands().map(|(label, description)| entry(label, description)));

    entries
}

fn entry(name: &str, description: &str) -> Entry {
    Entry {
        id: name.to_string(),
        name: name.to_string(),
        description: description.to_string(),
    }
}

// the commands matching what follows the prefix, best first; all of them when nothing does yet
pub fn groups(query: &str) -> Vec<Group> {
    let query = query.trim();

    if query.is_empty() {
        return vec![Group {
            label: "commands",
            entries: all(),
        }];
    }

    let mut scored: Vec<(f32, Entry)> = all()
        .into_iter()
        .filter_map(|entry| search::score(query, &entry.name).map(|score| (score, entry)))
        .collect();

    scored.sort_by(|a, b| b.0.total_cmp(&a.0));

    let entries: Vec<Entry> = scored.into_iter().map(|(_, entry)| entry).collect();

    let label = if entries.is_empty() {
        "no such command"
    } else {
        "commands"
    };

    vec![Group { label, entries }]
}

/*
 * runs a picked command. power actions go through the power surface, which
 * asks before anything but lock, so none of them happens on a stray enter
 */
pub fn run(name: &str) {
    match name {
        "power" => Surface::open(Kind::Power),
        label => power::start(label),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn names(groups: &[Group]) -> Vec<String> {
        groups
            .iter()
            .flat_map(|group| group.entries.iter().map(|entry| entry.name.clone()))
            .collect()
    }

    #[test]
    fn an_empty_query_lists_every_command_with_power_first() {
        let shown = names(&groups(""));

        assert_eq!(shown.first().map(String::as_str), Some("power"));
        assert!(shown.contains(&String::from("shutdown")));
        assert!(shown.contains(&String::from("lock")));
    }

    #[test]
    fn a_query_keeps_only_matching_commands() {
        let shown = names(&groups("reb"));

        assert_eq!(shown, vec![String::from("reboot")]);
    }

    #[test]
    fn nothing_matching_says_so() {
        let found = groups("zzz");

        assert_eq!(found.first().map(|group| group.label), Some("no such command"));
        assert!(names(&found).is_empty());
    }
}
