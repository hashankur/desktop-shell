use std::process;

use amane::{Argument, Bus, Service};

const LOGIN1: &str = "org.freedesktop.login1";
const MANAGER_PATH: &str = "/org/freedesktop/login1";
const MANAGER: &str = "org.freedesktop.login1.Manager";
const SESSION: &str = "org.freedesktop.login1.Session";

/*
 * logind asks the session's locker to lock through a signal, which is what
 * `loginctl lock-session`, idle daemons and a closed lid all go through
 */
pub struct Logind;

impl Service for Logind {
    fn new() -> Self {
        Self
    }

    fn listen() {
        let bus = Bus::system();

        let pid = Argument::Unsigned(process::id());

        let session = bus.call(LOGIN1, MANAGER_PATH, MANAGER, "GetSessionByPID", &[pid]);

        // outside a logind session, any session's lock request is taken
        let session = String::from(session.text());

        for signal in bus.signals(SESSION, "Lock") {
            if !session.is_empty() && signal.path() != session {
                continue;
            }

            super::start();
        }
    }
}
