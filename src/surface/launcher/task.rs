use amane::Service;

use crate::clock::Clock;
use crate::surface::list::{self, Entry, Group};
use crate::surface::search;
use crate::tasks::{self, Task, Tasks, due};

/*
 * "> task" and a title adds a google task without opening anything else;
 * a date at the end sets when it's due. a row per list says where it goes,
 * the main list first. open tasks matching the words show under them, and
 * picking one ticks it off. with no title yet there are no rows, so a
 * stray enter does nothing
 */

// the command's word, and what the query becomes after one is added, ready for the next
pub const WORD: &str = "task";
const READY: &str = ">task ";

// rows for adding, one per list, then open tasks up to the launcher's nine
const ADD_ROWS: usize = 3;
const ROWS: usize = 9;

// a picked row's id: what to do, then its fields, tab separated
const ADD: &str = "add";
const TICK: &str = "tick";

// the words after "task" when the command query is a task, none otherwise
pub fn words(command: &str) -> Option<&str> {
    let rest = command.trim_start().strip_prefix(WORD)?;

    (rest.is_empty() || rest.starts_with(char::is_whitespace)).then_some(rest)
}

// the command list's own row for this command, which fills in the word
pub fn start() {
    list::set_query(READY);
}

pub fn groups(words: &str) -> Vec<Group> {
    let tasks = Tasks::read();

    if !tasks.ready() {
        return vec![Group {
            label: "sign in to google again to allow tasks",
            entries: Vec::new(),
        }];
    }

    let today = Clock::read().days();
    let (title, due) = due::split(words, today);

    let mut groups = Vec::new();

    if !title.is_empty() {
        let when = due.map_or_else(|| String::from("no date"), |day| due::label(day, today));
        let day = due.map(|day| day.to_string()).unwrap_or_default();

        let entries: Vec<Entry> = tasks
            .lists()
            .iter()
            .take(ADD_ROWS)
            .map(|list| Entry {
                id: format!("{ADD}\t{}\t{day}\t{title}", list.id),
                name: title.clone(),
                description: format!("{when} · {}", list.title),
            })
            .collect();

        groups.push(Group {
            label: "add a task",
            entries,
        });
    }

    let room = ROWS.saturating_sub(groups.first().map_or(0, |group| group.entries.len()));

    let open = matching(&title, tasks.tasks(), room);

    let open: Vec<Entry> = open
        .into_iter()
        .map(|task| {
            let when = match task.due {
                _ if task.done => String::from("done"),
                Some(day) => due::label(day, today),
                None => String::from("no date"),
            };

            Entry {
                id: format!("{TICK}\t{}", task.id),
                name: task.title.clone(),
                description: format!("{when} · {}", tasks.list_title(&task.list)),
            }
        })
        .collect();

    if groups.is_empty() && open.is_empty() {
        groups.push(Group {
            label: "type the task; end with a date to set when it's due",
            entries: Vec::new(),
        });
    }

    if !open.is_empty() {
        groups.push(Group {
            label: "open tasks",
            entries: open,
        });
    }

    groups
}

/*
 * the open tasks a title matches, best first. none for no title: then
 * the first row would be a task, and an enter pressed out of habit after
 * adding one would tick it off at google
 */
fn matching<'a>(title: &str, tasks: &'a [Task], room: usize) -> Vec<&'a Task> {
    if title.is_empty() {
        return Vec::new();
    }

    let mut scored: Vec<(f32, &Task)> = tasks
        .iter()
        .filter_map(|task| search::score(title, &task.title).map(|score| (score, task)))
        .collect();

    scored.sort_by(|a, b| b.0.total_cmp(&a.0));

    scored.into_iter().take(room).map(|(_, task)| task).collect()
}

/*
 * acts on a picked row: adds the task and clears the title for the next
 * one, or ticks an open one off (or back on). false for an id that isn't
 * a task's
 */
pub fn run(id: &str) -> bool {
    let mut fields = id.splitn(4, '\t');

    match fields.next() {
        Some(ADD) => {
            if let (Some(list_id), Some(day), Some(title)) = (fields.next(), fields.next(), fields.next()) {
                tasks::add(list_id, title, day.parse().ok());
                list::set_query(READY);
            }

            true
        }

        Some(TICK) => {
            if let Some(task) = fields.next() {
                tasks::toggle(task);
            }

            true
        }

        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn knows_a_task_query() {
        assert_eq!(words("task"), Some(""));
        assert_eq!(words(" task oat milk"), Some(" oat milk"));
        assert_eq!(words("tasks"), None);
        assert_eq!(words("tas"), None);
        assert_eq!(words("reboot"), None);
    }

    fn task(title: &str) -> Task {
        Task {
            id: title.to_string(),
            list: String::from("list"),
            title: title.to_string(),
            due: None,
            position: String::new(),
            done: false,
        }
    }

    #[test]
    fn no_title_offers_no_task_to_tick() {
        let tasks = [task("buy oat milk"), task("book the dentist")];

        assert!(matching("", &tasks, 9).is_empty());

        let found: Vec<&str> = matching("milk", &tasks, 9).iter().map(|task| task.title.as_str()).collect();

        assert_eq!(found, ["buy oat milk"]);
    }
}
