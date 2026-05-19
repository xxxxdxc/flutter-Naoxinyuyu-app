"""HRV 计算路由"""

from fastapi import APIRouter, HTTPException
from ..models.schemas import HrvRequest, HrvResponse
from ..services.r_peak_detector import detect_r_peaks
from ..services.hrv_calculator import (
    compute_rr_intervals,
    compute_heart_rate,
    compute_sdnn,
    compute_rmssd,
    compute_lf_hf_ratio,
    compute_stress_index,
)
from .upload import get_cached_data

router = APIRouter()


@router.post("/api/hrv", response_model=HrvResponse)
async def compute_hrv(request: HrvRequest):
    """计算 HRV 指标

    从已上传的 ECG 数据中检测 R 峰，计算各项 HRV 时域和频域指标。
    """
    cached = get_cached_data(request.file_id)

    filtered_data = cached["filtered_data"]
    sample_rate = cached.get("sample_rate", 500)

    if len(filtered_data) < 100:
        raise HTTPException(status_code=422, detail="ECG 数据不足，至少需要 100 个采样点")

    # 检测 R 峰
    r_peaks = detect_r_peaks(filtered_data, sample_rate)

    if len(r_peaks) < 2:
        raise HTTPException(status_code=422, detail="无法检测到足够的 R 峰（至少需要 2 个）")

    # 计算 RR 间期
    rr_intervals = compute_rr_intervals(r_peaks, sample_rate)

    # 计算 HRV 指标
    heart_rate = compute_heart_rate(rr_intervals)
    sdnn = compute_sdnn(rr_intervals)
    rmssd = compute_rmssd(rr_intervals)
    lf_hf = compute_lf_hf_ratio(rr_intervals, sample_rate)
    stress = compute_stress_index(sdnn, rmssd, lf_hf)
    mean_rr = float(sum(rr_intervals) / len(rr_intervals)) if rr_intervals else 0.0

    # 缓存计算结果供分析报告使用
    cached["hrv_result"] = {
        "heart_rate": heart_rate,
        "sdnn_ms": sdnn,
        "rmssd_ms": rmssd,
        "lf_hf_ratio": lf_hf,
        "stress_index": stress,
        "r_peak_count": len(r_peaks),
        "r_peak_indices": r_peaks,
        "rr_intervals_ms": rr_intervals,
        "mean_rr_ms": mean_rr,
    }

    return HrvResponse(
        heart_rate=round(heart_rate, 1),
        sdnn_ms=round(sdnn, 1),
        rmssd_ms=round(rmssd, 1),
        lf_hf_ratio=round(lf_hf, 2),
        stress_index=stress,
        r_peak_count=len(r_peaks),
        r_peak_indices=r_peaks,
        rr_intervals_ms=[round(r, 1) for r in rr_intervals],
        mean_rr_ms=round(mean_rr, 1),
    )
