from fastapi import APIRouter

from . import analysis, auth, health, reports, sessions, users

router = APIRouter(prefix="/api/v1")
router.include_router(health.router)
router.include_router(auth.router)
router.include_router(users.router)
router.include_router(analysis.router)
router.include_router(sessions.router)
router.include_router(reports.router)
