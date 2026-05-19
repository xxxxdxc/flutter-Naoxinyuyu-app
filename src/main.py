"""Naoxinyuyu 后端服务

FastAPI 本地服务，提供 .mat 文件解析、HRV 计算、分析报告生成等能力。
Flutter 前端通过 HTTP REST API 调用。
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routers import upload, hrv, analyze
from .models.schemas import HealthResponse

app = FastAPI(
    title="Naoxinyuyu Backend",
    description="脑心愈郁 — 闭环DBS多模态上位机后端计算服务",
    version="1.0.0",
)

# CORS 配置 — 允许 Flutter 前端跨域访问
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本地服务允许所有来源
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(upload.router)
app.include_router(hrv.router)
app.include_router(analyze.router)


@app.get("/api/health", response_model=HealthResponse)
async def health_check():
    """健康检查端点"""
    return HealthResponse(status="ok", version="1.0.0")
