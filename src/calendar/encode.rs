use std::fs::File;
use std::io::Read;

// the characters a url, and pkce's verifier, take as they are
fn unreserved(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'.' | b'_' | b'~')
}

// everything but the unreserved characters as %XX, for query strings and form bodies
pub fn percent(text: &str) -> String {
    let mut out = String::with_capacity(text.len());

    for byte in text.bytes() {
        if unreserved(byte) {
            out.push(byte as char);
        } else {
            out.push_str(&format!("%{byte:02X}"));
        }
    }

    out
}

// back from %XX, with + as a space the way forms send it; a broken escape is kept as written
pub fn unpercent(text: &str) -> String {
    let bytes = text.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut index = 0;

    while index < bytes.len() {
        match bytes[index] {
            b'%' => {
                let value = text
                    .get(index + 1..index + 3)
                    .and_then(|hex| u8::from_str_radix(hex, 16).ok());

                if let Some(value) = value {
                    out.push(value);
                    index += 3;
                    continue;
                }

                out.push(b'%');
            }

            b'+' => out.push(b' '),

            byte => out.push(byte),
        }

        index += 1;
    }

    String::from_utf8_lossy(&out).into_owned()
}

// key=value pairs joined with &, each side encoded: a query string or a form body
pub fn form(pairs: &[(&str, &str)]) -> String {
    pairs
        .iter()
        .map(|(key, value)| format!("{}={}", percent(key), percent(value)))
        .collect::<Vec<_>>()
        .join("&")
}

// the value of one key in a query string like "code=4%2F0A&state=xyz"
pub fn query_value(query: &str, key: &str) -> Option<String> {
    query.split('&').find_map(|pair| {
        let (name, value) = pair.split_once('=').unwrap_or((pair, ""));

        (unpercent(name) == key).then(|| unpercent(value))
    })
}

// base64 with the url alphabet and no padding, as pkce's challenge is written
pub fn base64_url(bytes: &[u8]) -> String {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

    let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);

    for chunk in bytes.chunks(3) {
        let joined = chunk
            .iter()
            .enumerate()
            .fold(0u32, |joined, (index, byte)| joined | u32::from(*byte) << (16 - 8 * index));

        // n bytes carry n + 1 characters' worth of bits
        for index in 0..=chunk.len() {
            out.push(ALPHABET[(joined >> (18 - 6 * index) & 63) as usize] as char);
        }
    }

    out
}

// a random string of unreserved characters, for pkce's verifier and the state check
pub fn random(length: usize) -> Option<String> {
    const ALPHABET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";

    let mut bytes = vec![0u8; length];

    File::open("/dev/urandom").ok()?.read_exact(&mut bytes).ok()?;

    // 256 isn't a multiple of 66, so a few characters come up slightly more often; harmless for a one-time secret
    Some(
        bytes
            .into_iter()
            .map(|byte| ALPHABET[byte as usize % ALPHABET.len()] as char)
            .collect(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encodes_and_decodes() {
        let text = "4/0A b&c=d+é";

        assert_eq!(percent("http://127.0.0.1:8080"), "http%3A%2F%2F127.0.0.1%3A8080");
        assert_eq!(unpercent(&percent(text)), text);
        assert_eq!(unpercent("a+b%2"), "a b%2");
    }

    #[test]
    fn finds_query_values() {
        let query = "state=xyz&code=4%2F0AbC&scope=https%3A%2F%2Fwww.googleapis.com";

        assert_eq!(query_value(query, "code").as_deref(), Some("4/0AbC"));
        assert_eq!(query_value(query, "state").as_deref(), Some("xyz"));
        assert_eq!(query_value(query, "error"), None);
    }

    #[test]
    fn builds_forms() {
        assert_eq!(form(&[("a", "1 2"), ("b", "x/y")]), "a=1%202&b=x%2Fy");
    }

    #[test]
    fn writes_url_base64_without_padding() {
        assert_eq!(base64_url(b""), "");
        assert_eq!(base64_url(b"f"), "Zg");
        assert_eq!(base64_url(b"fo"), "Zm8");
        assert_eq!(base64_url(b"foo"), "Zm9v");
        assert_eq!(base64_url(&[0xfb, 0xff]), "-_8");
    }

    #[test]
    fn makes_random_strings() {
        let one = random(43).unwrap();

        assert_eq!(one.len(), 43);
        assert!(one.bytes().all(unreserved));
        assert_ne!(one, random(43).unwrap());
    }
}
