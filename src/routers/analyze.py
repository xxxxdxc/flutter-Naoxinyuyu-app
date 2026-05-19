"""分析报告生成路由"""

from fastapi import APIRouter, HTTPException
from ..models.schemas import AnalyzeRequest, AnalyzeResponse, Interpretation
from .upload import get_cached_data

router = APIRouter()


def _score_health(hrv_result: dict) -> float:
    """根据 HRV 指标计算健康评分 (0-100)"""
    stress = hrv_result.get("stress_index", 50)
    sdnn = hrv_result.get("sdnn_ms", 50)
    rmssd = hrv_result.get("rmssd_ms", 50)
    lf_hf = hrv_result.get("lf_hf_ratio", 1.0)

    # 压力指数反向评分（低压力 = 高健康分）
    stress_score = max(0, 100 - stress)

    # SDNN 评分（SDNN > 50ms 表示自主神经调节良好）
    sdnn_score = min(100, sdnn * 1.5)

    # RMSSD 评分（RMSSD > 30ms 表示迷走神经调节良好）
    rmssd_score = min(100, rmssd * 2.0)

    # LF/HF 评分（0.5-2.0 为平衡范围）
    lfhf_score = 100 - min(100, abs(lf_hf - 1.0) * 50)

    score = stress_score * 0.3 + sdnn_score * 0.25 + rmssd_score * 0.25 + lfhf_score * 0.2
    return round(min(100, max(0, score)), 1)


def _generate_interpretation(hrv_result: dict, health_score: float) -> Interpretation:
    """根据 HRV 指标生成 AI 解读文本"""
    heart_rate = hrv_result.get("heart_rate", 0)
    sdnn = hrv_result.get("sdnn_ms", 0)
    rmssd = hrv_result.get("rmssd_ms", 0)
    lf_hf = hrv_result.get("lf_hf_ratio", 1.0)
    stress = hrv_result.get("stress_index", 50)

    findings = []
    recommendations = []

    # 心率分析
    if 60 <= heart_rate <= 100:
        findings.append(f"心率 {heart_rate:.0f} BPM 处于正常静息范围")
    elif heart_rate < 60:
        findings.append(f"心率 {heart_rate:.0f} BPM 偏缓，可能与迷走神经张力较高有关")
    else:
        findings.append(f"心率 {heart_rate:.0f} BPM 偏快，可能处于应激或疲劳状态")

    # SDNN 分析
    if sdnn > 50:
        findings.append(f"SDNN {sdnn:.1f}ms 表明自主神经系统调节能力良好")
        recommendations.append("维持当前作息和压力管理方式")
    elif sdnn > 30:
        findings.append(f"SDNN {sdnn:.1f}ms 处于中等水平，自主神经调节能力尚可")
        recommendations.append("建议保持规律作息，适当增加有氧运动")
    else:
        findings.append(f"SDNN {sdnn:.1f}ms 偏低，提示自主神经调节功能可能减弱")
        recommendations.append("建议关注睡眠质量，减少咖啡因摄入，必要时就医评估")

    # RMSSD 分析
    if rmssd > 30:
        findings.append(f"RMSSD {rmssd:.1f}ms 表明副交感神经（迷走神经）活性良好")
    else:
        findings.append(f"RMSSD {rmssd:.1f}ms 偏低，副交感神经活性可能减弱")

    # LF/HF 分析
    if 0.5 <= lf_hf <= 2.0:
        findings.append(f"LF/HF 比值 {lf_hf:.2f} 处于平衡范围，交感与副交感神经功能协调")
    elif lf_hf > 2.0:
        findings.append(f"LF/HF 比值 {lf_hf:.2f} 偏高，交感神经相对占优势")
        recommendations.append("建议进行深呼吸、冥想等放松训练")
    else:
        findings.append(f"LF/HF 比值 {lf_hf:.2f} 偏低，副交感神经相对占优势")

    # 压力水平
    if stress < 30:
        findings.append(f"综合压力指数 {stress:.0f}，处于较低水平")
    elif stress < 60:
        findings.append(f"综合压力指数 {stress:.0f}，处于中等水平")
        if "建议" not in str(recommendations):
            recommendations.append("可考虑适当放松和休息")
    else:
        findings.append(f"综合压力指数 {stress:.0f}，偏高")
        recommendations.append("建议增加休息时间，必要时寻求专业指导")

    # 综合建议
    if health_score >= 80:
        summary = f"总体健康状态良好，评分 {health_score:.0f} 分。自主神经功能平衡，心血管调节能力正常。"
    elif health_score >= 60:
        summary = f"总体健康状态中等，评分 {health_score:.0f} 分。部分指标提示需关注自主神经调节状态。"
    else:
        summary = f"总体健康状态需关注，评分 {health_score:.0f} 分。建议持续监测并在必要时就医。"

    if not recommendations:
        recommendations = ["继续保持健康的生活方式"]

    return Interpretation(
        summary=summary,
        findings=findings[:4],
        recommendations=recommendations[:3],
    )


@router.post("/api/analyze", response_model=AnalyzeResponse)
async def generate_analysis(request: AnalyzeRequest):
    """生成健康分析报告

    基于已计算的 HRV 指标生成健康评分和 AI 解读。
    需先调用 POST /api/hrv 计算指标。
    """
    cached = get_cached_data(request.file_id)

    hrv_result = cached.get("hrv_result")
    if hrv_result is None:
        raise HTTPException(
            status_code=400,
            detail="请先调用 POST /api/hrv 计算 HRV 指标",
        )

    health_score = _score_health(hrv_result)
    interpretation = _generate_interpretation(hrv_result, health_score)

    return AnalyzeResponse(
        health_score=health_score,
        avg_heart_rate=round(hrv_result.get("heart_rate", 0), 1),
        hrv_stress_index=hrv_result.get("stress_index", 0),
        interpretation=interpretation,
    )
