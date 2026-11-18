/*
 * what the preview draws: tabs as four spaces, and the spaces that indent a
 * line made unbreakable, since wrapping splits on plain spaces and would
 * drop them. other control characters go, and so does the blank tail
 */
pub fn tidy(raw: &str) -> String {
    let lines: Vec<String> = raw
        .replace("\r\n", "\n")
        .split('\n')
        .map(|line| {
            let line: String = line
                .replace('\t', "    ")
                .chars()
                .filter(|letter| !letter.is_control())
                .collect();

            let body = line.trim_start_matches(' ');
            let indent = line.len() - body.len();

            format!("{}{}", "\u{a0}".repeat(indent), body.trim_end())
        })
        .collect();

    lines.join("\n").trim_end().to_string()
}

// several lines, some indented or ended like a statement: worth the mono face
pub fn looks_like_code(raw: &str) -> bool {
    let lines: Vec<&str> = raw.lines().filter(|line| !line.trim().is_empty()).collect();

    lines.len() > 1
        && lines.iter().any(|line| {
            line.starts_with("  ")
                || line.starts_with('\t')
                || line.trim_end().ends_with(['{', ';'])
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn indentation_survives_wrapping() {
        let text = tidy("fn a() {\n\tlet b = 1;\r\n  c\n\n\n");

        assert_eq!(text, "fn a() {\n\u{a0}\u{a0}\u{a0}\u{a0}let b = 1;\n\u{a0}\u{a0}c");
    }

    #[test]
    fn control_characters_are_dropped() {
        assert_eq!(tidy("a\u{7}b\u{1b}[0m"), "ab[0m");
    }

    #[test]
    fn code_is_told_from_prose() {
        assert!(looks_like_code("fn a() {\n    b\n}"));
        assert!(looks_like_code("let a = 1;\nlet b = 2;"));
        assert!(!looks_like_code("## Summary\n\nThe calendar now fetches the month."));
        assert!(!looks_like_code("    one indented line"));
    }
}
