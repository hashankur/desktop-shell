use super::kind::{self, Kind};

// one entry of the history: cliphist's id, its one-line preview, and what it looks like
#[derive(Clone, PartialEq)]
pub struct Clip {
    pub id: String,
    pub text: String,
    pub kind: Kind,
}

/*
 * `cliphist list` prints one entry per line, newest first: its numeric id, a
 * tab, then a one-line preview, cut at 100 characters. an image has no text,
 * so cliphist writes "[[ binary data 4 KiB png 188x75 ]]" in its place
 */
pub fn clips(raw: &str) -> Vec<Clip> {
    raw.lines().filter_map(clip).collect()
}

fn clip(line: &str) -> Option<Clip> {
    let (id, preview) = line.split_once('\t')?;

    // the id ends up in a command to copy it back, so only digits are trusted
    if !is_id(id) {
        return None;
    }

    let (text, kind) = match image(preview) {
        Some((weight, format, size)) => (
            format!("image · {format} · {size}"),
            Kind::Image {
                format: format.to_lowercase(),
                size,
                weight,
            },
        ),
        None => {
            let text = one_line(preview);
            let kind = kind::of(&text);

            (text, kind)
        }
    };

    Some(Clip {
        id: id.to_string(),
        text,
        kind,
    })
}

pub fn is_id(id: &str) -> bool {
    !id.is_empty() && id.bytes().all(|byte| byte.is_ascii_digit())
}

// the weight, format and size out of an image's placeholder, like ("4 KiB", "png", "188×75")
fn image(preview: &str) -> Option<(String, &str, String)> {
    let inner = preview
        .strip_prefix("[[ binary data ")?
        .strip_suffix(" ]]")?;

    // "4 KiB png 188x75"
    let parts: Vec<&str> = inner.split_whitespace().collect();

    let [amount, unit, format, size] = parts.as_slice() else {
        return None;
    };

    Some((format!("{amount} {unit}"), format, size.replace('x', "×")))
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

        let list = clips(raw);

        assert_eq!(list.len(), 2);

        assert_eq!(list[0].id, "44584");
        assert_eq!(list[0].text, "image · png · 188×75");
        assert_eq!(
            list[0].kind,
            Kind::Image {
                format: String::from("png"),
                size: String::from("188×75"),
                weight: String::from("4 KiB"),
            }
        );

        assert_eq!(list[1].id, "44582");
        assert_eq!(list[1].text, "cargo build");
        assert_eq!(list[1].kind, Kind::Text);
    }

    #[test]
    fn skips_lines_without_a_numeric_id() {
        assert!(clips("no tab here\nabc\tword\n\ttext\n12; rm -rf x\tevil\n").is_empty());
    }

    #[test]
    fn a_whitespace_clip_still_has_a_name() {
        assert_eq!(clips("7\t   \n")[0].text, "(whitespace)");
    }

    #[test]
    fn a_placeholder_that_is_not_one_stays_text() {
        let list = clips("9\t[[ binary data lots ]]\n");

        assert_eq!(list[0].kind, Kind::Text);
    }

    #[test]
    fn an_empty_history_is_an_empty_list() {
        assert!(clips("").is_empty());
    }
}

