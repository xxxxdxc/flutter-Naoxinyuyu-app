import json
import uuid
from datetime import datetime

from fastapi import HTTPException

from ...core.database import get_connection
from ..analysis.service import compute_hrv_for_file, load_hrv_result


def score_health(hrv_result: dict) -> float:
    stress = hrv_result.get("stress_index", 50)
    sdnn = hrv_result.get("sdnn_ms", 50)
    rmssd = hrv_result.get("rmssd_ms", 50)
    lf_hf = hrv_result.get("lf_hf_ratio", 1.0)
    stress_score = max(0, 100 - stress)
    sdnn_score = min(100, sdnn * 1.5)
    rmssd_score = min(100, rmssd * 2.0)
    lfhf_score = 100 - min(100, abs(lf_hf - 1.0) * 50)
    score = stress_score * 0.3 + sdnn_score * 0.25 + rmssd_score * 0.25 + lfhf_score * 0.2
    return round(min(100, max(0, score)), 1)


def generate_interpretation(hrv_result: dict, health_score: float) -> dict:
    heart_rate = hrv_result.get("heart_rate", 0)
    sdnn = hrv_result.get("sdnn_ms", 0)
    rmssd = hrv_result.get("rmssd_ms", 0)
    lf_hf = hrv_result.get("lf_hf_ratio", 1.0)
    stress = hrv_result.get("stress_index", 50)
    findings: list[str] = []
    recommendations: list[str] = []

    if 60 <= heart_rate <= 100:
        findings.append(f"心率 {heart_rate:.0f} BPM 处于正常静息范围")
    elif heart_rate < 60:
        findings.append(f"心率 {heart_rate:.0f} BPM 偏缓，可结合个体状态继续观察")
    else:
        findings.append(f"心率 {heart_rate:.0f} BPM 偏快，可能处于应激或疲劳状态")

    if sdnn > 50:
        findings.append(f"SDNN {sdnn:.1f}ms 表明自主神经调节能力较好")
        recommendations.append("维持当前作息和压力管理方式")
    elif sdnn > 30:
        findings.append(f"SDNN {sdnn:.1f}ms 处于中等水平")
        recommendations.append("建议保持规律作息，适当增加放松训练")
    else:
        findings.append(f"SDNN {sdnn:.1f}ms 偏低，提示压力或疲劳风险需要关注")
        recommendations.append("建议关注睡眠质量，必要时寻求专业指导")

    if rmssd > 30:
        findings.append(f"RMSSD {rmssd:.1f}ms 表明副交感神经活性较好")
    else:
        findings.append(f"RMSSD {rmssd:.1f}ms 偏低，副交感神经活性可能减弱")

    if 0.5 <= lf_hf <= 2.0:
        findings.append(f"LF/HF 比值 {lf_hf:.2f} 处于相对平衡范围")
    elif lf_hf > 2.0:
        findings.append(f"LF/HF 比值 {lf_hf:.2f} 偏高，交感神经相对占优")
        recommendations.append("建议进行深呼吸、冥想等放松训练")
    else:
        findings.append(f"LF/HF 比值 {lf_hf:.2f} 偏低，可继续结合趋势观察")

    if stress >= 60:
        recommendations.append("建议增加休息时间，并持续观察压力趋势")

    if health_score >= 80:
        summary = f"整体健康评估状态良好，评分 {health_score:.0f} 分。"
    elif health_score >= 60:
        summary = f"整体健康评估状态中等，评分 {health_score:.0f} 分，部分指标需要关注。"
    else:
        summary = f"整体健康评估状态需要关注，评分 {health_score:.0f} 分。"

    if not recommendations:
        recommendations = ["继续保持健康的生活方式，并关注后续趋势变化"]

    return {
        "summary": summary,
        "findings": findings[:4],
        "recommendations": recommendations[:3],
    }


def generate_report_for_file(file_id: str) -> dict:
    hrv_result = load_hrv_result(file_id) or compute_hrv_for_file(file_id)
    health_score = score_health(hrv_result)
    interpretation = generate_interpretation(hrv_result, health_score)
    report_id = str(uuid.uuid4())
    report = {
        "report_id": report_id,
        "file_id": file_id,
        "health_score": health_score,
        "avg_heart_rate": round(hrv_result.get("heart_rate", 0), 1),
        "hrv_stress_index": hrv_result.get("stress_index", 0),
        "interpretation": interpretation,
        "created_at": datetime.now().isoformat(),
    }
    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO reports (
                id, file_id, session_id, health_score, avg_heart_rate,
                hrv_stress_index, summary, findings, recommendations, created_at
            ) VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                report["report_id"],
                file_id,
                report["health_score"],
                report["avg_heart_rate"],
                report["hrv_stress_index"],
                interpretation["summary"],
                json.dumps(interpretation["findings"], ensure_ascii=False),
                json.dumps(interpretation["recommendations"], ensure_ascii=False),
                report["created_at"],
            ),
        )
    return report


def get_report(report_id: str) -> dict:
    with get_connection() as conn:
        row = conn.execute("SELECT * FROM reports WHERE id = ?", (report_id,)).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="报告不存在")
    return {
        "report_id": row["id"],
        "file_id": row["file_id"],
        "session_id": row["session_id"],
        "health_score": row["health_score"],
        "avg_heart_rate": row["avg_heart_rate"],
        "hrv_stress_index": row["hrv_stress_index"],
        "interpretation": {
            "summary": row["summary"],
            "findings": json.loads(row["findings"]),
            "recommendations": json.loads(row["recommendations"]),
        },
        "created_at": row["created_at"],
    }
