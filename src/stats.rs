use std::collections::VecDeque;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

use amane::Service;

const HWMON: &str = "/sys/class/hwmon";

// the ring is full at this temperature, as in neue
const TEMP_FULL: f32 = 100.0;

// integrated gpu busy % jumps every read, so the ring shows the mean of the last few
const GPU_SAMPLES: usize = 3;

/*
 * what amane's Cpu and Memory don't cover: the cpu package temperature
 * and gpu load. sensors are found once by hwmon name, since hwmon and
 * card numbers change between boots; a missing one hides its ring
 */
#[derive(Default)]
pub struct Sensors {
    temp_path: Option<PathBuf>,
    gpu_path: Option<PathBuf>,

    // degrees celsius
    temp: Option<f32>,

    gpu_samples: VecDeque<f32>,
}

impl Service for Sensors {
    fn new() -> Self {
        let mut sensors = Self {
            temp_path: find_temp(),
            gpu_path: find_gpu(),
            ..Self::default()
        };

        sensors.update();

        sensors
    }

    fn interval() -> Duration {
        Duration::from_secs(2)
    }

    fn update(&mut self) -> bool {
        let before = (self.temp_percent(), self.gpu_percent());

        // millidegrees
        self.temp = self
            .temp_path
            .as_deref()
            .and_then(read_number)
            .map(|milli| milli / 1000.0);

        if let Some(busy) = self.gpu_path.as_deref().and_then(read_number) {
            if self.gpu_samples.len() == GPU_SAMPLES {
                self.gpu_samples.pop_front();
            }

            self.gpu_samples.push_back(busy);
        }

        // only what the rings show counts as a change
        (self.temp_percent(), self.gpu_percent()) != before
    }
}

impl Sensors {
    // 0 to 1, or None without a sensor
    pub fn temp(&self) -> Option<f32> {
        self.temp.map(|celsius| (celsius / TEMP_FULL).clamp(0.0, 1.0))
    }

    pub fn gpu(&self) -> Option<f32> {
        if self.gpu_samples.is_empty() {
            return None;
        }

        let mean = self.gpu_samples.iter().sum::<f32>() / self.gpu_samples.len() as f32;

        Some((mean / 100.0).clamp(0.0, 1.0))
    }

    fn temp_percent(&self) -> Option<u8> {
        self.temp().map(|value| (value * 100.0).round() as u8)
    }

    fn gpu_percent(&self) -> Option<u8> {
        self.gpu().map(|value| (value * 100.0).round() as u8)
    }
}

fn read_number(path: &Path) -> Option<f32> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn hwmon_named(name: &str) -> Option<PathBuf> {
    fs::read_dir(HWMON)
        .ok()?
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .find(|folder| {
            fs::read_to_string(folder.join("name")).is_ok_and(|found| found.trim() == name)
        })
}

// amd's cpu package temperature is the input labelled Tctl, whichever number it has
fn find_temp() -> Option<PathBuf> {
    let folder = hwmon_named("k10temp")?;

    let entries = fs::read_dir(&folder).ok()?;

    for entry in entries.filter_map(Result::ok) {
        let file = entry.file_name();
        let file = file.to_string_lossy();

        let Some(sensor) = file.strip_suffix("_label") else {
            continue;
        };

        let label = fs::read_to_string(entry.path()).unwrap_or_default();

        if label.trim() == "Tctl" {
            let input = folder.join(format!("{sensor}_input"));

            return input.exists().then_some(input);
        }
    }

    None
}

fn find_gpu() -> Option<PathBuf> {
    let busy = hwmon_named("amdgpu")?.join("device/gpu_busy_percent");

    busy.exists().then_some(busy)
}
