"""HRV 指标计算服务

从 R 峰位置计算各项 HRV 时域和频域指标。
"""

import numpy as np
from scipy import signal, interpolate


def compute_rr_intervals(r_peak_indices: list[int], sample_rate: int = 500) -> list[float]:
    """计算 RR 间期（毫秒）

    Args:
        r_peak_indices: R 峰索引位置列表
        sample_rate: 采样率 (Hz)

    Returns:
        list[float]: RR 间期列表 (ms)
    """
    if len(r_peak_indices) < 2:
        return []

    intervals = []
    for i in range(1, len(r_peak_indices)):
        rr_samples = r_peak_indices[i] - r_peak_indices[i - 1]
        rr_ms = rr_samples / sample_rate * 1000.0
        intervals.append(rr_ms)

    return intervals


def compute_heart_rate(rr_intervals_ms: list[float]) -> float:
    """计算平均心率 (BPM)

    Args:
        rr_intervals_ms: RR 间期列表 (ms)

    Returns:
        float: 平均心率 (BPM)
    """
    if not rr_intervals_ms:
        return 0.0

    mean_rr = np.mean(rr_intervals_ms)
    if mean_rr <= 0:
        return 0.0

    return 60000.0 / mean_rr


def compute_sdnn(rr_intervals_ms: list[float]) -> float:
    """计算 SDNN — 全部 RR 间期的标准差 (ms)"""
    if len(rr_intervals_ms) < 2:
        return 0.0
    return float(np.std(rr_intervals_ms, ddof=1))


def compute_rmssd(rr_intervals_ms: list[float]) -> float:
    """计算 RMSSD — 相邻 RR 差值的均方根 (ms)"""
    if len(rr_intervals_ms) < 2:
        return 0.0

    diffs = np.diff(rr_intervals_ms)
    squared = diffs ** 2
    return float(np.sqrt(np.mean(squared)))


def compute_lf_hf_ratio(
    rr_intervals_ms: list[float],
    sample_rate: int = 500,
) -> float:
    """计算 LF/HF 比值

    使用 Lomb-Scargle 周期图法处理非均匀采样的 RR 间期数据。

    Args:
        rr_intervals_ms: RR 间期列表 (ms)
        sample_rate: ECG 采样率 (Hz)

    Returns:
        float: LF/HF 比值
    """
    if len(rr_intervals_ms) < 5:
        return 1.0

    # 准备 RR 间期的时间序列（累积和）
    rr_times = np.cumsum(rr_intervals_ms) / 1000.0  # 转换为秒

    if len(rr_times) < 4:
        return 1.0

    # 去除均值
    rr_values = np.array(rr_intervals_ms) - np.mean(rr_intervals_ms)

    # 使用 Lomb-Scargle 周期图
    freqs = np.linspace(0.003, 0.5, 500)  # 0.003-0.5 Hz

    # 计算功率谱
    from scipy.signal import lombscargle
    pgram = lombscargle(rr_times, rr_values, freqs)

    # 归一化功率
    pgram = pgram / np.max(pgram) if np.max(pgram) > 0 else pgram

    # 划分频带
    lf_band = (freqs >= 0.04) & (freqs <= 0.15)
    hf_band = (freqs >= 0.15) & (freqs <= 0.4)

    lf_power = np.trapezoid(pgram[lf_band], freqs[lf_band]) if np.any(lf_band) else 0
    hf_power = np.trapezoid(pgram[hf_band], freqs[hf_band]) if np.any(hf_band) else 0

    if hf_power <= 0:
        return 1.0

    return float(lf_power / hf_power)


def compute_stress_index(
    sdnn_ms: float,
    rmssd_ms: float,
    lf_hf_ratio: float,
) -> float:
    """计算压力指数 (0-100)

    基于 HRV 多项指标综合评估压力水平。

    Args:
        sdnn_ms: SDNN (ms)
        rmssd_ms: RMSSD (ms)
        lf_hf_ratio: LF/HF 比值

    Returns:
        float: 压力指数 (0-100)，越高压力越大
    """
    # SDNN 评分 (SDNN < 50ms → 高压力)
    sdnn_score = max(0, min(100, (100 - sdnn_ms * 1.5)))

    # RMSSD 评分 (RMSSD < 30ms → 高压力)
    rmssd_score = max(0, min(100, (100 - rmssd_ms * 2.0)))

    # LF/HF 评分 (LF/HF > 2.0 → 交感主导 → 高压力)
    lfhf_score = max(0, min(100, (lf_hf_ratio - 0.5) / 3.0 * 100))

    stress = sdnn_score * 0.3 + rmssd_score * 0.3 + lfhf_score * 0.4
    return round(min(100, max(0, stress)), 1)
