"""发送 .mat 数据到后端服务的工具

用法：
    python scripts/export_mat_to_json.py <文件路径>
    python scripts/export_mat_to_json.py <目录路径>  (批量处理)

示例：
    python scripts/export_mat_to_json.py send_xzc/live_result/Live_ECG_0505_1652.mat
"""

import json
import sys
import os
from pathlib import Path

# 添加 src 到路径以便导入（或独立使用）
try:
    import scipy.io
    import numpy as np
except ImportError:
    print("请安装依赖: pip install scipy numpy")
    sys.exit(1)


def mat_to_dict(file_path: str) -> dict:
    """将 .mat 文件转换为可序列化的字典"""
    mat = scipy.io.loadmat(file_path)
    result = {}

    for key, value in mat.items():
        if key.startswith('__') and key.endswith('__'):
            continue
        if hasattr(value, 'shape'):
            arr = value.flatten() if value.ndim == 2 else value
            if arr.dtype.kind in ('f', 'i', 'u'):
                result[key] = arr.tolist()

    return result


def process_file(file_path: str):
    """处理单个 .mat 文件"""
    path = Path(file_path)
    if not path.exists():
        print(f"文件不存在: {file_path}")
        return

    print(f"\n处理: {path.name}")
    data = mat_to_dict(str(path))

    filtered = data.get('stm32_filtered_data', [])
    raw = data.get('raw_data', [])

    print(f"  采样点数: {len(filtered)}")
    print(f"  时长: {len(filtered)/500:.1f} 秒 (500Hz)")
    print(f"  滤波数据范围: [{min(filtered):.4f}, {max(filtered):.4f}]" if filtered else "  ☑ 无滤波数据")
    print(f"  原始数据范围: [{min(raw):.4f}, {max(raw):.4f}]" if raw else "  ☑ 无原始数据")


def process_directory(dir_path: str):
    """批量处理目录中的 .mat 文件"""
    path = Path(dir_path)
    mat_files = list(path.glob("*.mat"))

    if not mat_files:
        print(f"目录中未找到 .mat 文件: {dir_path}")
        return

    print(f"找到 {len(mat_files)} 个 .mat 文件:\n")
    for f in mat_files:
        process_file(str(f))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python scripts/export_mat_to_json.py <文件或目录>")
        sys.exit(1)

    target = sys.argv[1]

    if os.path.isdir(target):
        process_directory(target)
    else:
        process_file(target)
