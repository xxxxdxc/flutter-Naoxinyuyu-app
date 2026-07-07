"""Naoxinyuyu backend service.

Local FastAPI service for offline ECG/HRV analysis, reports, user metadata,
and session history used by the Flutter desktop app.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.v1.router import router as v1_router
from .core.database import initialize_database

app = FastAPI(
    title="Naoxinyuyu Backend",
    description="脑心愈郁竞赛演示上位机后端服务",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    initialize_database()


app.include_router(v1_router)
