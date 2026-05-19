from pydantic import BaseModel
from typing import Optional


class UploadResponse(BaseModel):
    file_id: str
    file_name: str
    sample_rate: int
    num_samples: int
    duration_sec: float
    filtered_data: list[float]
    raw_data: list[float]


class HrvRequest(BaseModel):
    file_id: str


class HrvResponse(BaseModel):
    heart_rate: float
    sdnn_ms: float
    rmssd_ms: float
    lf_hf_ratio: float
    stress_index: float
    r_peak_count: int
    r_peak_indices: list[int]
    rr_intervals_ms: list[float]
    mean_rr_ms: float


class AnalyzeRequest(BaseModel):
    file_id: str


class Interpretation(BaseModel):
    summary: str
    findings: list[str]
    recommendations: list[str]


class AnalyzeResponse(BaseModel):
    health_score: float
    avg_heart_rate: float
    hrv_stress_index: float
    interpretation: Interpretation


class HealthResponse(BaseModel):
    status: str
    version: str
