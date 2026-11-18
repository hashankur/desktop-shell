// cut to a character count, not bytes, so a title in any script cuts cleanly
pub fn shorten(text: &str, limit: usize) -> String {
    if text.chars().count() <= limit {
        return text.to_string();
    }

    let mut short: String = text.chars().take(limit.saturating_sub(1)).collect();
    short.push('…');

    short
}

/*
 * a notification body as plain text: senders may use the spec's simple
 * markup (<b>, <i>, <a href>) and its escapes, which would otherwise show
 * as typed. a line break tag becomes a break, and blank lines are dropped:
 * a body is cut after a few lines, and browsers put an empty one between
 * the site and the message, which would push the message out
 */
pub fn plain(markup: &str) -> String {
    let mut text = String::with_capacity(markup.len());
    let mut rest = markup;

    while let Some(open) = rest.find('<') {
        text.push_str(&rest[..open]);

        let Some(close) = rest[open..].find('>') else {
            // a lone "<" is text, not a tag
            text.push_str(&rest[open..]);
            rest = "";
            break;
        };

        let tag = &rest[open + 1..open + close];

        if tag.trim_end_matches('/').trim().eq_ignore_ascii_case("br") {
            text.push('\n');
        }

        rest = &rest[open + close + 1..];
    }

    text.push_str(rest);

    let text = text
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&#39;", "'")
        .replace("&amp;", "&");

    text.lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>()
        .join("\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn drops_markup_from_a_body() {
        assert_eq!(plain("<b>Ferris</b> said &quot;hi&quot;"), "Ferris said \"hi\"");
        assert_eq!(plain("a<br/>b"), "a\nb");
        assert_eq!(plain("<a href=\"x\">link</a> &amp; more"), "link & more");
        assert_eq!(plain("1 < 2"), "1 < 2");
        assert_eq!(plain("  plain  "), "plain");
        assert_eq!(plain("site\n\n\nmessage\n"), "site\nmessage");
    }

    #[test]
    fn keeps_short_text_whole() {
        assert_eq!(shorten("kitty", 5), "kitty");
    }

    #[test]
    fn cuts_by_characters_not_bytes() {
        assert_eq!(shorten("日本語のタイトル", 4), "日本語…");
    }
}
