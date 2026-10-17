use std::env;
use std::fs;
use std::io::{self, BufRead, BufReader, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, SystemTime};

use chrono::{DateTime, Local, TimeDelta, Utc};
use clap::{Parser, Subcommand, ValueEnum};
use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use crossterm::execute;
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::backend::CrosstermBackend;
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Cell, Clear, List, ListItem, Paragraph, Row, Table, TableState, Tabs, Wrap};
use ratatui::Terminal;
use serde::{Deserialize, Serialize};

const EVENT_PREFIX: &str = "CLAMAV_NOTIFY_EVENT:";
const SYSLOG_TAG: &str = "clamav-notify-event";

#[derive(Parser, Debug)]
#[command(
    name = "clamav-notify",
    about = "ClamAV notification daemon, inbox, and interactive TUI"
)]
struct Cli {
    /// Override state directory (defaults to $XDG_STATE_HOME/clamav-notify or ~/.local/state/clamav-notify)
    #[arg(long, global = true, env = "CLAMAV_NOTIFY_STATE_DIR")]
    state_dir: Option<PathBuf>,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Open the interactive TUI inbox (default when no subcommand is given)
    Tui,
    /// Run the user-session background daemon that tails systemd journal and dispatches desktop notifications
    Daemon {
        /// Process pending journal events and expired snoozes once, then exit
        #[arg(long)]
        once: bool,
        /// Lookback window when no saved journal cursor exists
        #[arg(long, default_value = "-7 days")]
        since: String,
    },
    /// List inbox notifications in the terminal
    List {
        /// Filter by status
        #[arg(long, value_enum, default_value_t = FilterTab::All)]
        status: FilterTab,
        /// Output as JSON
        #[arg(long)]
        json: bool,
    },
    /// Snooze an inbox item by ID for a duration (e.g. 15m, 1h, 4h, 8h, 24h, 7d)
    Snooze {
        /// Inbox item ID
        id: u64,
        /// Duration string (e.g. 15m, 1h, 4h, 8h, 24h, 7d)
        duration: String,
    },
    /// Mark an inbox item as closed/resolved
    Close {
        /// Inbox item ID
        id: u64,
    },
    /// Re-open a snoozed or closed inbox item
    Reopen {
        /// Inbox item ID
        id: u64,
    },
    /// Remove all closed items from the inbox
    ClearClosed,
    /// Emit a structured VirusEvent to the systemd journal (used by clamd VirusEvent hook)
    EmitEvent {
        /// Infected file path (defaults to CLAM_VIRUSEVENT_FILENAME)
        #[arg(long)]
        file: Option<String>,
        /// Virus signature name (defaults to CLAM_VIRUSEVENT_VIRUSNAME)
        #[arg(long)]
        virus: Option<String>,
        /// Source label
        #[arg(long, default_value = "clamd")]
        source: String,
    },
    /// Trigger a synthetic test alert to verify notifications and inbox recording
    TestAlert {
        /// Test file path
        #[arg(long, default_value = "/tmp/eicar-test-signature.txt")]
        file: String,
        /// Test signature name
        #[arg(long, default_value = "Win.Test.EICAR_HDB-1")]
        virus: String,
        /// Record directly into inbox and send notification without waiting for the journal daemon
        #[arg(long)]
        direct: bool,
    },
}

#[derive(Copy, Clone, Debug, PartialEq, Eq, ValueEnum)]
enum FilterTab {
    All,
    Open,
    Snoozed,
    Closed,
}

impl FilterTab {
    fn next(self) -> Self {
        match self {
            Self::All => Self::Open,
            Self::Open => Self::Snoozed,
            Self::Snoozed => Self::Closed,
            Self::Closed => Self::All,
        }
    }

