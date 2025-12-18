use niri_ipc::{Event, Reply, Request};
use std::env;
use std::io::{BufRead, BufReader, Error, ErrorKind, Write};
use std::os::unix::net::UnixStream;
use std::sync::mpsc::Sender;

use crate::{SystemState, Workspace};

pub async fn niri_event_listener(tx: Sender<SystemState>) -> Result<(), Error> {
    let mut wss: Vec<Workspace> = Vec::new();

    let socket_path = env::var("NIRI_SOCKET")
        .map_err(|_| Error::new(ErrorKind::Other, "NIRI_SOCKET environment variable not set"))?;

    let mut stream = UnixStream::connect(&socket_path).map_err(|e| {
        Error::new(
            ErrorKind::Other,
            format!("Failed to connect to niri socket: {}", e),
        )
    })?;

    // Start the event stream (this will provide initial state automatically)
    let request = Request::EventStream;
    let request_json = serde_json::to_string(&request)?;
    writeln!(stream, "{}", request_json)?;

    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    reader.read_line(&mut line)?;
    let _reply: Reply = serde_json::from_str(line.trim())?;

    println!("Connected to niri event stream (initial state will be provided)");

    loop {
        line.clear();
        match reader.read_line(&mut line) {
            Ok(0) => {
                println!("Niri event stream closed");
                break;
            }
            Ok(_) => {
                if let Ok(event) = serde_json::from_str::<Event>(line.trim()) {
                    // println!("{:?}", event);
                    match &event {
                        Event::WorkspaceActivated { id, focused: _ } => {
                            tx.send(SystemState::FocusedWorkspace { id: *id as i32 })
                                .unwrap();
                        }
                        Event::WorkspaceActiveWindowChanged {
                            workspace_id,
                            active_window_id,
                        } => {
                            for ws in wss.iter_mut().filter(|ws| ws.id == *workspace_id as i32) {
                                match active_window_id {
                                    Some(id) => {
                                        ws.active_window_id = *id as i32;
                                    }
                                    None => {
                                        ws.active_window_id = 0;
                                    }
                                }
                            }
                            tx.send(SystemState::Workspaces(wss.clone())).unwrap();
                        }
                        Event::WorkspacesChanged { workspaces } => {
                            workspaces.iter().for_each(|ws| {
                                wss.push(Workspace {
                                    id: ws.id as i32,
                                    active_window_id: ws.active_window_id.unwrap_or(0) as i32,
                                })
                            });
                            tx.send(SystemState::Workspaces(wss.clone())).unwrap();
                        }
                        _ => {}
                    }
                }
            }
            Err(e) => {
                eprintln!("Error reading from niri socket: {}", e);
                break;
            }
        }
    }

    Ok(())
}
