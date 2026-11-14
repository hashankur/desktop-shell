use std::fs;
use std::path::PathBuf;

use crate::files;
use crate::theme;

/*
 * what signing in to google leaves behind: the desktop client it was done
 * with, the refresh token, and the short-lived access token with when it
 * runs out. one key=value per line, readable only by the user. it lives in
 * state, never in the config folder, which is a git repository
 */
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Credentials {
    pub client_id: String,
    pub client_secret: String,
    pub refresh_token: String,
    pub access_token: String,
    // seconds since 1970 when the access token stops working
    pub expires: i64,
    // the scopes google granted, space separated; empty for a sign-in from before this was kept
    pub scope: String,
}

impl Credentials {
    pub fn signed_in(&self) -> bool {
        !self.client_id.is_empty() && !self.refresh_token.is_empty()
    }

    /*
     * whether google granted a scope. its consent page lets each one be
     * turned down, so a sign-in can have the calendar and not tasks
     */
    pub fn granted(&self, scope: &str) -> bool {
        self.scope.split_whitespace().any(|granted| granted == scope)
    }

    pub fn load() -> Option<Self> {
        Some(Self::parse(&fs::read_to_string(credentials_path()).ok()?))
    }

    pub fn save(&self) -> bool {
        files::write_private(&credentials_path(), &self.to_text()).is_ok()
    }

    pub fn forget() {
        let _ = fs::remove_file(credentials_path());
    }

    fn parse(text: &str) -> Self {
        let mut credentials = Self::default();

        for line in text.lines() {
            let Some((key, value)) = line.split_once('=') else {
                continue;
            };

            let value = value.trim().to_string();

            match key.trim() {
                "client_id" => credentials.client_id = value,
                "client_secret" => credentials.client_secret = value,
                "refresh_token" => credentials.refresh_token = value,
                "access_token" => credentials.access_token = value,
                "expires" => credentials.expires = value.parse().unwrap_or(0),
                "scope" => credentials.scope = value,
                _ => {}
            }
        }

        credentials
    }

    fn to_text(&self) -> String {
        format!(
            "client_id={}\nclient_secret={}\nrefresh_token={}\naccess_token={}\nexpires={}\nscope={}\n",
            self.client_id, self.client_secret, self.refresh_token, self.access_token, self.expires, self.scope
        )
    }
}

fn credentials_path() -> PathBuf {
    theme::state_folder().join("google")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_back_what_it_writes() {
        let credentials = Credentials {
            client_id: String::from("id.apps.googleusercontent.com"),
            client_secret: String::from("secret"),
            refresh_token: String::from("1//refresh"),
            access_token: String::from("ya29.access"),
            expires: 1_794_355_200,
            scope: String::from("https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/tasks"),
        };

        assert_eq!(Credentials::parse(&credentials.to_text()), credentials);
        assert!(credentials.signed_in());
        assert!(!Credentials::default().signed_in());
        assert!(credentials.granted("https://www.googleapis.com/auth/tasks"));
        assert!(!credentials.granted("https://www.googleapis.com/auth/tasks.readonly"));
        assert!(!Credentials::default().granted("https://www.googleapis.com/auth/tasks"));
    }

}
