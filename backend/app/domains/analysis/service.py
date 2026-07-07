import json
from datetime import datetime

from fastapi import HTTPException

from ...services.hrv_calculator import (
    compute_heart_rate,
    compute_lf_hf_ratio,
    compute_rmssd,
    compute_rr_intervals,
    compute_sdnn,
    compute_stress_index,
)
from ...services.mat_loader import get_sample_rate, load_mat
from ...services.r_peak_detector import detect_r_peaks
from ...core.database import get_connection
from ..files.repository import load_uploaded_mat, save_uploaded_mat


def parse_and_store_mat(file_name: str, contents: bytes) -> dict:
    if not file_name.endswith(".mat"):
        raise HTTPException(status_code=400, detail="仅支持 .mat 文件格式")
    if not contents:
        raise HTTPException(status_code=400, detail="文件为空")

    try:
        mat_data = load_mat(contents)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f".mat 文件解析失败: {exc}") from exc

    if not mat_data:
        raise HTTPException(status_code=422, detail=".mat 文件中未找到有效数据变量")

    filtered_data = mat_data.get("stm32_filtered_data", [])
    raw_data = mat_data.get("raw_data", [])
    if not filtered_data:
        for value in mat_data.values():
            if isinstance(value, list) and len(value) > 100:
                filtered_data = value
                break
    if not filtered_data:
        raise HTTPException(status_code=422, detail="未找到 ECG 波形数据")

    return save_uploaded_mat(
        file_name=file_name,
        contents=contents,
        sample_rate=get_sample_rate(mat_data),
        filtered_data=filtered_data,
        raw_data=raw_data,
        mat_data=mat_data,
    )


def compute_hrv_for_file(file_id: str) -> dict:
    data = load_uploaded_mat(file_id)
    if data is None:
        raise HTTPException(status_code=404, detail="文件未找到或已过期")

    filtered_data = data["filtered_data"]
    sample_rate = int(data.get("sample_rate", 500) or 500)
    if len(filtered_data) < 100:
        raise HTTPException(status_code=422, detail="ECG 数据不足，至少需要 100 个采样点")

    r_peaks = [int(index) for index in detect_r_peaks(filtered_data, sample_rate)]
    if len(r_peaks) < 2:
        raise HTTPException(status_code=422, detail="无法检测到足够的 R 峰（至少需要 2 个）")

    rr_intervals = [float(value) for value in compute_rr_intervals(r_peaks, sample_rate)]
    heart_rate = float(compute_heart_rate(rr_intervals))
    sdnn = float(compute_sdnn(rr_intervals))
    rmssd = float(compute_rmssd(rr_intervals))
    lf_hf = float(compute_lf_hf_ratio(rr_intervals, sample_rate))
    stress = float(compute_stress_index(sdnn, rmssd, lf_hf))
    mean_rr = float(sum(rr_intervals) / len(rr_intervals)) if rr_intervals else 0.0

    result = {
        "file_id": file_id,
        "heart_rate": float(round(heart_rate, 1)),
        "sdnn_ms": float(round(sdnn, 1)),
        "rmssd_ms": float(round(rmssd, 1)),
        "lf_hf_ratio": float(round(lf_hf, 2)),
        "stress_index": float(stress),
        "r_peak_count": len(r_peaks),
        "r_peak_indices": r_peaks,
        "rr_intervals_ms": [float(round(r, 1)) for r in rr_intervals],
        "mean_rr_ms": float(round(mean_rr, 1)),
    }
    with get_connection() as conn:
        conn.execute(
            """
            INSERT OR REPLACE INTO analysis_results (
                file_id, heart_rate, sdnn_ms, rmssd_ms, lf_hf_ratio,
                stress_index, r_peak_count, r_peak_indices,
                rr_intervals_ms, mean_rr_ms, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                file_id,
                result["heart_rate"],
                result["sdnn_ms"],
                result["rmssd_ms"],
                result["lf_hf_ratio"],
                result["stress_index"],
                result["r_peak_count"],
                json.dumps(result["r_peak_indices"]),
                json.dumps(result["rr_intervals_ms"]),
                result["mean_rr_ms"],
                datetime.now().isoformat(),
            ),
        )
    return result


def load_hrv_result(file_id: str) -> dict | None:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT * FROM analysis_results WHERE file_id = ?", (file_id,)
        ).fetchone()
    if row is None:
        return None
    result = dict(row)
    result["r_peak_indices"] = json.loads(result["r_peak_indices"])
    result["rr_intervals_ms"] = json.loads(result["rr_intervals_ms"])
    return result
