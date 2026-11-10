use amane::Point;

// a box on one output, in the window's own units: its top-left corner and size
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Area {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

impl Area {
    // the whole output, for taking a frame without drawing a box
    pub fn whole(bounds: (f32, f32)) -> Self {
        Self {
            x: 0.0,
            y: 0.0,
            width: bounds.0,
            height: bounds.1,
        }
    }

    // a box this small either way is a stray click, not a region
    pub fn is_at_least(&self, side: f32) -> bool {
        self.width >= side && self.height >= side
    }
}

/*
 * the box between where the drag started and where it is now, in either
 * order; kept inside the output, since a drag can run past its edge
 */
pub fn between(start: Point, end: Point, bounds: (f32, f32)) -> Area {
    let (width, height) = bounds;

    let (x0, y0) = (start.x.clamp(0.0, width), start.y.clamp(0.0, height));
    let (x1, y1) = (end.x.clamp(0.0, width), end.y.clamp(0.0, height));

    Area {
        x: x0.min(x1),
        y: y0.min(y1),
        width: (x1 - x0).abs(),
        height: (y1 - y0).abs(),
    }
}

/*
 * the box in the frozen picture's own pixels, as magick's `WxH+X+Y`. the
 * picture is the output at its real resolution, so a scaled output has
 * more pixels than window units; none when nothing is left inside it
 */
pub fn crop(area: Area, bounds: (f32, f32), picture: (u32, u32)) -> Option<String> {
    let (width, height) = bounds;

    if width <= 0.0 || height <= 0.0 {
        return None;
    }

    let scale_x = picture.0 as f32 / width;
    let scale_y = picture.1 as f32 / height;

    // rounded edges rather than a rounded size, so the box neither drifts nor grows
    let edge =
        |units: f32, scale: f32, limit: u32| ((units * scale).round().max(0.0) as u32).min(limit);

    let left = edge(area.x, scale_x, picture.0);
    let top = edge(area.y, scale_y, picture.1);
    let right = edge(area.x + area.width, scale_x, picture.0);
    let bottom = edge(area.y + area.height, scale_y, picture.1);

    let (crop_width, crop_height) = (right.saturating_sub(left), bottom.saturating_sub(top));

    (crop_width > 0 && crop_height > 0).then(|| format!("{crop_width}x{crop_height}+{left}+{top}"))
}

const PNG_SIGNATURE: [u8; 8] = [0x89, b'P', b'N', b'G', b'\r', b'\n', 0x1a, b'\n'];

// how many bytes from the start of a png its size ends at
pub const PNG_HEADER: usize = 24;

// a png's width and height, from the header chunk that always comes first
pub fn png_size(header: &[u8]) -> Option<(u32, u32)> {
    if header.get(..8)? != PNG_SIGNATURE || header.get(12..16)? != b"IHDR" {
        return None;
    }

    let width = u32::from_be_bytes(header.get(16..20)?.try_into().ok()?);
    let height = u32::from_be_bytes(header.get(20..24)?.try_into().ok()?);

    (width > 0 && height > 0).then_some((width, height))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn point(x: f32, y: f32) -> Point {
        Point { x, y }
    }

    #[test]
    fn a_box_dragged_up_and_left_is_the_same_box() {
        let down = between(point(10.0, 20.0), point(110.0, 70.0), (1920.0, 1080.0));
        let up = between(point(110.0, 70.0), point(10.0, 20.0), (1920.0, 1080.0));

        assert_eq!(down, up);
        assert_eq!(
            down,
            Area {
                x: 10.0,
                y: 20.0,
                width: 100.0,
                height: 50.0
            }
        );
    }

    #[test]
    fn a_drag_past_the_edge_stops_at_it() {
        let area = between(point(1800.0, -40.0), point(2500.0, 100.0), (1920.0, 1080.0));

        assert_eq!(
            area,
            Area {
                x: 1800.0,
                y: 0.0,
                width: 120.0,
                height: 100.0
            }
        );
    }

    #[test]
    fn a_click_is_too_small_to_take() {
        let area = between(point(5.0, 5.0), point(6.0, 5.0), (1920.0, 1080.0));

        assert!(!area.is_at_least(4.0));
        assert!(Area::whole((1920.0, 1080.0)).is_at_least(4.0));
    }

    #[test]
    fn crops_in_the_pictures_own_pixels() {
        let area = Area {
            x: 100.0,
            y: 50.0,
            width: 300.0,
            height: 200.0,
        };

        assert_eq!(
            crop(area, (1920.0, 1080.0), (1920, 1080)).as_deref(),
            Some("300x200+100+50")
        );

        // a 1.5 scale output: 1280 units across, 1920 pixels
        assert_eq!(
            crop(area, (1280.0, 720.0), (1920, 1080)).as_deref(),
            Some("450x300+150+75")
        );
    }

    #[test]
    fn a_crop_never_runs_past_the_picture() {
        let area = Area::whole((1280.0, 720.0));

        assert_eq!(
            crop(area, (1280.0, 720.0), (1920, 1080)).as_deref(),
            Some("1920x1080+0+0")
        );

        let empty = Area {
            x: 10.0,
            y: 10.0,
            width: 0.0,
            height: 30.0,
        };

        assert_eq!(crop(empty, (1920.0, 1080.0), (1920, 1080)), None);
        assert_eq!(crop(area, (0.0, 0.0), (1920, 1080)), None);
    }

    #[test]
    fn reads_the_size_from_a_png_header() {
        let mut header = PNG_SIGNATURE.to_vec();
        header.extend_from_slice(&[0, 0, 0, 13]);
        header.extend_from_slice(b"IHDR");
        header.extend_from_slice(&1920u32.to_be_bytes());
        header.extend_from_slice(&1080u32.to_be_bytes());

        assert_eq!(header.len(), PNG_HEADER);
        assert_eq!(png_size(&header), Some((1920, 1080)));

        // cut short, or not a png at all
        assert_eq!(png_size(&header[..20]), None);
        assert_eq!(png_size(b"GIF89a and some more bytes!"), None);
    }
}
