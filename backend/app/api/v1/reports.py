from fastapi import APIRouter

from ...domains.reports.service import get_report
from .schemas import AnalyzeResponse

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/{report_id}", response_model=AnalyzeResponse)
async def get_report_endpoint(report_id: str):
    return get_report(report_id)
