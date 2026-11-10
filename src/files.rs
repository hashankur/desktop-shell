use std::fs;
use std::io;
use std::path::Path;

/*
 * writes beside the file and renames over it, so a reader, or amane's file
 * watcher, never sees half of it, and a crash never leaves it torn
 */
pub fn write_atomic(path: &Path, contents: &str) -> io::Result<()> {
    if let Some(folder) = path.parent() {
        fs::create_dir_all(folder)?;
    }

    let mut partial = path.as_os_str().to_owned();
    partial.push(".part");

    fs::write(&partial, contents)?;
    fs::rename(&partial, path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn replaces_the_whole_file_and_leaves_nothing_beside_it() {
        let folder = std::env::temp_dir().join(format!("yohaku-files-{}", std::process::id()));
        let path = folder.join("state");

        write_atomic(&path, "first\nsecond\n").unwrap();
        write_atomic(&path, "third\n").unwrap();

        assert_eq!(fs::read_to_string(&path).unwrap(), "third\n");
        assert!(!folder.join("state.part").exists());

        fs::remove_dir_all(&folder).unwrap();
    }
}
