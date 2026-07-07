from fastapi import APIRouter

from .schemas import HealthResponse

router = APIRouter(prefix="/health", tags=["health"])


@router.get("", response_model=HealthResponse)
async def health_check():
    return HealthResponse(status="ok", version="1.0.0")
