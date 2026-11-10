use std::thread;

use amane::{Center, Column, Lock, Rectangle, Service, Start, Text, TextInput, children};

use crate::theme::{MONO, Theme, size, space};

// the text input's name, which keeps what was typed between redraws
const INPUT: &str = "lock-password";

// forgets whatever was typed, so a lock never opens on the last one's half-typed password
pub fn clear() {
    TextInput::set_text(INPUT, "");
}

// the user's name, the password field, and what the check said
pub fn view(theme: &Theme, width: f32) -> Column {
    let lock = Lock::read();
    let (checking, failed) = (lock.checking(), lock.failed());
    drop(lock);

    let user = std::env::var("USER").unwrap_or_default();

    let label = Text::new(user.to_uppercase())
        .font(MONO)
        .size(size::SM)
        .color(theme.on_surface_variant);

    // the one place the shell shows an error color: a password that was refused
    let (status, color) = if failed {
        ("wrong password", theme.error)
    } else if checking {
        ("checking…", theme.on_surface_variant)
    } else {
        ("↵ unlock", theme.outline)
    };

    let status = Text::new(status).font(MONO).size(size::SM).color(color);

    Column::new(children![label, field(theme, width), status])
        .width(width)
        .gap(space::SM)
}

fn field(theme: &Theme, width: f32) -> Rectangle {
    let input = TextInput::new(INPUT)
        .size(size::MD)
        .color(theme.on_surface)
        .placeholder("password")
        .password()
        .focused()
        .on_submit(submit);

    Rectangle::new()
        .width(width)
        .height(size::MD * 1.5)
        .align_child(Start, Center)
        .child(input)
}

// the field empties either way: a wrong password is typed again from scratch
fn submit(password: String) {
    if password.is_empty() {
        return;
    }

    // checked by pam on its own thread; the session unlocks only if pam accepts it,
    // and the curtain opens once it has
    Lock::unlock(&password);

    thread::spawn(super::curtain::open_when_accepted);

    clear();
}
