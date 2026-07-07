from fastapi import APIRouter, File, UploadFile

from ...domains.analysis.service import compute_hrv_for_file, parse_and_store_mat
from ...domains.reports.service import generate_report_for_file
from .schemas import AnalyzeResponse, FileRequest, HrvResponse, UploadResponse

router = APIRouter(tags=["analysis"])


@router.post("/files/mat", response_model=UploadResponse)
async def upload_mat_file(file: UploadFile = File(...)):
    record = parse_and_store_mat(file.filename or "upload.mat", await file.read())
    return UploadResponse(
        file_id=record["id"],
        file_name=record["file_name"],
        sample_rate=record["sample_rate"],
        num_samples=record["num_samples"],
        duration_sec=record["duration_sec"],
        filtered_data=record["filtered_data"][:5000],
        raw_data=record["raw_data"][:5000],
    )


@router.post("/analysis/hrv", response_model=HrvResponse)
async def compute_hrv_endpoint(request: FileRequest):
    return compute_hrv_for_file(request.file_id)


@router.post("/analysis/report", response_model=AnalyzeResponse)
async def generate_report_endpoint(request: FileRequest):
    return generate_report_for_file(request.file_id)
