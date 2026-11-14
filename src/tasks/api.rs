use super::due;
use super::{List, Task};
use crate::google::encode::{form, percent, unescape};
use crate::google::{access_token, get, jq, run, send};

const API: &str = "https://tasks.googleapis.com/tasks/v1";

// the most google gives in one page, for lists and tasks alike
const PAGE: &str = "100";

/*
 * one page of task lists: the next page's token on the first line (empty
 * on the last page), then one line per list: id and title
 */
const LISTS: &str = r#"(.nextPageToken // ""), (.items[]? | [.id, (.title // "")] | @tsv)"#;

/*
 * one page of a list's open tasks, the token first as above. completed and
 * deleted ones are left out even if google sends them, and so are blank
 * ones, which google's apps leave behind while a task is being typed
 */
const TASKS: &str = r#"(.nextPageToken // ""),
    (.items[]?
    | select(.status != "completed" and (.deleted // false | not))
    | select((.title // "") | test("\\S"))
    | [.id, (.due // ""), (.position // ""), .title]
    | @tsv)"#;

/*
 * every list and every open task in them. tasks come sorted by when
 * they're due, undated last, then by list and by their place in it. any
 * page that fails fails the whole fetch, so the caller keeps what it had
 */
pub fn everything(now: i64) -> Result<(Vec<List>, Vec<Task>), &'static str> {
    let token = access_token(now).ok_or("couldn't renew the access token; if it keeps failing, sign in again")?;

    let mut lists: Vec<List> = Vec::new();

    for line in pages(&format!("{API}/users/@me/lists"), &[], LISTS, &token)
        .ok_or("couldn't fetch the task lists; is the tasks api enabled in google cloud?")?
    {
        let mut fields = line.split('\t');

        if let (Some(id), Some(title)) = (fields.next(), fields.next()) {
            lists.push(List {
                id: id.to_string(),
                title: unescape(title),
            });
        }
    }

    /*
     * google's apps add to the default list, which isn't always first in
     * the listing; asking for it by its alias gives its id. if that fails
     * the order stays as it came
     */
    if let Some(main) = get(&format!("{API}/users/@me/lists/@default"), &token).and_then(|body| jq(".id // \"\"", &body)) {
        main_first(&mut lists, main.trim());
    }

    let mut tasks: Vec<Task> = Vec::new();

    for list in &lists {
        let url = format!("{API}/lists/{}/tasks", percent(&list.id));
        let query = [("showCompleted", "false"), ("showHidden", "false"), ("showAssigned", "true")];

        for line in pages(&url, &query, TASKS, &token).ok_or("couldn't fetch a task list")? {
            if let Some(task) = parse_line(&line, &list.id) {
                tasks.push(task);
            }
        }
    }

    sort(&mut tasks, &lists);

    Ok((lists, tasks))
}

// moves the list with this id to the front, keeping the others in order
fn main_first(lists: &mut Vec<List>, id: &str) {
    if let Some(at) = lists.iter().position(|list| list.id == id) {
        let main = lists.remove(at);

        lists.insert(0, main);
    }
}
/*
 * when they're due, undated last, then the lists in google's order, then
 * each task's place in its list, which google gives as text that sorts
 */
pub fn sort(tasks: &mut [Task], lists: &[List]) {
    let order = |task: &Task| lists.iter().position(|list| list.id == task.list).unwrap_or(usize::MAX);

    tasks.sort_by(|a, b| {
        (a.due.is_none(), a.due, order(a), &a.position).cmp(&(b.due.is_none(), b.due, order(b), &b.position))
    });
}

/*
 * the lines a filter makes of every page at a url, following each page's
 * token to the next. none if any page fails
 */
fn pages(url: &str, query: &[(&str, &str)], filter: &str, token: &str) -> Option<Vec<String>> {
    let mut lines = Vec::new();
    let mut next = String::new();

    loop {
        let mut pairs: Vec<(&str, &str)> = vec![("maxResults", PAGE)];

        pairs.extend_from_slice(query);

        if !next.is_empty() {
            pairs.push(("pageToken", &next));
        }

        let page = jq(filter, &get(&format!("{url}?{}", form(&pairs)), token)?)?;
        let mut page_lines = page.lines();

        let token_line = page_lines.next().unwrap_or_default().to_string();

        lines.extend(page_lines.filter(|line| !line.is_empty()).map(str::to_string));

        if token_line.is_empty() {
            return Some(lines);
        }

        next = token_line;
    }
}

fn parse_line(line: &str, list: &str) -> Option<Task> {
    let mut fields = line.split('\t');

    let id = fields.next()?.to_string();
    let due = due::parse(fields.next()?);
    let position = fields.next()?.to_string();
    let title = unescape(fields.next()?);

    if id.is_empty() {
        return None;
    }

    Some(Task {
        id,
        list: list.to_string(),
        title,
        due,
        position,
        done: false,
    })
}

/*
 * ticks a task off, or back on. unticking clears the time it was done too,
 * which is what google's apps send
 */
pub fn set_done(list: &str, id: &str, done: bool, now: i64) -> Result<(), &'static str> {
    let token = access_token(now).ok_or("couldn't renew the access token")?;

    let body = if done {
        r#"{"status":"completed"}"#
    } else {
        r#"{"status":"needsAction","completed":null}"#
    };

    let url = format!("{API}/lists/{}/tasks/{}", percent(list), percent(id));

    send("PATCH", &url, &token, body).map(|_| ()).ok_or("couldn't change a task")
}

/*
 * a new task at the top of a list, as google's apps put it; its id back.
 * the body is built by jq, which quotes whatever the title holds
 */
pub fn add(list: &str, title: &str, due: Option<i64>, now: i64) -> Result<String, &'static str> {
    let token = access_token(now).ok_or("couldn't renew the access token")?;

    let due = due.map(due::format).unwrap_or_default();

    let body = run(
        "jq",
        &[
            "-nc",
            "--arg", "title", title,
            "--arg", "due", &due,
            r#"{title: $title} + (if $due == "" then {} else {due: $due} end)"#,
        ],
        "",
    )
    .ok_or("couldn't write the new task")?;

    let url = format!("{API}/lists/{}/tasks", percent(list));

    let reply = send("POST", &url, &token, body.trim()).ok_or("couldn't add the task")?;

    let id = jq(r#".id // """#, &reply).ok_or("google's reply to a new task had no id")?;
    let id = id.trim();

    if id.is_empty() {
        return Err("google's reply to a new task had no id");
    }

    Ok(id.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clock::days_from_civil;

    const PAGE_ONE: &str = r#"{"nextPageToken": "abc", "items": [
        {"id": "t1", "title": "pay the\telectricity bill", "status": "needsAction", "due": "2026-11-10T00:00:00.000Z", "position": "00000000000000000001"},
        {"id": "t2", "title": "done already", "status": "completed", "position": "2"},
        {"id": "t3", "title": "   ", "status": "needsAction", "position": "3"},
        {"id": "t4", "title": "gone", "status": "needsAction", "deleted": true, "position": "4"},
        {"id": "t5", "title": "someday", "status": "needsAction", "position": "00000000000000000005"}
    ]}"#;

    #[test]
    fn reads_a_page_of_open_tasks() {
        let page = jq(TASKS, PAGE_ONE).unwrap();
        let mut lines = page.lines();

        assert_eq!(lines.next(), Some("abc"));

        let tasks: Vec<Task> = lines.filter_map(|line| parse_line(line, "list")).collect();
        let titles: Vec<&str> = tasks.iter().map(|task| task.title.as_str()).collect();

        assert_eq!(titles, ["pay the electricity bill", "someday"]);
        assert_eq!(tasks[0].due, Some(days_from_civil(2026, 11, 10)));
        assert_eq!(tasks[1].due, None);
    }

    #[test]
    fn a_last_page_has_no_token() {
        let page = jq(LISTS, r#"{"items": [{"id": "MDE", "title": "My Tasks"}]}"#).unwrap();

        assert_eq!(page.lines().collect::<Vec<_>>(), ["", "MDE\tMy Tasks"]);
    }

    #[test]
    fn sorts_by_due_then_list_then_place() {
        let task = |id: &str, list: &str, due: Option<i64>, position: &str| Task {
            id: id.to_string(),
            list: list.to_string(),
            title: id.to_string(),
            due,
            position: position.to_string(),
            done: false,
        };

        let lists = [
            List { id: String::from("a"), title: String::new() },
            List { id: String::from("b"), title: String::new() },
        ];

        let mut tasks = [
            task("undated", "a", None, "1"),
            task("later", "a", Some(20), "1"),
            task("b first", "b", Some(10), "1"),
            task("a second", "a", Some(10), "2"),
            task("a first", "a", Some(10), "1"),
        ];

        sort(&mut tasks, &lists);

        let order: Vec<&str> = tasks.iter().map(|task| task.id.as_str()).collect();

        assert_eq!(order, ["a first", "a second", "b first", "later", "undated"]);
    }

    #[test]
    fn puts_the_main_list_first() {
        let list = |id: &str| List { id: id.to_string(), title: String::new() };
        let mut lists = vec![list("work"), list("main"), list("groceries")];

        main_first(&mut lists, "main");
        main_first(&mut lists, "missing");

        let order: Vec<&str> = lists.iter().map(|list| list.id.as_str()).collect();

        assert_eq!(order, ["main", "work", "groceries"]);
    }
}
