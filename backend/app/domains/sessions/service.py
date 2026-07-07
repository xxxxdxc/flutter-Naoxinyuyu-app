import json
import uuid
from datetime import datetime

from fastapi import HTTPException

from ...core.database import get_connection


def _session_from_row(row) -> dict:
    return {
        "session_id": row["id"],
        "record_type": row["record_type"],
        "user_id": row["user_id"],
        "user_name": row["user_name"],
        "device_name": row["device_name"],
        "started_at": row["started_at"],
        "ended_at": row["ended_at"],
        "sample_rate": row["sample_rate"],
        "ecg_sample_count": row["ecg_sample_count"],
        "hrv_record_count": row["hrv_record_count"],
        "stress_record_count": row["stress_record_count"],
        "average_heart_rate": row["average_heart_rate"],
        "average_rmssd": row["average_rmssd"],
        "average_stress_score": row["average_stress_score"],
        "max_stress_score": row["max_stress_score"],
        "is_complete": bool(row["is_complete"]),
    }


def create_session(
    *,
    user_id: str,
    user_name: str,
    device_name: str,
    sample_rate: int = 500,
    record_type: str = "acquisition",
) -> dict:
    session_id = str(uuid.uuid4())
    now = datetime.now().isoformat()
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO sessions (
                id, user_id, user_name, device_name, record_type,
                started_at, sample_rate
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (session_id, user_id, user_name, device_name, record_type, now, sample_rate),
        )
        row = conn.execute("SELECT * FROM sessions WHERE id = ?", (session_id,)).fetchone()
    return _session_from_row(row)


def add_session_event(session_id: str, event_type: str, payload: dict) -> dict:
    now = datetime.now().isoformat()
    with get_connection() as conn:
        row = conn.execute("SELECT * FROM sessions WHERE id = ?", (session_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="会话不存在")
        conn.execute(
            """
            INSERT INTO session_events (session_id, event_type, payload, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (session_id, event_type, json.dumps(payload, ensure_ascii=False), now),
        )
        if event_type == "ecg_chunk":
            count = len(payload.get("samples", []))
            conn.execute(
                """
                UPDATE sessions
                SET ecg_sample_count = ecg_sample_count + ?
                WHERE id = ?
                """,
                (count, session_id),
            )
        elif event_type == "hrv_metric":
            conn.execute(
                """
                UPDATE sessions
                SET hrv_record_count = hrv_record_count + 1
                WHERE id = ?
                """,
                (session_id,),
            )
        elif event_type == "stress_metric":
            conn.execute(
                """
                UPDATE sessions
                SET stress_record_count = stress_record_count + 1
                WHERE id = ?
                """,
                (session_id,),
            )
    return {"session_id": session_id, "event_type": event_type, "created_at": now}


def finish_session(session_id: str, summary: dict | None = None) -> dict:
    summary = summary or {}
    now = datetime.now().isoformat()
    with get_connection() as conn:
        existing = conn.execute(
            "SELECT * FROM sessions WHERE id = ?", (session_id,)
        ).fetchone()
        if existing is None:
            raise HTTPException(status_code=404, detail="会话不存在")
        conn.execute(
            """
            UPDATE sessions
            SET ended_at = ?,
                average_heart_rate = COALESCE(?, average_heart_rate),
                average_rmssd = COALESCE(?, average_rmssd),
                average_stress_score = COALESCE(?, average_stress_score),
                max_stress_score = COALESCE(?, max_stress_score),
                is_complete = 1
            WHERE id = ?
            """,
            (
                now,
                summary.get("average_heart_rate"),
                summary.get("average_rmssd"),
                summary.get("average_stress_score"),
                summary.get("max_stress_score"),
                session_id,
            ),
        )
        row = conn.execute("SELECT * FROM sessions WHERE id = ?", (session_id,)).fetchone()
    return _session_from_row(row)


def list_sessions_for_user(user_id: str) -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT * FROM sessions WHERE user_id = ? ORDER BY started_at DESC",
            (user_id,),
        ).fetchall()
    return [_session_from_row(row) for row in rows]


def get_session(session_id: str) -> dict:
    with get_connection() as conn:
        row = conn.execute("SELECT * FROM sessions WHERE id = ?", (session_id,)).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="会话不存在")
        events = conn.execute(
            """
            SELECT event_type, payload, created_at
            FROM session_events
            WHERE session_id = ?
            ORDER BY id ASC
            """,
            (session_id,),
        ).fetchall()
    session = _session_from_row(row)
    session["events"] = [
        {
            "event_type": event["event_type"],
            "payload": json.loads(event["payload"]),
            "created_at": event["created_at"],
        }
        for event in events
    ]
    return session