    fn previous(self) -> Self {
        match self {
            Self::All => Self::Closed,
            Self::Open => Self::All,
            Self::Snoozed => Self::Open,
            Self::Closed => Self::Snoozed,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
enum AlertStatus {
    Open,
    Snoozed,
    Closed,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
struct AlertItem {
    id: u64,
    filename: String,
    virus_name: String,
    source: String,
    status: AlertStatus,
    hit_count: u64,
    first_seen: DateTime<Utc>,
    last_seen: DateTime<Utc>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    snoozed_until: Option<DateTime<Utc>>,
}

impl AlertItem {
    fn matches_filter(&self, filter: FilterTab) -> bool {
        match filter {
            FilterTab::All => true,
            FilterTab::Open => self.status == AlertStatus::Open,
            FilterTab::Snoozed => self.status == AlertStatus::Snoozed,
            FilterTab::Closed => self.status == AlertStatus::Closed,
        }
    }

    fn status_badge(&self, now: DateTime<Utc>) -> String {
        match self.status {
            AlertStatus::Open => "[ ] OPEN".to_string(),
            AlertStatus::Snoozed => {
                if let Some(until) = self.snoozed_until {
                    let remaining = until.signed_duration_since(now);
                    format!("[z] SNOOZE ({})", format_remaining(remaining))
                } else {
                    "[z] SNOOZED".to_string()
                }
            }
            AlertStatus::Closed => "[x] CLOSED".to_string(),
        }
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
struct InboxStore {
    next_id: u64,
    items: Vec<AlertItem>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
struct WireVirusEvent {
    filename: String,
    virus_name: String,
    #[serde(default = "default_source")]
    source: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    timestamp: Option<DateTime<Utc>>,
}

fn default_source() -> String {
    "clamd".to_string()
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct NotificationPopup {
    summary: String,
    body: String,
}

impl InboxStore {
    fn load(path: &Path) -> io::Result<Self> {
        if !path.exists() {
            return Ok(Self {
                next_id: 1,
                items: Vec::new(),
            });
        }
        let data = fs::read_to_string(path)?;
        if data.trim().is_empty() {
            return Ok(Self {
                next_id: 1,
                items: Vec::new(),
            });
        }
        let mut store: Self = serde_json::from_str(&data)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
        if store.next_id == 0 {
            store.next_id = store.items.iter().map(|i| i.id).max().unwrap_or(0) + 1;
        }
        Ok(store)
    }

    fn save(&self, path: &Path) -> io::Result<()> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let tmp_path = path.with_extension("json.tmp");
        let serialized = serde_json::to_string_pretty(self)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
        {
            let mut file = fs::File::create(&tmp_path)?;
            file.write_all(serialized.as_bytes())?;
            file.write_all(b"\n")?;
            file.sync_all()?;
        }
        fs::rename(&tmp_path, path)?;
        Ok(())
    }

    fn expire_snoozes(&mut self, now: DateTime<Utc>) -> Vec<NotificationPopup> {
        let mut popups = Vec::new();
        for item in &mut self.items {
            if item.status == AlertStatus::Snoozed {
                if let Some(until) = item.snoozed_until {
                    if until <= now {
                        item.status = AlertStatus::Open;
                        item.snoozed_until = None;
                        popups.push(NotificationPopup {
                            summary: format!("ClamAV Alert Resurfaced: {}", item.virus_name),
                            body: format!(
                                "Snooze expired for threat '{}' in:\n{}\n(Seen {} time(s))",
                                item.virus_name, item.filename, item.hit_count
                            ),
                        });
                    }
                }
            }
        }
        popups
    }

    fn ingest_event(
        &mut self,
        event: WireVirusEvent,
        now: DateTime<Utc>,
    ) -> Option<NotificationPopup> {
        let event_time = event.timestamp.unwrap_or(now);
        if let Some(existing) = self
            .items
            .iter_mut()
            .find(|i| i.filename == event.filename && i.virus_name == event.virus_name)
        {
            existing.hit_count += 1;
            existing.last_seen = event_time;
            existing.source = event.source;

            match existing.status {
                AlertStatus::Snoozed => {
                    if let Some(until) = existing.snoozed_until {
                        if until > now {
                            return None;
                        }
                    }
                    existing.status = AlertStatus::Open;
                    existing.snoozed_until = None;
                }
                AlertStatus::Closed => {
                    existing.status = AlertStatus::Open;
                    existing.snoozed_until = None;
                }
                AlertStatus::Open => {}
            }

            return Some(NotificationPopup {
                summary: format!("ClamAV Threat Detected: {}", existing.virus_name),
                body: format!(
                    "Signature: {}\nFile: {}\nDetections: {}",
                    existing.virus_name, existing.filename, existing.hit_count
                ),
            });
        }

        let id = if self.next_id == 0 { 1 } else { self.next_id };
        self.next_id = id + 1;

        let item = AlertItem {
            id,
            filename: event.filename.clone(),
            virus_name: event.virus_name.clone(),
            source: event.source,
            status: AlertStatus::Open,
            hit_count: 1,
            first_seen: event_time,
            last_seen: event_time,
            snoozed_until: None,
        };
        self.items.insert(0, item);

        Some(NotificationPopup {
            summary: format!("ClamAV Threat Detected: {}", event.virus_name),
            body: format!("Signature: {}\nFile: {}", event.virus_name, event.filename),
        })
    }

    fn snooze_item(&mut self, id: u64, until: DateTime<Utc>) -> bool {
        if let Some(item) = self.items.iter_mut().find(|i| i.id == id) {
            item.status = AlertStatus::Snoozed;
            item.snoozed_until = Some(until);
            true
        } else {
            false
        }
    }

    fn close_item(&mut self, id: u64) -> bool {
        if let Some(item) = self.items.iter_mut().find(|i| i.id == id) {
            item.status = AlertStatus::Closed;
            item.snoozed_until = None;
            true
        } else {
            false
        }
    }

    fn reopen_item(&mut self, id: u64) -> bool {
        if let Some(item) = self.items.iter_mut().find(|i| i.id == id) {
            item.status = AlertStatus::Open;
            item.snoozed_until = None;
            true
        } else {
            false
        }
    }

    fn toggle_close(&mut self, id: u64) -> bool {
        if let Some(item) = self.items.iter_mut().find(|i| i.id == id) {
            match item.status {
                AlertStatus::Closed => {
                    item.status = AlertStatus::Open;
                    item.snoozed_until = None;
                }
                AlertStatus::Open | AlertStatus::Snoozed => {
                    item.status = AlertStatus::Closed;
                    item.snoozed_until = None;
                }
            }
            true
        } else {
            false
        }
    }

    fn clear_closed(&mut self) -> usize {
        let before = self.items.len();
        self.items.retain(|i| i.status != AlertStatus::Closed);
        before - self.items.len()
    }
}

fn resolve_state_dir(override_dir: Option<PathBuf>) -> PathBuf {
    if let Some(dir) = override_dir {
        return dir;
    }
    if let Ok(xdg) = env::var("XDG_STATE_HOME") {
        if !xdg.trim().is_empty() {
            return PathBuf::from(xdg).join("clamav-notify");
        }
    }
    if let Ok(home) = env::var("HOME") {
        return PathBuf::from(home).join(".local/state/clamav-notify");
    }
    PathBuf::from("/tmp/clamav-notify")
}

fn inbox_path(state_dir: &Path) -> PathBuf {
    state_dir.join("inbox.json")
}

fn cursor_path(state_dir: &Path) -> PathBuf {
    state_dir.join("cursor")
}

fn parse_duration_str(input: &str) -> Result<TimeDelta, String> {
    let trimmed = input.trim().to_lowercase();
    if trimmed.is_empty() {
        return Err("Duration cannot be empty".to_string());
    }
    let (num_str, unit) = if let Some(n) = trimmed.strip_suffix("ms") {
        (n, "ms")
    } else {
        let split_idx = trimmed
            .find(|c: char| !c.is_ascii_digit())
            .unwrap_or(trimmed.len());
        (&trimmed[..split_idx], &trimmed[split_idx..])
    };
    let value: i64 = num_str
        .parse()
        .map_err(|_| format!("Invalid duration number in '{input}'"))?;
    if value <= 0 {
        return Err("Duration must be positive".to_string());
    }
    match unit {
        "s" | "sec" | "secs" => Ok(TimeDelta::seconds(value)),
        "m" | "min" | "mins" | "" => Ok(TimeDelta::minutes(value)),
        "h" | "hr" | "hrs" => Ok(TimeDelta::hours(value)),
        "d" | "day" | "days" => Ok(TimeDelta::days(value)),
        _ => Err(format!(
            "Unsupported duration unit '{unit}' (use s, m, h, or d)"
        )),
    }
}

fn format_remaining(delta: TimeDelta) -> String {
    let secs = delta.num_seconds();
    if secs <= 0 {
        return "expired".to_string();
    }
    let days = secs / 86_400;
    let hours = (secs % 86_400) / 3_600;
    let mins = (secs % 3_600) / 60;
    if days > 0 {
        format!("{days}d {hours}h")
    } else if hours > 0 {
        format!("{hours}h {mins}m")
    } else if mins > 0 {
        format!("{mins}m")
    } else {
        format!("{secs}s")
    }
}

fn format_local_time(dt: DateTime<Utc>) -> String {
    dt.with_timezone(&Local)
        .format("%Y-%m-%d %H:%M:%S")
        .to_string()
}

fn format_wire_event_line(event: &WireVirusEvent) -> io::Result<String> {
    let json = serde_json::to_string(event)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
    Ok(format!("{EVENT_PREFIX}{json}"))
}

fn parse_wire_event_message(message: &str) -> Option<WireVirusEvent> {
    let trimmed = message.trim();
    let payload = trimmed.strip_prefix(EVENT_PREFIX)?;
    serde_json::from_str(payload).ok()
}

#[derive(Debug)]
struct JournalRecord {
    cursor: Option<String>,
    event: Option<WireVirusEvent>,
}

fn parse_journal_json_line(line: &str) -> Option<JournalRecord> {
    let value: serde_json::Value = serde_json::from_str(line).ok()?;
    let cursor = value
        .get("__CURSOR")
        .and_then(|v| v.as_str())
        .map(ToOwned::to_owned);

    let message = match value.get("MESSAGE")? {
        serde_json::Value::String(s) => s.clone(),
        serde_json::Value::Array(bytes) => {
            let mut buf = Vec::with_capacity(bytes.len());
            for b in bytes {
                buf.push(b.as_u64()? as u8);
            }
            String::from_utf8_lossy(&buf).into_owned()
        }
        _ => return Some(JournalRecord { cursor, event: None }),
    };

    let mut event = parse_wire_event_message(&message)?;
    if event.timestamp.is_none() {
        if let Some(ts_str) = value.get("__REALTIME_TIMESTAMP").and_then(|v| v.as_str()) {
            if let Ok(micros) = ts_str.parse::<i64>() {
                event.timestamp = DateTime::from_timestamp_micros(micros);
            }
        }
    }

    Some(JournalRecord {
        cursor,
        event: Some(event),
    })
}

fn send_desktop_notification(popup: &NotificationPopup) {
    let notify_bin =
        env::var("CLAMAV_NOTIFY_SEND_BIN").unwrap_or_else(|_| "notify-send".to_string());
    let mut cmd = Command::new(notify_bin);
    if env::var_os("DBUS_SESSION_BUS_ADDRESS").is_none() {
        if let Ok(runtime_dir) = env::var("XDG_RUNTIME_DIR") {
            let bus_path = Path::new(&runtime_dir).join("bus");
            if bus_path.exists() {
                cmd.env(
                    "DBUS_SESSION_BUS_ADDRESS",
                    format!("unix:path={}", bus_path.display()),
                );
            }
        }
    }
    let _ = cmd
        .args([
            "-u",
            "critical",
            "-a",
            "ClamAV",
            "-i",
            "dialog-warning",
            &popup.summary,
            &popup.body,
        ])
        .status();
}

fn emit_event_to_journal(file: Option<String>, virus: Option<String>, source: String) -> io::Result<()> {
    let filename = file
        .or_else(|| env::var("CLAM_VIRUSEVENT_FILENAME").ok())
        .unwrap_or_else(|| "<unknown-file>".to_string());
    let virus_name = virus
        .or_else(|| env::var("CLAM_VIRUSEVENT_VIRUSNAME").ok())
        .unwrap_or_else(|| "Unknown.Threat".to_string());

    let event = WireVirusEvent {
        filename,
        virus_name,
        source,
        timestamp: Some(Utc::now()),
    };
    let line = format_wire_event_line(&event)?;

    let mut child = Command::new("systemd-cat")
        .args(["-t", SYSLOG_TAG])
        .stdin(Stdio::piped())
        .spawn();

    if let Ok(ref mut proc) = child {
        if let Some(mut stdin) = proc.stdin.take() {
            let _ = writeln!(stdin, "{line}");
        }
        if let Ok(status) = proc.wait() {
            if status.success() {
                return Ok(());
            }
        }
    }

    println!("{line}");
    Ok(())
}

fn build_journalctl_args(saved_cursor: Option<&str>, since: &str, once: bool) -> Vec<String> {
    let mut args = vec!["--output=json".to_string(), "--no-pager".to_string()];
    if !once {
        args.push("--follow".to_string());
    }
    if let Some(cursor) = saved_cursor {
        args.push(format!("--after-cursor={cursor}"));
    } else {
        args.push(format!("--since={since}"));
    }
    args.extend([
        "_SYSTEMD_UNIT=clamav-daemon.service".to_string(),
        "+".to_string(),
        "_SYSTEMD_UNIT=clamdscan.service".to_string(),
        "+".to_string(),
        format!("SYSLOG_IDENTIFIER={SYSLOG_TAG}"),
    ]);
    args
}

fn process_expired_snoozes(state_dir: &Path) -> io::Result<()> {
    let path = inbox_path(state_dir);
    let mut store = InboxStore::load(&path)?;
    let popups = store.expire_snoozes(Utc::now());
    if !popups.is_empty() {
        store.save(&path)?;
        for popup in &popups {
            send_desktop_notification(popup);
        }
    }
    Ok(())
}

fn process_journal_line(state_dir: &Path, line: &str) -> io::Result<()> {
    let Some(record) = parse_journal_json_line(line) else {
        return Ok(());
    };
    if let Some(event) = record.event {
        let path = inbox_path(state_dir);
        let mut store = InboxStore::load(&path)?;
        let expired_popups = store.expire_snoozes(Utc::now());
        let event_popup = store.ingest_event(event, Utc::now());
        store.save(&path)?;

        for popup in &expired_popups {
            send_desktop_notification(popup);
        }
        if let Some(popup) = event_popup {
            send_desktop_notification(&popup);
        }
    }
    if let Some(cursor) = record.cursor {
        fs::create_dir_all(state_dir)?;
        let _ = fs::write(cursor_path(state_dir), cursor);
    }
    Ok(())
}

fn run_daemon(state_dir: &Path, once: bool, since: &str) -> io::Result<()> {
    fs::create_dir_all(state_dir)?;
    process_expired_snoozes(state_dir)?;

    let saved_cursor = fs::read_to_string(cursor_path(state_dir))
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());

    let journal_bin = env::var("CLAMAV_NOTIFY_JOURNALCTL_BIN").unwrap_or_else(|_| "journalctl".to_string());

    if once {
        let args = build_journalctl_args(saved_cursor.as_deref(), since, true);
        let output = Command::new(&journal_bin).args(&args).output()?;
        let lines_output = if !output.status.success() && saved_cursor.is_some() {
            let fallback_args = build_journalctl_args(None, since, true);
            Command::new(&journal_bin).args(&fallback_args).output()?
        } else {
            output
        };
        let stdout = String::from_utf8_lossy(&lines_output.stdout);
        for line in stdout.lines() {
            process_journal_line(state_dir, line)?;
        }
        process_expired_snoozes(state_dir)?;
        return Ok(());
    }

    let mut args = build_journalctl_args(saved_cursor.as_deref(), since, false);
    let mut child = Command::new(&journal_bin)
        .args(&args)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()?;

    thread::sleep(Duration::from_millis(150));
    if let Ok(Some(status)) = child.try_wait() {
        if !status.success() && saved_cursor.is_some() {
            args = build_journalctl_args(None, since, false);
            child = Command::new(&journal_bin)
                .args(&args)
                .stdout(Stdio::piped())
                .stderr(Stdio::null())
                .spawn()?;
        }
    }

    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| io::Error::other("Failed to capture journalctl stdout"))?;

    let (tx, rx) = mpsc::channel::<String>();
    thread::spawn(move || {
        let reader = BufReader::new(stdout);
        for line in reader.lines().map_while(Result::ok) {
            if tx.send(line).is_err() {
                break;
            }
        }
    });

    loop {
        match rx.recv_timeout(Duration::from_secs(5)) {
            Ok(line) => {
                process_journal_line(state_dir, &line)?;
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {
                process_expired_snoozes(state_dir)?;
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                return Err(io::Error::new(
                    io::ErrorKind::UnexpectedEof,
                    "journalctl stream ended",
                ));
            }
        }
    }
}

fn run_list(state_dir: &Path, filter: FilterTab, as_json: bool) -> io::Result<()> {
    process_expired_snoozes(state_dir)?;
    let store = InboxStore::load(&inbox_path(state_dir))?;
    let filtered: Vec<&AlertItem> = store
        .items
        .iter()
        .filter(|i| i.matches_filter(filter))
        .collect();

    let mut out = io::stdout().lock();
    let res = (|| -> io::Result<()> {
        if as_json {
            let text = serde_json::to_string_pretty(&filtered)
                .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
            writeln!(out, "{text}")?;
            return Ok(());
        }

        if filtered.is_empty() {
            writeln!(out, "No ClamAV notifications matching filter {:?}.", filter)?;
            return Ok(());
        }

        let now = Utc::now();
        writeln!(
            out,
            "{:<4} {:<22} {:<28} {:<6} {:<19} FILE",
            "ID", "STATUS", "SIGNATURE", "HITS", "LAST SEEN"
        )?;
        for item in filtered {
            writeln!(
                out,
                "{:<4} {:<22} {:<28} {:<6} {:<19} {}",
                item.id,
                item.status_badge(now),
                item.virus_name,
                item.hit_count,
                format_local_time(item.last_seen),
                item.filename
            )?;
        }
        Ok(())
    })();

    match res {
        Err(e) if e.kind() == io::ErrorKind::BrokenPipe => Ok(()),
        other => other,
    }
}

const SNOOZE_PRESETS: &[(&str, &str)] = &[
    ("15m", "15 minutes"),
    ("1h", "1 hour"),
    ("4h", "4 hours"),
    ("8h", "8 hours"),
    ("24h", "24 hours"),
    ("7d", "7 days"),
    ("unsnooze", "Unsnooze (Re-open immediately)"),
];

struct TuiApp {
    state_dir: PathBuf,
    store: InboxStore,
    filter: FilterTab,
    table_state: TableState,
    snooze_modal: Option<usize>,
    status_message: String,
    last_mtime: Option<SystemTime>,
}

impl TuiApp {
    fn new(state_dir: PathBuf) -> io::Result<Self> {
        let _ = process_expired_snoozes(&state_dir);
        let path = inbox_path(&state_dir);
        let last_mtime = fs::metadata(&path).and_then(|m| m.modified()).ok();
        let store = InboxStore::load(&path)?;
        let mut table_state = TableState::default();
        if !store.items.is_empty() {
            table_state.select(Some(0));
        }
        Ok(Self {
            state_dir,
            store,
            filter: FilterTab::All,
            table_state,
            snooze_modal: None,
            status_message: "Ready.".to_string(),
            last_mtime,
        })
    }

    fn filtered_items(&self) -> Vec<&AlertItem> {
        self.store
            .items
            .iter()
            .filter(|i| i.matches_filter(self.filter))
            .collect()
    }

    fn selected_item_id(&self) -> Option<u64> {
        let items = self.filtered_items();
        let idx = self.table_state.selected()?;
        items.get(idx).map(|i| i.id)
    }

    fn clamp_selection(&mut self) {
        let len = self.filtered_items().len();
        if len == 0 {
            self.table_state.select(None);
        } else {
            let current = self.table_state.selected().unwrap_or(0);
            if current >= len {
                self.table_state.select(Some(len - 1));
            } else if self.table_state.selected().is_none() {
                self.table_state.select(Some(0));
            }
        }
    }

    fn reload_if_changed(&mut self, force: bool) -> io::Result<()> {
        let _ = process_expired_snoozes(&self.state_dir);
        let path = inbox_path(&self.state_dir);
        let current_mtime = fs::metadata(&path).and_then(|m| m.modified()).ok();
        if !force && current_mtime == self.last_mtime {
            return Ok(());
        }
        let selected_id = self.selected_item_id();
        self.store = InboxStore::load(&path)?;
        self.last_mtime = current_mtime;

        let filtered = self.filtered_items();
        if let Some(id) = selected_id {
            if let Some(pos) = filtered.iter().position(|i| i.id == id) {
                self.table_state.select(Some(pos));
                return Ok(());
            }
        }
        self.clamp_selection();
        Ok(())
    }

    fn save_store(&mut self) -> io::Result<()> {
        let path = inbox_path(&self.state_dir);
        self.store.save(&path)?;
        self.last_mtime = fs::metadata(&path).and_then(|m| m.modified()).ok();
        self.clamp_selection();
        Ok(())
    }
}

fn run_tui(state_dir: PathBuf) -> io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let result = run_tui_loop(&mut terminal, state_dir);

    let _ = disable_raw_mode();
    let _ = execute!(terminal.backend_mut(), LeaveAlternateScreen);
    let _ = terminal.show_cursor();

    result
}

fn run_tui_loop(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    state_dir: PathBuf,
) -> io::Result<()> {
    let mut app = TuiApp::new(state_dir)?;

    loop {
        app.reload_if_changed(false)?;
        terminal.draw(|f| draw_tui(f, &mut app))?;

        if event::poll(Duration::from_millis(500))? {
            if let Event::Key(key) = event::read()? {
                if key.kind != KeyEventKind::Press {
                    continue;
                }
                if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
                    return Ok(());
                }

                if let Some(modal_idx) = app.snooze_modal {
                    match key.code {
                        KeyCode::Esc | KeyCode::Char('q') => {
                            app.snooze_modal = None;
                        }
                        KeyCode::Down | KeyCode::Char('j') => {
                            app.snooze_modal = Some((modal_idx + 1) % SNOOZE_PRESETS.len());
                        }
                        KeyCode::Up | KeyCode::Char('k') => {
                            app.snooze_modal = Some(
                                (modal_idx + SNOOZE_PRESETS.len() - 1) % SNOOZE_PRESETS.len(),
                            );
                        }
                        KeyCode::Enter | KeyCode::Char(' ') => {
                            if let Some(id) = app.selected_item_id() {
                                let (code, label) = SNOOZE_PRESETS[modal_idx];
                                if code == "unsnooze" {
                                    app.store.reopen_item(id);
                                    app.status_message = format!("Re-opened alert #{id}.");
                                } else if let Ok(delta) = parse_duration_str(code) {
                                    let until = Utc::now() + delta;
                                    app.store.snooze_item(id, until);
                                    app.status_message =
                                        format!("Snoozed alert #{id} for {label}.");
                                }
                                app.save_store()?;
                            }
                            app.snooze_modal = None;
                        }
                        _ => {}
                    }
                    continue;
                }

                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                    KeyCode::Tab => {
                        app.filter = app.filter.next();
                        app.clamp_selection();
                    }
                    KeyCode::BackTab => {
                        app.filter = app.filter.previous();
                        app.clamp_selection();
                    }
                    KeyCode::Char('1') => {
                        app.filter = FilterTab::All;
                        app.clamp_selection();
                    }
                    KeyCode::Char('2') => {
                        app.filter = FilterTab::Open;
                        app.clamp_selection();
                    }
                    KeyCode::Char('3') => {
                        app.filter = FilterTab::Snoozed;
                        app.clamp_selection();
                    }
                    KeyCode::Char('4') => {
                        app.filter = FilterTab::Closed;
                        app.clamp_selection();
                    }
                    KeyCode::Down | KeyCode::Char('j') => {
                        let len = app.filtered_items().len();
                        if len > 0 {
                            let next = match app.table_state.selected() {
                                Some(i) => (i + 1) % len,
                                None => 0,
                            };
                            app.table_state.select(Some(next));
                        }
                    }
                    KeyCode::Up | KeyCode::Char('k') => {
                        let len = app.filtered_items().len();
                        if len > 0 {
                            let prev = match app.table_state.selected() {
                                Some(i) => (i + len - 1) % len,
                                None => 0,
                            };
                            app.table_state.select(Some(prev));
                        }
                    }
                    KeyCode::Char(' ') | KeyCode::Enter => {
                        if let Some(id) = app.selected_item_id() {
                            app.store.toggle_close(id);
                            app.save_store()?;
                            app.status_message = format!("Toggled status for alert #{id}.");
                        }
                    }
                    KeyCode::Char('s') => {
                        if app.selected_item_id().is_some() {
                            app.snooze_modal = Some(1);
                        }
                    }
                    KeyCode::Char('u') => {
                        if let Some(id) = app.selected_item_id() {
                            app.store.reopen_item(id);
                            app.save_store()?;
                            app.status_message = format!("Unsnoozed/re-opened alert #{id}.");
                        }
                    }
                    KeyCode::Char('c') => {
                        let removed = app.store.clear_closed();
                        app.save_store()?;
                        app.status_message = format!("Cleared {removed} closed alert(s).");
                    }
                    KeyCode::Char('r') => {
                        app.reload_if_changed(true)?;
                        app.status_message = "Refreshed inbox.".to_string();
                    }
                    KeyCode::Char('t') => {
                        let event = WireVirusEvent {
                            filename: "/tmp/eicar-test-signature.txt".to_string(),
                            virus_name: "Win.Test.EICAR_HDB-1".to_string(),
                            source: "test-alert".to_string(),
                            timestamp: Some(Utc::now()),
                        };
                        if let Some(popup) = app.store.ingest_event(event, Utc::now()) {
                            send_desktop_notification(&popup);
                        }
                        app.save_store()?;
                        app.status_message = "Triggered synthetic test alert.".to_string();
                    }
                    _ => {}
                }
            }
        }
    }
}

fn draw_tui(f: &mut ratatui::Frame, app: &mut TuiApp) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Min(8),
            Constraint::Length(7),
            Constraint::Length(2),
        ])
        .split(f.area());

