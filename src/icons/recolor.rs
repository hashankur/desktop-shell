/*
 * symbolic svgs ship with a dark fill baked in (#2e3436, #000, or none at
 * all); like gtk, every color in them is rewritten to the one asked for
 */
/*
 * every fill, stroke and color value becomes the tint, whether written as an
 * attribute (fill="#2e3436") or in css (fill:#000000); none, url(...) and
 * currentColor stay as they are. the root gets the tint as its default too,
 * for shapes that never set a fill and would draw black
 */
pub fn recolor(svg: &str, hex: &str) -> String {
    let mut out = String::with_capacity(svg.len() + 64);

    let bytes = svg.as_bytes();
    let mut copied = 0;
    let mut at = 0;

    while at < bytes.len() {
        let Some((value_start, value_end)) = color_value_at(bytes, at) else {
            at += 1;
            continue;
        };

        let value = svg[value_start..value_end].trim();

        if !keeps(value) {
            out.push_str(&svg[copied..value_start]);
            out.push_str(hex);
            copied = value_end;
        }

        at = value_end;
    }

    out.push_str(&svg[copied..]);

    with_root_defaults(out, hex)
}

const PROPERTIES: [&str; 3] = ["fill", "stroke", "color"];

// the value's byte range, if a fill, stroke or color property starts here
fn color_value_at(bytes: &[u8], at: usize) -> Option<(usize, usize)> {
    // part of a longer name like stop-color or bordercolor
    if at > 0 && is_name_byte(bytes[at - 1]) {
        return None;
    }

    let name = PROPERTIES
        .iter()
        .find(|name| bytes[at..].starts_with(name.as_bytes()))?;

    let mut index = skip_spaces(bytes, at + name.len());

    match bytes.get(index)? {
        // an attribute: fill="#2e3436"
        b'=' => {
            index = skip_spaces(bytes, index + 1);

            let quote = *bytes.get(index)?;

            if quote != b'"' && quote != b'\'' {
                return None;
            }

            let start = index + 1;
            let length = bytes[start..].iter().position(|&byte| byte == quote)?;

            Some((start, start + length))
        }

        // css: fill:#000000; up to the end of the declaration
        b':' => {
            let start = index + 1;

            let length = bytes[start..]
                .iter()
                .position(|byte| matches!(byte, b';' | b'"' | b'\'' | b'}' | b'!' | b'<'))
                .unwrap_or(bytes.len() - start);

            Some((start, start + length))
        }

        _ => None,
    }
}

fn is_name_byte(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b':' | b'.')
}

fn skip_spaces(bytes: &[u8], mut index: usize) -> usize {
    while bytes.get(index).is_some_and(u8::is_ascii_whitespace) {
        index += 1;
    }

    index
}

fn keeps(value: &str) -> bool {
    value.is_empty()
        || value.eq_ignore_ascii_case("none")
        || value.eq_ignore_ascii_case("transparent")
        || value.eq_ignore_ascii_case("currentcolor")
        || value.eq_ignore_ascii_case("inherit")
        || value.starts_with("url(")
}

// adds fill and color to the <svg> tag unless it already sets them, which recolor has rewritten
fn with_root_defaults(mut svg: String, hex: &str) -> String {
    let Some(open) = find_root(&svg) else {
        return svg;
    };

    let close = svg[open..].find('>').map_or(svg.len(), |end| open + end);
    let tag = &svg[open..close];

    let mut extra = String::new();

    for name in ["fill", "color"] {
        let sets = tag.match_indices(name).any(|(index, _)| {
            let bytes = tag.as_bytes();

            !is_name_byte(bytes[index - 1])
                && bytes.get(skip_spaces(bytes, index + name.len())) == Some(&b'=')
        });

        if !sets {
            extra.push_str(&format!(" {name}=\"{hex}\""));
        }
    }

    svg.insert_str(open + "<svg".len(), &extra);

    svg
}

// the root tag, not an <svg:svg> namespace prefix or a comment mentioning svg
fn find_root(svg: &str) -> Option<usize> {
    svg.match_indices("<svg").map(|(index, _)| index).find(|&index| {
        svg.as_bytes()
            .get(index + 4)
            .is_some_and(|byte| byte.is_ascii_whitespace() || *byte == b'>')
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const TINT: &str = "#c4c6d0";

    #[test]
    fn rewrites_attributes_and_css() {
        let svg = r##"<svg xmlns="http://www.w3.org/2000/svg"><path fill="#2e3436"/><g style="display:inline;fill:#000000;stroke: #000 ;opacity:0.5"/></svg>"##;

        let out = recolor(svg, TINT);

        assert!(out.contains(r##"<path fill="#c4c6d0"/>"##));
        assert!(out.contains("fill:#c4c6d0;stroke:#c4c6d0;opacity:0.5"));
    }

    #[test]
    fn keeps_none_urls_and_current_color() {
        let svg = r##"<svg fill="none"><path fill="url(#a)" stroke="none" style="fill:currentColor"/></svg>"##;

        let out = recolor(svg, TINT);

        assert!(out.contains(r##"fill="url(#a)" stroke="none" style="fill:currentColor""##));
        // the root's own fill is kept, so no second fill is added to it
        assert_eq!(out.matches("fill=\"none\"").count(), 1);
        assert!(out.starts_with(r##"<svg color="#c4c6d0" fill="none">"##));
    }

    #[test]
    fn leaves_longer_names_alone() {
        let svg = r##"<svg><stop stop-color="#000"/><path fill-rule="evenodd" fill-opacity="0.3" style="flood-color:#000"/><namedview bordercolor="#666"/></svg>"##;

        let out = recolor(svg, TINT);

        assert!(out.contains(r##"stop-color="#000""##));
        assert!(out.contains(r##"fill-rule="evenodd" fill-opacity="0.3""##));
        assert!(out.contains("flood-color:#000"));
        assert!(out.contains(r##"bordercolor="#666""##));
    }

    #[test]
    fn gives_unset_shapes_the_tint() {
        let svg = "<?xml version=\"1.0\"?>\n<svg height=\"16px\" xmlns=\"http://www.w3.org/2000/svg\"><path d=\"m 1 1\"/></svg>";

        let out = recolor(svg, TINT);

        assert!(out.contains(r##"<svg fill="#c4c6d0" color="#c4c6d0" height="16px""##));
    }

}
