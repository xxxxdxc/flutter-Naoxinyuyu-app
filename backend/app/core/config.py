from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[1]
BACKEND_DIR = APP_DIR.parent
RUNTIME_DIR = BACKEND_DIR / "runtime"
DATA_DIR = RUNTIME_DIR / "data"
UPLOAD_DIR = DATA_DIR / "uploads"
SESSION_DIR = DATA_DIR / "sessions"
DATABASE_PATH = DATA_DIR / "naoxinyuyu.db"


def ensure_runtime_dirs() -> None:
    for path in (DATA_DIR, UPLOAD_DIR, SESSION_DIR):
        path.mkdir(parents=True, exist_ok=True)
