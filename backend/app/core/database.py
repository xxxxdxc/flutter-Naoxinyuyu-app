import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager

from .config import DATABASE_PATH, ensure_runtime_dirs


SCHEMA = """
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'patient',
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    last_login_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS files (
    id TEXT PRIMARY KEY,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    sample_rate INTEGER NOT NULL,
    num_samples INTEGER NOT NULL,
    duration_sec REAL NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS analysis_results (
    file_id TEXT PRIMARY KEY,
    heart_rate REAL NOT NULL,
    sdnn_ms REAL NOT NULL,
    rmssd_ms REAL NOT NULL,
    lf_hf_ratio REAL NOT NULL,
    stress_index REAL NOT NULL,
    r_peak_count INTEGER NOT NULL,
    r_peak_indices TEXT NOT NULL,
    rr_intervals_ms TEXT NOT NULL,
    mean_rr_ms REAL NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(file_id) REFERENCES files(id)
);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    user_name TEXT NOT NULL,
    device_name TEXT NOT NULL,
    record_type TEXT NOT NULL DEFAULT 'acquisition',
    started_at TEXT NOT NULL,
    ended_at TEXT,
    sample_rate INTEGER NOT NULL DEFAULT 500,
    ecg_sample_count INTEGER NOT NULL DEFAULT 0,
    hrv_record_count INTEGER NOT NULL DEFAULT 0,
    stress_record_count INTEGER NOT NULL DEFAULT 0,
    average_heart_rate REAL,
    average_rmssd REAL,
    average_stress_score REAL,
    max_stress_score REAL,
    is_complete INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS session_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(session_id) REFERENCES sessions(id)
);

CREATE TABLE IF NOT EXISTS reports (
    id TEXT PRIMARY KEY,
    file_id TEXT,
    session_id TEXT,
    health_score REAL NOT NULL,
    avg_heart_rate REAL NOT NULL,
    hrv_stress_index REAL NOT NULL,
    summary TEXT NOT NULL,
    findings TEXT NOT NULL,
    recommendations TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY(file_id) REFERENCES files(id),
    FOREIGN KEY(session_id) REFERENCES sessions(id)
);
"""


def initialize_database() -> None:
    ensure_runtime_dirs()
    with sqlite3.connect(DATABASE_PATH) as conn:
        conn.executescript(SCHEMA)


@contextmanager
def get_connection() -> Iterator[sqlite3.Connection]:
    initialize_database()
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("PRAGMA foreign_keys = ON")
        yield conn
        conn.commit()
    finally:
        conn.close()
