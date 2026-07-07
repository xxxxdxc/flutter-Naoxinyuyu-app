import json
import uuid
from datetime import datetime

from ...core.config import UPLOAD_DIR
from ...core.database import get_connection


def save_uploaded_mat(
    *,
    file_name: str,
    contents: bytes,
    sample_rate: int,
    filtered_data: list[float],
    raw_data: list[float],
    mat_data: dict,
) -> dict:
    file_id = str(uuid.uuid4())
    stored_path = UPLOAD_DIR / f"{file_id}.json"
    duration_sec = len(filtered_data) / sample_rate
    payload = {
        "file_name": file_name,
        "sample_rate": sample_rate,
        "filtered_data": filtered_data,
        "raw_data": raw_data,
        "mat_data": mat_data,
        "original_size": len(contents),
    }
    stored_path.write_text(json.dumps(payload), encoding="utf-8")

    record = {
        "id": file_id,
        "file_name": file_name,
        "file_path": str(stored_path),
        "sample_rate": sample_rate,
        "num_samples": len(filtered_data),
        "duration_sec": duration_sec,
        "created_at": datetime.now().isoformat(),
    }
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO files (
                id, file_name, file_path, sample_rate, num_samples,
                duration_sec, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                record["id"],
                record["file_name"],
                record["file_path"],
                record["sample_rate"],
                record["num_samples"],
                record["duration_sec"],
                record["created_at"],
            ),
        )
    return record | payload


def load_uploaded_mat(file_id: str) -> dict | None:
    with get_connection() as conn:
        row = conn.execute("SELECT * FROM files WHERE id = ?", (file_id,)).fetchone()
    if row is None:
        return None

    payload = json.loads(row["file_path"] and open(row["file_path"], encoding="utf-8").read())
    return dict(row) | payload
