use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};

/*
 * matugen 4 prints every role as .colors.<role>.default.color; with the dark
 * mode asked for, default is the dark value. jq flattens that into the
 * `role=#rrggbb` lines the theme reads
 */
const FLATTEN: &str = r#".colors | to_entries[] | "\(.key)=\(.value.default.color)""#;

/*
 * the scheme for an image, or none when matugen or jq fail or say something
 * unexpected; the image goes to matugen as an argument, never through a shell.
 * the first source color matugen ranks is taken, so it never stops to ask
 */
pub fn scheme(image: &Path) -> Option<String> {
    let matugen = Command::new("matugen")
        .arg("image")
        .arg(image)
        .args(["--json", "hex", "--dry-run", "--mode", "dark"])
        .args(["--source-color-index", "0", "--quiet"])
        .output()
        .ok()?;

    if !matugen.status.success() {
        eprintln!(
            "yohaku: matugen failed: {}",
            String::from_utf8_lossy(&matugen.stderr).trim()
        );

        return None;
    }

    let mut jq = Command::new("jq")
        .args(["-r", FLATTEN])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .ok()?;

    // written then dropped, which closes jq's input so it can finish
    jq.stdin.take()?.write_all(&matugen.stdout).ok()?;

    let flattened = jq.wait_with_output().ok()?;

    if !flattened.status.success() {
        return None;
    }

    checked(&String::from_utf8_lossy(&flattened.stdout))
}

/*
 * only well-formed `role=#rrggbb` lines are kept, and a scheme without the
 * roles the shell leans on is refused, so a surprise in matugen's output
 * keeps the colors there are instead of replacing them with nonsense
 */
fn checked(text: &str) -> Option<String> {
    let lines: Vec<&str> = text.lines().map(str::trim).filter(|line| well_formed(line)).collect();

    let has = |role: &str| lines.iter().any(|line| line.starts_with(&format!("{role}=")));

    if !["primary", "surface", "on_surface"].iter().all(|role| has(role)) {
        return None;
    }

    Some(lines.join("\n") + "\n")
}

fn well_formed(line: &str) -> bool {
    let Some((role, hex)) = line.split_once('=') else {
        return false;
    };

    let digits = hex.strip_prefix('#').unwrap_or("");

    !role.is_empty()
        && role.bytes().all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || byte == b'_')
        && digits.len() == 6
        && digits.bytes().all(|byte| byte.is_ascii_hexdigit())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn keeps_well_formed_roles() {
        let text = "primary=#a9c7ff\nsurface=#111318\non_surface=#e2e2e9\n";

        assert_eq!(checked(text).as_deref(), Some(text));
    }

    #[test]
    fn drops_lines_that_are_not_a_role_and_a_color() {
        let text = "primary=#a9c7ff\nsurface=#111318\non_surface=#e2e2e9\nnull\nbad role=#123456\nshadow=#00\nsource=red\n";

        assert_eq!(
            checked(text).as_deref(),
            Some("primary=#a9c7ff\nsurface=#111318\non_surface=#e2e2e9\n")
        );
    }

    #[test]
    fn refuses_a_scheme_missing_what_the_shell_needs() {
        assert_eq!(checked("primary=#a9c7ff\nsurface=#111318\n"), None);
        assert_eq!(checked(""), None);
    }
}
