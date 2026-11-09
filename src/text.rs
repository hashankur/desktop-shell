// cut to a character count, not bytes, so a title in any script cuts cleanly
pub fn shorten(text: &str, limit: usize) -> String {
    if text.chars().count() <= limit {
        return text.to_string();
    }

    let mut short: String = text.chars().take(limit.saturating_sub(1)).collect();
    short.push('…');

    short
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keeps_short_text_whole() {
        assert_eq!(shorten("kitty", 5), "kitty");
    }

    #[test]
    fn cuts_by_characters_not_bytes() {
        assert_eq!(shorten("日本語のタイトル", 4), "日本語…");
    }
}
