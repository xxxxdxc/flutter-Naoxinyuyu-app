from fastapi import APIRouter

from ...domains.sessions.service import (
    add_session_event,
    create_session,
    finish_session,
    get_session,
    list_sessions_for_user,
)
from .schemas import (
    SessionCreate,
    SessionDetail,
    SessionEventCreate,
    SessionFinishRequest,
    SessionSummary,
)

router = APIRouter(tags=["sessions"])


@router.post("/sessions", response_model=SessionSummary)
async def create_session_endpoint(request: SessionCreate):
    return create_session(**request.dict())


@router.post("/sessions/{session_id}/events")
async def add_session_event_endpoint(session_id: str, request: SessionEventCreate):
    return add_session_event(session_id, request.event_type, request.payload)


@router.patch("/sessions/{session_id}/finish", response_model=SessionSummary)
async def finish_session_endpoint(session_id: str, request: SessionFinishRequest):
    return finish_session(session_id, request.dict())


@router.get("/users/{user_id}/sessions", response_model=list[SessionSummary])
async def list_sessions_endpoint(user_id: str):
    return list_sessions_for_user(user_id)


@router.get("/sessions/{session_id}", response_model=SessionDetail)
async def get_session_endpoint(session_id: str):
    return get_session(session_id)
