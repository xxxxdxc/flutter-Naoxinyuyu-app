# 后端 API v1

后端顶层目录为 `backend/`，FastAPI 包入口为 `backend/app/main.py`。

启动命令：

```powershell
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

依赖安装：

```powershell
pip install -r backend\requirements.txt
```

## API 前缀

所有新接口统一使用 `/api/v1`。

## 当前接口

- `GET /api/v1/health`
- `POST /api/v1/auth/login`
- `POST /api/v1/users`
- `GET /api/v1/users`
- `GET /api/v1/users/{user_id}`
- `POST /api/v1/files/mat`
- `POST /api/v1/analysis/hrv`
- `POST /api/v1/analysis/report`
- `POST /api/v1/sessions`
- `POST /api/v1/sessions/{session_id}/events`
- `PATCH /api/v1/sessions/{session_id}/finish`
- `GET /api/v1/users/{user_id}/sessions`
- `GET /api/v1/sessions/{session_id}`
- `GET /api/v1/reports/{report_id}`

## 数据存储

- SQLite 数据库：`backend/runtime/data/naoxinyuyu.db`
- 上传和派生文件：`backend/runtime/data/uploads/`
- 会话大体量数据：`backend/runtime/data/sessions/`

SQLite 存用户、文件、HRV 结果、会话、事件、报告等元数据。ECG/LFP 等大体量数据优先用文件存储，数据库保存索引和摘要。

## 兼容边界

旧接口 `/api/upload`、`/api/hrv`、`/api/analyze` 不再作为目标 API。前端应调用 `/api/v1/*`。

本次架构迁移不改变 `.mat` 解析、R 峰检测、HRV 算法、BLE 协议或 DBS 协议。
