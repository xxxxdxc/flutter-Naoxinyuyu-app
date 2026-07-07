import uuid
from datetime import datetime
from hashlib import sha256

from fastapi import HTTPException

from ...core.database import get_connection


def _normalize_username(username: str) -> str:
    normalized = username.strip().lower()
    if len(normalized) < 2:
        raise HTTPException(status_code=400, detail="用户名至少需要 2 个字符")
    return normalized


def _password_hash(username: str, password: str) -> str:
    if len(password) < 4:
        raise HTTPException(status_code=400, detail="密码至少需要 4 个字符")
    return sha256(f"{username}::{password}::naoxinyuyu".encode("utf-8")).hexdigest()


def _public_user(row) -> dict:
    return {
        "id": row["id"],
        "username": row["username"],
        "display_name": row["display_name"],
        "role": row["role"],
        "created_at": row["created_at"],
        "last_login_at": row["last_login_at"],
    }


def create_user(
    *, username: str, password: str, display_name: str, role: str = "patient"
) -> dict:
    normalized = _normalize_username(username)
    now = datetime.now().isoformat()
    user_id = str(uuid.uuid4())
    try:
        with get_connection() as conn:
            conn.execute(
                """
                INSERT INTO users (
                    id, username, display_name, role, password_hash,
                    created_at, last_login_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    user_id,
                    normalized,
                    display_name.strip() or normalized,
                    role,
                    _password_hash(normalized, password),
                    now,
                    now,
                ),
            )
            row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    except Exception as exc:
        if "UNIQUE" in str(exc).upper():
            raise HTTPException(status_code=409, detail="该用户名已存在") from exc
        raise
    return _public_user(row)


def login_user(*, username: str, password: str) -> dict:
    normalized = _normalize_username(username)
    with get_connection() as conn:
        row = conn.execute(
            "SELECT * FROM users WHERE username = ?", (normalized,)
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="用户不存在")
        if row["password_hash"] != _password_hash(normalized, password):
            raise HTTPException(status_code=401, detail="密码不正确")
        now = datetime.now().isoformat()
        conn.execute(
            "UPDATE users SET last_login_at = ? WHERE id = ?", (now, row["id"])
        )
        row = conn.execute("SELECT * FROM users WHERE id = ?", (row["id"],)).fetchone()
    return _public_user(row)


def list_users() -> list[dict]:
    with get_connection() as conn:
        rows = conn.execute("SELECT * FROM users ORDER BY created_at DESC").fetchall()
    return [_public_user(row) for row in rows]


def get_user(user_id: str) -> dict:
    with get_connection() as conn:
        row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="用户不存在")
    return _public_user(row)
