"""R 峰检测服务

基于自适应阈值的 QRS 波群检测算法，参考 DataReplayService 的 Dart 实现。
"""

import numpy as np
from scipy import signal


def detect_r_peaks(
    ecg_signal: list[float],
    sample_rate: int = 500,
    refractory_period_ms: int = 200,
) -> list[int]:
    """检测 ECG 信号中的 R 峰位置

    Args:
        ecg_signal: ECG 信号数据
        sample_rate: 采样率 (Hz)
        refractory_period_ms: 不应期 (ms)，防误检

    Returns:
        list[int]: R 峰在信号中的索引位置
    """
    signal_arr = np.array(ecg_signal, dtype=np.float64)

    if len(signal_arr) == 0:
        return []

    # 1. 带通滤波 5-15Hz 增强 QRS 波群
    sos = signal.butter(4, [5, 15], btype='band', fs=sample_rate, output='sos')
    filtered = signal.sosfilt(sos, signal_arr)

    # 2. 取绝对值增强 R 峰特征
    abs_signal = np.abs(filtered)

    # 3. 自适应阈值：滑动窗口均值 * 系数
    window_size = sample_rate // 2  # 0.5 秒窗口
    if len(abs_signal) < window_size:
        window_size = len(abs_signal)

    # 计算初始阈值
    initial_threshold = np.mean(abs_signal) * 1.5

    refractory_samples = int(refractory_period_ms * sample_rate / 1000)

    r_peaks = []
    last_peak_idx = -refractory_samples

    # 滑动窗口迭代检测
    i = 0
    while i < len(abs_signal):
        # 更新动态阈值
        start = max(0, i - window_size)
        end = min(len(abs_signal), i + window_size)
        window_vals = abs_signal[start:end]
        threshold = np.mean(window_vals) * 2.0

        if threshold < initial_threshold * 0.3:
            threshold = initial_threshold * 0.3

        # 寻找局部最大值
        search_end = min(i + refractory_samples, len(abs_signal))
        segment = abs_signal[i:search_end]

        if len(segment) == 0:
            break

        max_idx_in_seg = np.argmax(segment)
        max_val = segment[max_idx_in_seg]

        if max_val > threshold and (i + max_idx_in_seg - last_peak_idx) >= refractory_samples:
            # 找到候选 R 峰后，在原始信号中以 ±20ms 范围确认精确位置
            candidate_idx = i + max_idx_in_seg
            refine_window = max(10, int(0.02 * sample_rate))
            local_start = max(0, candidate_idx - refine_window)
            local_end = min(len(signal_arr), candidate_idx + refine_window)
            local_segment = signal_arr[local_start:local_end]

            if len(local_segment) > 0:
                # 在原始信号中找最大值
                if np.max(np.abs(local_segment)) > 0:
                    # 使用添加绝对值后的信号确认精确位置
                    refined_idx = local_start + int(np.argmax(np.abs(local_segment)))
                else:
                    refined_idx = candidate_idx

                r_peaks.append(refined_idx)
                last_peak_idx = refined_idx
                i = refined_idx + refractory_samples
            else:
                i += refractory_samples
        else:
            i += max(1, refractory_samples // 4)

    return r_peaks
