use crate::surface::list::Entry;

/*
 * `cliphist list` prints one entry per line, newest first: its numeric id, a
 * tab, then a one-line preview. an image has no text, so cliphist writes
 * "[[ binary data 4 KiB png 188x75 ]]" in its place
 */
pub fn entries(raw: &str) -> Vec<Entry> {
    raw.lines().filter_map(entry).collect()
}

fn entry(line: &str) -> Option<Entry> {
    let (id, preview) = line.split_once('\t')?;

    // the id ends up in a shell command to copy it back, so only digits are trusted
    if id.is_empty() || !id.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }

    let (name, description) = match image(preview) {
        Some((format, size)) => (format!("image · {format} · {size}"), "image"),
        None => (one_line(preview), "text"),
    };

    Some(Entry {
        id: id.to_string(),
        name,
        description: description.to_string(),
    })
}

// the format and size out of an image's placeholder, like ("png", "188×75")
fn image(preview: &str) -> Option<(&str, String)> {
    let inner = preview
        .strip_prefix("[[ binary data ")?
        .strip_suffix(" ]]")?;

    // "4 KiB png 188x75"
    let parts: Vec<&str> = inner.split_whitespace().collect();

    let [_, _, format, size] = parts.as_slice() else {
        return None;
    };

    Some((format, size.replace('x', "×")))
}

// runs of whitespace become one space; a clip of only whitespace gets a name
fn one_line(text: &str) -> String {
    let line = text.split_whitespace().collect::<Vec<_>>().join(" ");

    if line.is_empty() {
        String::from("(whitespace)")
    } else {
        line
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_text_and_images() {
        let raw = "44584\t[[ binary data 4 KiB png 188x75 ]]\n44582\tcargo   build\n";

        let list = entries(raw);

        assert_eq!(list.len(), 2);

        assert_eq!(list[0].id, "44584");
        assert_eq!(list[0].name, "image · png · 188×75");
        assert_eq!(list[0].description, "image");

        assert_eq!(list[1].id, "44582");
        assert_eq!(list[1].name, "cargo build");
        assert_eq!(list[1].description, "text");
    }

    #[test]
    fn skips_lines_without_a_numeric_id() {
        assert!(entries("no tab here\nabc\tword\n\ttext\n12; rm -rf x\tevil\n").is_empty());
    }

    #[test]
    fn a_whitespace_clip_still_has_a_name() {
        assert_eq!(entries("7\t   \n")[0].name, "(whitespace)");
    }

    #[test]
    fn a_placeholder_that_is_not_one_stays_text() {
        let list = entries("9\t[[ binary data lots ]]\n");

        assert_eq!(list[0].description, "text");
    }

    #[test]
    fn an_empty_history_is_an_empty_list() {
        assert!(entries("").is_empty());
    }
}
