use std::fs::{self, OpenOptions};
use std::io::{self, Write};
use std::os::unix::fs::OpenOptionsExt;
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

/*
 * the same, for secrets: the file is only ever readable by its owner, even
 * for the moment it exists beside the real one
 */
pub fn write_private(path: &Path, contents: &str) -> io::Result<()> {
    if let Some(folder) = path.parent() {
        fs::create_dir_all(folder)?;
    }

    let mut partial = path.as_os_str().to_owned();
    partial.push(".part");

    // a .part left by a crash may have been created looser, so it goes first
    let _ = fs::remove_file(&partial);

    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(&partial)?;

    file.write_all(contents.as_bytes())?;
    drop(file);

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

    #[test]
    fn keeps_secrets_to_the_owner() {
        use std::os::unix::fs::PermissionsExt;

        let folder = std::env::temp_dir().join(format!("yohaku-private-{}", std::process::id()));
        let path = folder.join("token");

        write_private(&path, "secret\n").unwrap();
        write_private(&path, "newer\n").unwrap();

        let mode = fs::metadata(&path).unwrap().permissions().mode();

        assert_eq!(mode & 0o777, 0o600);
        assert_eq!(fs::read_to_string(&path).unwrap(), "newer\n");

        fs::remove_dir_all(&folder).unwrap();
    }
}
