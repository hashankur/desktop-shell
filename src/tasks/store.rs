use std::fs;
use std::path::PathBuf;
use std::time::SystemTime;

use super::{List, Task};
use crate::files;
use crate::theme;

fn path() -> PathBuf {
    theme::state_folder().join("tasks")
}

/*
 * the last lists and open tasks google gave, so a restart or a reload
 * starts with them. one per line, tab separated: "list", id, title; then
 * "task", id, list, due day (empty for none), position, title
 */
pub fn load() -> (Vec<List>, Vec<Task>) {
    let text = fs::read_to_string(path()).unwrap_or_default();

    let (mut lists, mut tasks) = (Vec::new(), Vec::new());

    for line in text.lines() {
        let mut fields = line.splitn(6, '\t');

        match fields.next() {
            Some("list") => {
                if let (Some(id), Some(title)) = (fields.next(), fields.next()) {
                    lists.push(List {
                        id: id.to_string(),
                        title: title.to_string(),
                    });
                }
            }

            Some("task") => {
                if let Some(task) = parse_task(fields) {
                    tasks.push(task);
                }
            }

            _ => {}
        }
    }

    (lists, tasks)
}

fn parse_task<'a>(mut fields: impl Iterator<Item = &'a str>) -> Option<Task> {
    Some(Task {
        id: fields.next()?.to_string(),
        list: fields.next()?.to_string(),
        due: fields.next()?.parse().ok(),
        position: fields.next()?.to_string(),
        title: fields.next()?.to_string(),
        done: false,
    })
}

pub fn save(lists: &[List], tasks: &[Task]) {
    let mut text = String::new();

    for list in lists {
        text.push_str(&format!("list\t{}\t{}\n", clean(&list.id), clean(&list.title)));
    }

    for task in tasks {
        let due = task.due.map(|day| day.to_string()).unwrap_or_default();

        text.push_str(&format!(
            "task\t{}\t{}\t{due}\t{}\t{}\n",
            clean(&task.id),
            clean(&task.list),
            clean(&task.position),
            clean(&task.title)
        ));
    }

    let _ = files::write_atomic(&path(), &text);
}

// when the tasks were last fetched, which is when they were last saved
pub fn fetched_at() -> Option<SystemTime> {
    fs::metadata(path()).ok()?.modified().ok()
}

pub fn forget() {
    let _ = fs::remove_file(path());
}

// a tab or a line break would split the line
fn clean(text: &str) -> String {
    text.replace(['\t', '\n', '\r'], " ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_a_task_line() {
        let task = parse_task("t1\tlist\t20405\t0001\tpay\tthe bill".splitn(5, '\t')).unwrap();

        assert_eq!((task.id.as_str(), task.list.as_str(), task.due), ("t1", "list", Some(20405)));
        assert_eq!(task.title, "pay\tthe bill");

        let undated = parse_task("t2\tlist\t\t0002\tsomeday".splitn(5, '\t')).unwrap();

        assert_eq!(undated.due, None);
        assert!(parse_task("t3\tlist".splitn(5, '\t')).is_none());
    }
}
