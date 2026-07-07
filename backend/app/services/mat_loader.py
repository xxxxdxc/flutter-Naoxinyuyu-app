"""MATLAB .mat 文件加载服务"""

import io
import scipy.io


def load_mat(file_bytes: bytes) -> dict[str, list[float]]:
    """加载 .mat 文件，提取所有数值变量

    Args:
        file_bytes: .mat 文件的完整字节内容

    Returns:
        dict[str, list[float]]: 变量名 -> 数据列表
    """
    mat = scipy.io.loadmat(io.BytesIO(file_bytes))
    result = {}

    for key, value in mat.items():
        # 跳过 MATLAB 内置元数据键
        if key.startswith('__') and key.endswith('__'):
            continue

        # 仅提取一维数值数组
        if hasattr(value, 'shape') and value.ndim <= 2:
            arr = value.flatten() if value.ndim == 2 else value
            if arr.dtype.kind in ('f', 'i', 'u'):
                result[key] = arr.tolist()

    return result


def get_sample_rate(mat_data: dict[str, list[float]]) -> int:
    """从 .mat 数据中推断采样率（默认 500Hz）"""
    # 检查是否存在 'fs' 变量
    if 'fs' in mat_data:
        return int(mat_data['fs'][0]) if isinstance(mat_data['fs'], list) else int(mat_data['fs'])
    return 500  # 硬件固定 500Hz
