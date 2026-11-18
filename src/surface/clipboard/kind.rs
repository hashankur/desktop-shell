use crate::theme::clipboard;

// what a clip looks like, read from its one-line preview alone
#[derive(Clone, Debug, PartialEq)]
pub enum Kind {
    Text,

    // the site it points at, like "docs.rs"
    Link(String),

    Path,

    // looks like a password, so it is shown as dots until asked for
    Secret,

    // as cliphist describes it: "png", "1606×926", "160 KiB"
    Image {
        format: String,
        size: String,
        weight: String,
    },
}

pub fn of(text: &str) -> Kind {
    if let Some(host) = host(text) {
        return Kind::Link(host);
    }

    if is_path(text) {
        return Kind::Path;
    }

    if is_secret(text) {
        return Kind::Secret;
    }

    Kind::Text
}

// a web address on its own, without the "www."
fn host(text: &str) -> Option<String> {
    if text.contains(char::is_whitespace) {
        return None;
    }

    let rest = text
        .strip_prefix("https://")
        .or_else(|| text.strip_prefix("http://"))?;

    let host = rest.split(['/', '?', '#']).next()?;
    let host = host.strip_prefix("www.").unwrap_or(host);

    (!host.is_empty()).then(|| host.to_string())
}

// a file's place, not a command that starts with one: "/usr/bin/foo --all" has flags
fn is_path(text: &str) -> bool {
    let rooted = text.len() > 1 && (text.starts_with('/') || text.starts_with("~/"));

    rooted && !text.contains(" -") && !text.starts_with("//")
}

/*
 * one word that mixes at least three of lowercase, uppercase, digits and
 * symbols, and keeps switching between them, the way a generated password
 * does. "Base64Encoder" mixes three but switches only three times in
 * thirteen, so it stays text. a guess: a token or an id may be hidden too,
 * and enter still copies whatever is hidden
 */
fn is_secret(text: &str) -> bool {
    let length = text.chars().count();

    if !(clipboard::SECRET_MIN..=clipboard::SECRET_MAX).contains(&length) {
        return false;
    }

    if text.contains(char::is_whitespace) || is_not_secret(text) {
        return false;
    }

    let classes: Vec<u8> = text.chars().map(class).collect();

    let mixed = [0, 1, 2, 3]
        .iter()
        .filter(|wanted| classes.contains(wanted))
        .count();

    let switches = classes.windows(2).filter(|pair| pair[0] != pair[1]).count();

    mixed >= 3 && switches as f32 >= length as f32 * clipboard::SECRET_SWITCHES
}

// shapes that mix kinds of letter but are ids, not passwords: an address, a NAME=url line, a uuid or hash
fn is_not_secret(text: &str) -> bool {
    let address = text.contains("://");

    let email = text.split_once('@').is_some_and(|(name, domain)| {
        !name.is_empty()
            && domain.contains('.')
            && domain.chars().all(|letter| letter.is_ascii_alphanumeric() || letter == '.' || letter == '-')
    });

    let hex = text.chars().all(|letter| letter.is_ascii_hexdigit() || letter == '-');

    address || email || hex
}

fn class(letter: char) -> u8 {
    if letter.is_lowercase() {
        0
    } else if letter.is_uppercase() {
        1
    } else if letter.is_ascii_digit() {
        2
    } else {
        3
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn links_name_their_site() {
        assert_eq!(
            of("https://www.docs.rs/zbus/latest/zbus/struct.Connection.html"),
            Kind::Link(String::from("docs.rs"))
        );
        assert_eq!(of("http://localhost:8000?x=1"), Kind::Link(String::from("localhost:8000")));
        assert_eq!(of("see https://example.com"), Kind::Text);
    }

    #[test]
    fn paths_are_places_not_commands() {
        assert_eq!(of("~/Pictures/Screenshots/Screenshot from 2026-11-17 21-04-11.png"), Kind::Path);
        assert_eq!(of("/tmp/ot-seed/trigger.py"), Kind::Path);
        assert_eq!(of("/usr/bin/foo --all"), Kind::Text);
        assert_eq!(of("/"), Kind::Text);
        assert_eq!(of("// a comment"), Kind::Text);
    }

    #[test]
    fn generated_passwords_are_hidden() {
        assert_eq!(of("q7#Lm2v!Tx9pR4wZ"), Kind::Secret);
        assert_eq!(of("aB3$xY9!kL"), Kind::Secret);
        assert_eq!(of("Zp4-wQ8_nR2-tK6"), Kind::Secret);
    }

    #[test]
    fn ordinary_words_and_names_are_not() {
        for text in [
            "Base64Encoder",
            "Calendar::months",
            "list::DESCRIPTION_CHARS",
            "8e7db2a",
            "8e7db2a9f0c4b1d2e3f4a5b6c7d8e9f0a1b2c3d4",
            "feat/partner-managed-billing",
            "Xiaomi Redmi 15",
            "E020",
            "user@example.com",
            "DATABASE_URL=postgres://127.0.0.1:5432",
            "bot-name@project-a1b2c3.iam.gserviceaccount.com",
            "3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f",
        ] {
            assert_eq!(of(text), Kind::Text, "{text}");
        }
    }
}
