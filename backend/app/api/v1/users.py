from fastapi import APIRouter

from ...domains.users.service import create_user, get_user, list_users
from .schemas import UserCreate, UserResponse

router = APIRouter(prefix="/users", tags=["users"])


@router.post("", response_model=UserResponse)
async def create_user_endpoint(request: UserCreate):
    return create_user(
        username=request.username,
        password=request.password,
        display_name=request.display_name,
        role=request.role,
    )


@router.get("", response_model=list[UserResponse])
async def list_users_endpoint():
    return list_users()


@router.get("/{user_id}", response_model=UserResponse)
async def get_user_endpoint(user_id: str):
    return get_user(user_id)