    let total_all = app.store.items.len();
    let total_open = app
        .store
        .items
        .iter()
        .filter(|i| i.status == AlertStatus::Open)
        .count();
    let total_snoozed = app
        .store
        .items
        .iter()
        .filter(|i| i.status == AlertStatus::Snoozed)
        .count();
    let total_closed = app
        .store
        .items
        .iter()
        .filter(|i| i.status == AlertStatus::Closed)
        .count();

    let tab_titles = vec![
        Line::from(format!(" [1] All ({total_all}) ")),
        Line::from(format!(" [2] Active ({total_open}) ")),
        Line::from(format!(" [3] Snoozed ({total_snoozed}) ")),
        Line::from(format!(" [4] Closed ({total_closed}) ")),
    ];
    let selected_tab = match app.filter {
        FilterTab::All => 0,
        FilterTab::Open => 1,
        FilterTab::Snoozed => 2,
        FilterTab::Closed => 3,
    };
    let tabs = Tabs::new(tab_titles)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title(" ClamAV Notification Inbox "),
        )
        .select(selected_tab)
        .highlight_style(
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        );
    f.render_widget(tabs, chunks[0]);

    let now = Utc::now();
    let filtered = app.filtered_items();
    let rows: Vec<Row> = filtered
        .iter()
        .map(|item| {
            let style = match item.status {
                AlertStatus::Open => Style::default().fg(Color::LightRed),
                AlertStatus::Snoozed => Style::default().fg(Color::Yellow),
                AlertStatus::Closed => Style::default().fg(Color::DarkGray),
            };
            Row::new(vec![
                Cell::from(format!("#{}", item.id)),
                Cell::from(item.status_badge(now)),
                Cell::from(item.virus_name.clone()),
                Cell::from(item.filename.clone()),
                Cell::from(format!("x{}", item.hit_count)),
                Cell::from(format_local_time(item.last_seen)),
            ])
            .style(style)
        })
        .collect();

    let header = Row::new(vec![
        "ID",
        "Status",
        "Signature",
        "File Path",
        "Hits",
        "Last Seen",
    ])
    .style(
        Style::default()
            .fg(Color::White)
            .add_modifier(Modifier::BOLD),
    );

    let table = Table::new(
        rows,
        [
            Constraint::Length(5),
            Constraint::Length(22),
            Constraint::Length(28),
            Constraint::Min(24),
            Constraint::Length(6),
            Constraint::Length(20),
        ],
    )
    .header(header)
    .block(Block::default().borders(Borders::ALL).title(" Detections "))
    .row_highlight_style(
        Style::default()
            .bg(Color::DarkGray)
            .add_modifier(Modifier::BOLD),
    )
    .highlight_symbol(">> ");

    let detail_text = if let Some(idx) = app.table_state.selected() {
        if let Some(item) = filtered.get(idx) {
            let snooze_info = item
                .snoozed_until
                .map(|u| format!(" (until {})", format_local_time(u)))
                .unwrap_or_default();
            vec![
                Line::from(vec![
                    Span::styled("File:       ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(item.filename.clone()),
                ]),
                Line::from(vec![
                    Span::styled("Signature:  ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(item.virus_name.clone()),
                    Span::raw("   "),
                    Span::styled("Source: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(item.source.clone()),
                ]),
                Line::from(vec![
                    Span::styled("Status:     ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(format!("{:?}{}", item.status, snooze_info)),
                    Span::raw("   "),
                    Span::styled("Hits: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(item.hit_count.to_string()),
                ]),
                Line::from(vec![
                    Span::styled("First Seen: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(format_local_time(item.first_seen)),
                    Span::raw("   "),
                    Span::styled("Last Seen: ", Style::default().add_modifier(Modifier::BOLD)),
                    Span::raw(format_local_time(item.last_seen)),
                ]),
            ]
        } else {
            vec![Line::from("No alert selected.")]
        }
    } else {
        vec![Line::from(
            "Inbox is empty for this filter. Press 't' to send a test alert.",
        )]
    };

    f.render_stateful_widget(table, chunks[1], &mut app.table_state);

    let details = Paragraph::new(detail_text)
        .block(Block::default().borders(Borders::ALL).title(" Details "))
        .wrap(Wrap { trim: false });
    f.render_widget(details, chunks[2]);

    let footer = Paragraph::new(Line::from(vec![
        Span::styled(
            " Space/Enter",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        ),
        Span::raw(": Check/Close  "),
        Span::styled(
            "s",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        ),
        Span::raw(": Snooze  "),
        Span::styled(
            "u",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        ),
        Span::raw(": Unsnooze  "),
        Span::styled(
            "c",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        ),
        Span::raw(": Clear Closed  "),
        Span::styled(
            "t",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        ),
        Span::raw(": Test Alert  "),
        Span::styled(
            "Tab/1-4",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        ),
        Span::raw(": Filter  "),
        Span::styled(
            "q",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        ),
        Span::raw(format!(": Quit   | {}", app.status_message)),
    ]));
    f.render_widget(footer, chunks[3]);

    if let Some(modal_idx) = app.snooze_modal {
        let area = centered_rect(48, 12, f.area());
        f.render_widget(Clear, area);
        let items: Vec<ListItem> = SNOOZE_PRESETS
            .iter()
            .enumerate()
            .map(|(idx, (_, label))| {
                let style = if idx == modal_idx {
                    Style::default()
                        .fg(Color::Black)
                        .bg(Color::Yellow)
                        .add_modifier(Modifier::BOLD)
                } else {
                    Style::default()
                };
                let prefix = if idx == modal_idx { ">> " } else { "   " };
                ListItem::new(format!("{prefix}{label}")).style(style)
            })
            .collect();
        let list = List::new(items).block(
            Block::default()
                .borders(Borders::ALL)
                .title(" Snooze Duration (Enter to confirm, Esc to cancel) "),
        );
        f.render_widget(list, area);
    }
}

fn centered_rect(width: u16, height: u16, r: Rect) -> Rect {
    let w = width.min(r.width);
    let h = height.min(r.height);
    Rect {
        x: r.x + (r.width.saturating_sub(w)) / 2,
        y: r.y + (r.height.saturating_sub(h)) / 2,
        width: w,
        height: h,
    }
}

fn main() -> io::Result<()> {
    let cli = Cli::parse();
    let state_dir = resolve_state_dir(cli.state_dir);

    match cli.command.unwrap_or(Commands::Tui) {
        Commands::Tui => run_tui(state_dir),
        Commands::Daemon { once, since } => run_daemon(&state_dir, once, &since),
        Commands::List { status, json } => run_list(&state_dir, status, json),
        Commands::Snooze { id, duration } => {
            let delta = parse_duration_str(&duration)
                .map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, e))?;
            let path = inbox_path(&state_dir);
            let mut store = InboxStore::load(&path)?;
            let until = Utc::now() + delta;
            if !store.snooze_item(id, until) {
                return Err(io::Error::new(
                    io::ErrorKind::NotFound,
                    format!("Alert #{id} not found"),
                ));
            }
            store.save(&path)?;
            println!(
                "Snoozed alert #{id} until {}.",
                format_local_time(until)
            );
            Ok(())
        }
        Commands::Close { id } => {
            let path = inbox_path(&state_dir);
            let mut store = InboxStore::load(&path)?;
            if !store.close_item(id) {
                return Err(io::Error::new(
                    io::ErrorKind::NotFound,
                    format!("Alert #{id} not found"),
                ));
            }
            store.save(&path)?;
            println!("Closed alert #{id}.");
            Ok(())
        }
        Commands::Reopen { id } => {
            let path = inbox_path(&state_dir);
            let mut store = InboxStore::load(&path)?;
            if !store.reopen_item(id) {
                return Err(io::Error::new(
                    io::ErrorKind::NotFound,
                    format!("Alert #{id} not found"),
                ));
            }
            store.save(&path)?;
            println!("Re-opened alert #{id}.");
            Ok(())
        }
        Commands::ClearClosed => {
            let path = inbox_path(&state_dir);
            let mut store = InboxStore::load(&path)?;
            let removed = store.clear_closed();
            store.save(&path)?;
            println!("Cleared {removed} closed alert(s).");
            Ok(())
        }
        Commands::EmitEvent {
            file,
            virus,
            source,
        } => emit_event_to_journal(file, virus, source),
        Commands::TestAlert {
            file,
            virus,
            direct,
        } => {
            if direct {
                let path = inbox_path(&state_dir);
                let mut store = InboxStore::load(&path)?;
                let event = WireVirusEvent {
                    filename: file,
                    virus_name: virus,
                    source: "test-alert".to_string(),
                    timestamp: Some(Utc::now()),
                };
                if let Some(popup) = store.ingest_event(event, Utc::now()) {
                    send_desktop_notification(&popup);
                }
                store.save(&path)?;
                println!("Recorded test alert directly into inbox.");
                Ok(())
            } else {
                emit_event_to_journal(Some(file), Some(virus), "test-alert".to_string())?;
                println!("Emitted test alert to systemd journal.");
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_wire_event_roundtrip_with_colons_and_spaces() {
        let ev = WireVirusEvent {
            filename: "/home/mahdtech/Downloads/weird:file name (1).exe".to_string(),
            virus_name: "Win.Test.EICAR_HDB-1".to_string(),
            source: "clamd".to_string(),
            timestamp: None,
        };
        let line = format_wire_event_line(&ev).unwrap();
        let parsed = parse_wire_event_message(&line).unwrap();
        assert_eq!(parsed, ev);
    }

    #[test]
    fn test_deduplication_snooze_and_reopen_lifecycle() {
        let mut store = InboxStore::default();
        let t0 = DateTime::from_timestamp(1_700_000_000, 0).unwrap();
        let ev = WireVirusEvent {
            filename: "/tmp/malicious.bin".to_string(),
            virus_name: "Trojan.Generic".to_string(),
            source: "clamd".to_string(),
            timestamp: Some(t0),
        };

        // First detection creates item #1 and returns popup
        let popup1 = store.ingest_event(ev.clone(), t0);
        assert!(popup1.is_some());
        assert_eq!(store.items.len(), 1);
        assert_eq!(store.items[0].id, 1);
        assert_eq!(store.items[0].hit_count, 1);
        assert_eq!(store.items[0].status, AlertStatus::Open);

        // Snooze for 1 hour
        let snooze_until = t0 + TimeDelta::hours(1);
        assert!(store.snooze_item(1, snooze_until));
        assert_eq!(store.items[0].status, AlertStatus::Snoozed);

        // Repeat detection while snoozed increments hit_count but suppresses popup
        let t1 = t0 + TimeDelta::minutes(15);
        let popup2 = store.ingest_event(ev.clone(), t1);
        assert!(popup2.is_none());
        assert_eq!(store.items[0].hit_count, 2);
        assert_eq!(store.items[0].status, AlertStatus::Snoozed);

        // Snooze expires after 1 hour -> resurfaces as Open with reminder popup
        let t2 = t0 + TimeDelta::minutes(61);
        let expired = store.expire_snoozes(t2);
        assert_eq!(expired.len(), 1);
        assert_eq!(store.items[0].status, AlertStatus::Open);

        // User closes the item
        assert!(store.close_item(1));
        assert_eq!(store.items[0].status, AlertStatus::Closed);

        // New detection after close re-opens the item and triggers a popup
        let t3 = t2 + TimeDelta::minutes(5);
        let popup3 = store.ingest_event(ev, t3);
        assert!(popup3.is_some());
        assert_eq!(store.items[0].status, AlertStatus::Open);
        assert_eq!(store.items[0].hit_count, 3);
    }

    #[test]
    fn test_parse_journal_json_line() {
        let json_line = r#"{"__CURSOR":"s=abc;i=1","__REALTIME_TIMESTAMP":"1700000000000000","MESSAGE":"CLAMAV_NOTIFY_EVENT:{\"filename\":\"/tmp/test\",\"virus_name\":\"EICAR\"}"}"#;
        let record = parse_journal_json_line(json_line).unwrap();
        assert_eq!(record.cursor.as_deref(), Some("s=abc;i=1"));
        let ev = record.event.unwrap();
        assert_eq!(ev.filename, "/tmp/test");
        assert_eq!(ev.virus_name, "EICAR");
    }

    #[test]
    fn test_parse_duration() {
        assert_eq!(parse_duration_str("15m").unwrap(), TimeDelta::minutes(15));
        assert_eq!(parse_duration_str("2h").unwrap(), TimeDelta::hours(2));
        assert_eq!(parse_duration_str("7d").unwrap(), TimeDelta::days(7));
        assert!(parse_duration_str("0m").is_err());
        assert!(parse_duration_str("invalid").is_err());
    }
}
