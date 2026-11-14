use std::io::Write;
use std::process::{Command, Stdio};
use std::sync::{Mutex, PoisonError};
use std::thread;

use super::credentials::Credentials;
use super::encode::form;

const TOKEN_URL: &str = "https://oauth2.googleapis.com/token";

// an access token this close to running out is renewed first
const EXPIRY_MARGIN: i64 = 120;

/*
 * a working access token, renewed with the refresh token when it's about
 * to run out. a renewal is written back at once, so a restart reuses it.
 * the calendar and tasks fetch on threads of their own, so the whole
 * check-and-renew is one step under a lock, with the credentials read
 * inside it: a token the other thread just renewed is reused, not renewed
 * again and written over. none when signed out
 */
pub fn access_token(now: i64) -> Option<String> {
    let _renewing = RENEWING.lock().unwrap_or_else(PoisonError::into_inner);

    let mut credentials = Credentials::load().filter(Credentials::signed_in)?;

    if !credentials.access_token.is_empty() && credentials.expires - EXPIRY_MARGIN > now {
        return Some(credentials.access_token.clone());
    }

    let body = form(&[
        ("client_id", &credentials.client_id),
        ("client_secret", &credentials.client_secret),
        ("refresh_token", &credentials.refresh_token),
        ("grant_type", "refresh_token"),
    ]);

    let reply = token_reply(&post_token(&body)?)?;

    credentials.access_token = reply.token.clone();
    credentials.expires = now + reply.lasts;

    // google says what the token covers; a reply without it changes nothing
    if !reply.scope.is_empty() {
        credentials.scope = reply.scope;
    }

    // signing out while this was out must not bring the file back
    if Credentials::load().is_some() {
        credentials.save();
    }

    Some(reply.token)
}

static RENEWING: Mutex<()> = Mutex::new(());

// the token endpoint, with the secrets in the body on stdin, not in curl's arguments
pub fn post_token(body: &str) -> Option<String> {
    run("curl", &curl_args(&["--data", "@-", TOKEN_URL]), body)
}

// what the token endpoint gives back: the token, its lifetime in seconds, and what it may do
#[derive(Debug, PartialEq)]
pub struct TokenReply {
    pub token: String,
    pub lasts: i64,
    pub scope: String,
}

pub fn token_reply(reply: &str) -> Option<TokenReply> {
    let fields = jq(r#".access_token // "", .expires_in // 0, .scope // """#, reply)?;
    let mut lines = fields.lines();

    let token = lines.next()?.to_string();
    let lasts = lines.next()?.parse().ok()?;
    let scope = lines.next().unwrap_or_default().to_string();

    (!token.is_empty()).then_some(TokenReply { token, lasts, scope })
}

// a get with the token as a header read from stdin, so it never shows in ps
pub fn get(url: &str, token: &str) -> Option<String> {
    run(
        "curl",
        &curl_args(&["--header", "@-", url]),
        &format!("Authorization: Bearer {token}\n"),
    )
}

/*
 * a change: a method with a json body and the reply's body. the headers
 * come on stdin like a get's, so the token stays out of ps; the body goes
 * in the arguments, since what it says is no secret
 */
pub fn send(method: &str, url: &str, token: &str, body: &str) -> Option<String> {
    run(
        "curl",
        &curl_args(&["--request", method, "--header", "@-", "--data-binary", body, url]),
        &format!("Authorization: Bearer {token}\nContent-Type: application/json\n"),
    )
}


fn curl_args<'a>(rest: &[&'a str]) -> Vec<&'a str> {
    let mut args = vec!["--fail", "--silent", "--show-error", "--connect-timeout", "5", "--max-time", "20"];

    args.extend_from_slice(rest);

    args
}

// jq -r with the text on stdin
pub fn jq(filter: &str, input: &str) -> Option<String> {
    run("jq", &["-r", filter], input)
}

// a program with text on stdin; its output when it succeeds, none otherwise
pub fn run(program: &str, args: &[&str], input: &str) -> Option<String> {
    let mut child = Command::new(program)
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;

    /*
     * written from its own thread: a long reply could fill the output pipe
     * while the input is still going in, and both sides would wait. the
     * pipe closes when the thread ends, so the program sees the end
     */
    let mut stdin = child.stdin.take()?;
    let input = input.to_string();
    let writer = thread::spawn(move || stdin.write_all(input.as_bytes()).is_ok());

    let output = child.wait_with_output().ok()?;

    if !writer.join().unwrap_or(false) {
        return None;
    }

    if !output.status.success() {
        return None;
    }

    Some(String::from_utf8_lossy(&output.stdout).into_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_a_token_reply() {
        let reply = r#"{"access_token": "ya29.x", "expires_in": 3599, "token_type": "Bearer"}"#;

        let read = token_reply(reply).unwrap();

        assert_eq!((read.token.as_str(), read.lasts, read.scope.as_str()), ("ya29.x", 3599, ""));
        assert_eq!(token_reply(r#"{"error": "invalid_grant"}"#), None);

        let scoped = r#"{"access_token": "a", "expires_in": 1, "scope": "https://www.googleapis.com/auth/tasks https://www.googleapis.com/auth/calendar.readonly"}"#;

        assert!(token_reply(scoped).unwrap().scope.ends_with("calendar.readonly"));
    }
}
