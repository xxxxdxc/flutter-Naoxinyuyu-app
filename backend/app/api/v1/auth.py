from fastapi import APIRouter

from ...domains.users.service import login_user
from .schemas import LoginRequest, UserResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=UserResponse)
async def login_endpoint(request: LoginRequest):
    return login_user(username=request.username, password=request.password)
