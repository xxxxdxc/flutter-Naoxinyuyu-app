"""文件上传与 .mat 解析路由"""

import uuid
import tempfile
import os
from pathlib import Path
from fastapi import APIRouter, UploadFile, File, HTTPException
from ..services.mat_loader import load_mat, get_sample_rate
from ..models.schemas import UploadResponse

router = APIRouter()

# 内存缓存: file_id -> mat_data
_upload_cache: dict[str, dict] = {}

# 临时文件目录
TEMP_DIR = Path(tempfile.gettempdir()) / "naoxinyuyu"
TEMP_DIR.mkdir(exist_ok=True)


@router.post("/api/upload", response_model=UploadResponse)
async def upload_mat_file(file: UploadFile = File(...)):
    """上传并解析 .mat 文件

    接收 .mat 文件，提取 raw_data 和 stm32_filtered_data，
    返回解析后的 ECG 数据。
    """
    if not file.filename or not file.filename.endswith('.mat'):
        raise HTTPException(status_code=400, detail="仅支持 .mat 文件格式")

    # 读取文件内容
    contents = await file.read()

    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="文件为空")

    # 解析 .mat 文件
    try:
        mat_data = load_mat(contents)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f".mat 文件解析失败: {str(e)}")

    if not mat_data:
        raise HTTPException(status_code=422, detail=".mat 文件中未找到有效数据变量")

    # 提取关键变量
    filtered_data = mat_data.get('stm32_filtered_data', [])
    raw_data = mat_data.get('raw_data', [])

    if not filtered_data:
        # 如果标准键不存在，使用第一个可用数值数组
        for key, val in mat_data.items():
            if isinstance(val, list) and len(val) > 100:
                filtered_data = val
                break

    if not filtered_data:
        raise HTTPException(status_code=422, detail="未找到 ECG 波形数据")

    file_id = str(uuid.uuid4())
    sample_rate = get_sample_rate(mat_data)

    # 缓存解析结果
    _upload_cache[file_id] = {
        "file_name": file.filename,
        "sample_rate": sample_rate,
        "num_samples": len(filtered_data),
        "duration_sec": len(filtered_data) / sample_rate,
        "filtered_data": filtered_data,
        "raw_data": raw_data,
        "mat_data": mat_data,  # 保留完整数据供后续 HRV 分析
    }

    return UploadResponse(
        file_id=file_id,
        file_name=file.filename,
        sample_rate=sample_rate,
        num_samples=len(filtered_data),
        duration_sec=len(filtered_data) / sample_rate,
        filtered_data=filtered_data[:5000],  # 前端展示最多 5000 点
        raw_data=raw_data[:5000],
    )


def get_cached_data(file_id: str) -> dict:
    """获取缓存的上传数据"""
    data = _upload_cache.get(file_id)
    if data is None:
        raise HTTPException(status_code=404, detail="文件未找到或已过期")
    return data
