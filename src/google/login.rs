use std::fs;
use std::io::{ErrorKind, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::path::Path;
use std::process::{Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use super::credentials::Credentials;
use super::encode::{base64_url, form, query_value, random};
use super::http::{jq, post_token, run};

const AUTH_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";

// how long the browser has to come back before the sign-in gives up
const WAIT: Duration = Duration::from_secs(300);
const POLL: Duration = Duration::from_millis(200);

/*
 * google's desktop-app sign-in: the browser opens google's consent page
 * and is sent back to a port on 127.0.0.1 that only this process listens
 * on, with a code that is traded for a refresh token. pkce ties the code
 * to this run, and the state check ties the reply to this request.
 * `client` is the json google cloud gives for a desktop client
 */
pub fn start(client: &Path) -> Result<(), String> {
    let json = fs::read_to_string(client).map_err(|error| format!("can't read {}: {error}", client.display()))?;

    let fields = jq(r#"(.installed // .web // {}) | .client_id // "", .client_secret // """#, &json)
        .ok_or("that file isn't a google client json")?;

    let mut lines = fields.lines();
    let (client_id, client_secret) = (
        lines.next().unwrap_or_default().to_string(),
        lines.next().unwrap_or_default().to_string(),
    );

    if client_id.is_empty() || client_secret.is_empty() {
        return Err(String::from("no client_id and client_secret in that file"));
    }

    let listener = TcpListener::bind("127.0.0.1:0").map_err(|error| format!("can't listen: {error}"))?;
    let port = listener.local_addr().map_err(|error| error.to_string())?.port();

    let verifier = random(64).ok_or("can't read /dev/urandom")?;
    let state = random(32).ok_or("can't read /dev/urandom")?;
    let challenge = challenge(&verifier).ok_or("openssl couldn't hash the pkce verifier")?;

    let redirect = format!("http://127.0.0.1:{port}");

    let url = format!(
        "{AUTH_URL}?{}",
        form(&[
            ("client_id", &client_id),
            ("redirect_uri", &redirect),
            ("response_type", "code"),
            ("scope", &super::SCOPES.join(" ")),
            ("code_challenge", &challenge),
            ("code_challenge_method", "S256"),
            ("state", &state),
            ("access_type", "offline"),
            // asks again even if granted before, so google hands out a refresh token every time
            ("prompt", "consent"),
        ])
    );

    let mut browser = Command::new("xdg-open")
        .arg(&url)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|error| format!("can't open the browser: {error}"))?;

    // a finished child that nobody waits for stays behind as a zombie
    thread::spawn(move || browser.wait());

    thread::spawn(move || {
        let Some(code) = wait_for_code(&listener, &state) else {
            return;
        };

        let body = form(&[
            ("code", &code),
            ("client_id", &client_id),
            ("client_secret", &client_secret),
            ("redirect_uri", &redirect),
            ("grant_type", "authorization_code"),
            ("code_verifier", &verifier),
        ]);

        let Some(reply) = post_token(&body) else {
            return;
        };

        let Some(fields) = jq(r#".refresh_token // "", .access_token // "", .expires_in // 0, .scope // """#, &reply) else {
            return;
        };

        let mut lines = fields.lines();
        let (refresh_token, access_token, lasts, scope) = (
            lines.next().unwrap_or_default().to_string(),
            lines.next().unwrap_or_default().to_string(),
            lines.next().and_then(|lasts| lasts.parse::<i64>().ok()).unwrap_or(0),
            lines.next().unwrap_or_default().to_string(),
        );

        if refresh_token.is_empty() {
            return;
        }

        let credentials = Credentials {
            client_id,
            client_secret,
            refresh_token,
            access_token,
            expires: super::now() + lasts,
            scope,
        };

        if credentials.save() {
            super::signed_in();
        }
    });

    Ok(())
}

// base64url of the verifier's sha-256, which is what S256 sends
fn challenge(verifier: &str) -> Option<String> {
    let hex = run("openssl", &["dgst", "-sha256", "-r"], verifier)?;

    // `-r` prints "<hex> *stdin"
    let hex = hex.split_whitespace().next()?;

    let bytes: Option<Vec<u8>> = (0..hex.len())
        .step_by(2)
        .map(|index| u8::from_str_radix(hex.get(index..index + 2)?, 16).ok())
        .collect();

    let bytes = bytes?;

    (bytes.len() == 32).then(|| base64_url(&bytes))
}

/*
 * answers requests on the loopback port until one brings the code back
 * with the right state, the user turns it down, or time runs out. other
 * requests, like the browser's favicon, are turned away and waited past
 */
fn wait_for_code(listener: &TcpListener, state: &str) -> Option<String> {
    listener.set_nonblocking(true).ok()?;

    let deadline = Instant::now() + WAIT;

    while Instant::now() < deadline {
        let stream = match listener.accept() {
            Ok((stream, _)) => stream,
            Err(error) if error.kind() == ErrorKind::WouldBlock => {
                thread::sleep(POLL);
                continue;
            }
            Err(_) => return None,
        };

        match answer(stream, state) {
            Reply::Code(code) => return Some(code),
            Reply::Refused => return None,
            Reply::Other => {}
        }
    }

    None
}

enum Reply {
    Code(String),
    Refused,
    Other,
}

fn answer(mut stream: TcpStream, state: &str) -> Reply {
    let _ = stream.set_nonblocking(false);
    let _ = stream.set_read_timeout(Some(Duration::from_secs(5)));

    // the request line is all that's needed, and it comes first
    let mut buffer = [0u8; 4096];
    let read = stream.read(&mut buffer).unwrap_or(0);
    let request = String::from_utf8_lossy(buffer.get(..read).unwrap_or_default());

    let reply = parse_request(&request, state);

    let (status, text) = match reply {
        Reply::Code(_) => ("200 OK", "yohaku is signed in to google. this tab can be closed."),
        Reply::Refused => ("200 OK", "yohaku was not signed in. this tab can be closed."),
        Reply::Other => ("404 Not Found", "not here."),
    };

    let _ = write!(
        stream,
        "HTTP/1.1 {status}\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{text}",
        text.len()
    );

    reply
}

// "GET /?state=..&code=..&scope=.. HTTP/1.1", checked against the state that was sent
fn parse_request(request: &str, state: &str) -> Reply {
    let Some(target) = request
        .lines()
        .next()
        .and_then(|line| line.strip_prefix("GET "))
        .and_then(|rest| rest.split_whitespace().next())
    else {
        return Reply::Other;
    };

    let Some(query) = target.strip_prefix("/?") else {
        return Reply::Other;
    };

    if query_value(query, "state").as_deref() != Some(state) {
        return Reply::Other;
    }

    if query_value(query, "error").is_some() {
        return Reply::Refused;
    }

    match query_value(query, "code") {
        Some(code) if !code.is_empty() => Reply::Code(code),
        _ => Reply::Refused,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hashes_the_verifier_like_rfc_7636() {
        // the example in rfc 7636, appendix b
        assert_eq!(
            challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk").as_deref(),
            Some("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        );
    }

    #[test]
    fn takes_the_code_only_with_the_right_state() {
        let request = "GET /?state=abc&code=4%2F0Ab&scope=x HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n";

        assert!(matches!(parse_request(request, "abc"), Reply::Code(code) if code == "4/0Ab"));
        assert!(matches!(parse_request(request, "other"), Reply::Other));
        assert!(matches!(parse_request("GET /favicon.ico HTTP/1.1\r\n", "abc"), Reply::Other));
        assert!(matches!(
            parse_request("GET /?state=abc&error=access_denied HTTP/1.1\r\n", "abc"),
            Reply::Refused
        ));
    }
}
