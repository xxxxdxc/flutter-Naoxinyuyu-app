from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    version: str


class UserCreate(BaseModel):
    username: str
    password: str
    display_name: str
    role: str = "patient"


class LoginRequest(BaseModel):
    username: str
    password: str


class UserResponse(BaseModel):
    id: str
    username: str
    display_name: str
    role: str
    created_at: str
    last_login_at: str


class UploadResponse(BaseModel):
    file_id: str
    file_name: str
    sample_rate: int
    num_samples: int
    duration_sec: float
    filtered_data: list[float]
    raw_data: list[float]


class FileRequest(BaseModel):
    file_id: str


class HrvResponse(BaseModel):
    file_id: str
    heart_rate: float
    sdnn_ms: float
    rmssd_ms: float
    lf_hf_ratio: float
    stress_index: float
    r_peak_count: int
    r_peak_indices: list[int]
    rr_intervals_ms: list[float]
    mean_rr_ms: float


class Interpretation(BaseModel):
    summary: str
    findings: list[str]
    recommendations: list[str]


class AnalyzeResponse(BaseModel):
    report_id: str
    file_id: str | None = None
    session_id: str | None = None
    health_score: float
    avg_heart_rate: float
    hrv_stress_index: float
    interpretation: Interpretation
    created_at: str | None = None


class SessionCreate(BaseModel):
    user_id: str
    user_name: str
    device_name: str
    sample_rate: int = 500
    record_type: str = "acquisition"


class SessionEventCreate(BaseModel):
    event_type: str
    payload: dict = {}


class SessionFinishRequest(BaseModel):
    average_heart_rate: float | None = None
    average_rmssd: float | None = None
    average_stress_score: float | None = None
    max_stress_score: float | None = None


class SessionSummary(BaseModel):
    session_id: str
    record_type: str
    user_id: str
    user_name: str
    device_name: str
    started_at: str
    ended_at: str | None = None
    sample_rate: int
    ecg_sample_count: int
    hrv_record_count: int
    stress_record_count: int
    average_heart_rate: float | None = None
    average_rmssd: float | None = None
    average_stress_score: float | None = None
    max_stress_score: float | None = None
    is_complete: bool


class SessionDetail(SessionSummary):
    events: list[dict] = []
