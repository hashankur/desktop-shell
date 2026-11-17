mod bar;
mod calendar;
mod cast;
mod charge;
mod clock;
mod compositor;
mod files;
mod google;
mod hover;
mod icons;
mod lock;
mod motion;
mod osd;
mod screenshot;
mod spotify;
mod stats;
mod surface;
mod tasks;
mod text;
mod theme;
mod toast;
mod wallpaper;

use amane::{App, Apps, Service};

use cast::Cast;
use compositor::Desktop;
use icons::Icons;
use lock::Logind;
use stats::Sensors;
use theme::Scheme;
use tasks::Tasks;
use toast::Toast;
use wallpaper::Wallpaper;

fn main() {
    // started before the first frame, so the bar opens with real data
    drop(Scheme::read());
    drop(Wallpaper::read());
    drop(Desktop::read());
    drop(Sensors::read());
    // listens before the first frame, so a share already running shows at once
    drop(Cast::read());
    drop(Icons::read());
    // listens for logind asking to lock, like `loginctl lock-session` or an idle daemon
    drop(Logind::read());
    // starts the notification server too, unless another daemon already has the name
    drop(Toast::read());
    // fetches tasks in the background, so they're there when the dashboard or launcher opens
    drop(Tasks::read());
    // the app scan takes seconds, so it starts before the launcher is first opened
    drop(Apps::read());

    App::new()
        .font(theme::MONO)
        .window_per_monitor(wallpaper::view)
        .window_per_monitor(bar::view)
        .window_per_monitor(toast::view)
        .window_per_monitor(surface::view)
        .window_per_monitor(osd::view)
        .window_per_monitor(screenshot::view)
        .window_per_monitor(lock::curtain_view)
        .lock(lock::view)
        .ipc("launcher", surface::launcher_ipc)
        .ipc("clipboard", surface::clipboard_ipc)
        .ipc("power", surface::power_ipc)
        .ipc("dashboard", surface::dashboard_ipc)
        .ipc("settings", surface::settings_ipc)
        .ipc("calendar", calendar::ipc)
        .ipc("tasks", tasks::ipc)
        .ipc("lock", lock::ipc)
        .ipc("wallpaper", wallpaper::ipc)
        .ipc("screenshot", screenshot::ipc)
        .run();
}
