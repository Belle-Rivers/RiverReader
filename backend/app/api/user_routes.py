from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Response, status
from fastapi.responses import Response as FastAPIResponse

from app.db import SessionDep
from app.schemas import (
    ResetPasswordRequest,
    UserDataBackupRead,
    UserLogin,
    UserProfileCreate,
    UserProfileRead,
    UserProfileUpdate,
)
from app.services import backup_service, profile_service

user_router = APIRouter(prefix="/users", tags=["Users"])


@user_router.post(
    "/register",
    response_model=UserProfileRead,
    status_code=status.HTTP_201_CREATED,
    summary="Register a local user profile",
)
def register_user_profile(
    payload: UserProfileCreate,
    session: SessionDep,
) -> UserProfileRead:
    try:
        return profile_service.create_user_profile(session, payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@user_router.get(
    "/recovery-question/{email}",
    summary="Get the recovery question for a user email",
)
def get_recovery_question(email: str, session: SessionDep) -> dict:
    result = profile_service.get_security_question(session, email)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user not found")
    question, stored_email = result
    return {"email": stored_email, "security_question": question}


@user_router.post(
    "/login",
    response_model=UserProfileRead,
    summary="Login user",
)
def login_user(
    payload: UserLogin,
    session: SessionDep,
) -> UserProfileRead:
    profile = profile_service.verify_login(session, payload)
    if not profile:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    return profile


@user_router.post(
    "/forgot-password",
    summary="Reset a password using the security answer",
)
def forgot_password(
    payload: ResetPasswordRequest,
    session: SessionDep,
) -> UserProfileRead:
    profile = profile_service.reset_password_with_security_answer(
        session,
        payload.email,
        payload.security_answer,
        payload.new_password,
    )
    if profile is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or security answer")
    return profile


@user_router.get("", response_model=list[UserProfileRead], summary="List user profiles")
def list_user_profiles(
    session: SessionDep,
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> list[UserProfileRead]:
    return profile_service.list_user_profiles(session, limit=limit, offset=offset)


@user_router.get(
    "/by-email/{email}",
    response_model=UserProfileRead,
    summary="Get a user profile by email",
)
def get_user_profile_by_email(email: str, session: SessionDep) -> UserProfileRead:
    profile = profile_service.get_user_profile_by_email(session, email)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user not found")
    return profile


@user_router.get(
    "/{user_id}",
    response_model=UserProfileRead,
    summary="Get a user profile",
)
def get_user_profile(user_id: UUID, session: SessionDep) -> UserProfileRead:
    profile = profile_service.get_user_profile_by_id(session, user_id)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user not found")
    return profile


@user_router.patch(
    "/{user_id}",
    response_model=UserProfileRead,
    summary="Update a user profile",
)
def update_user_profile(
    user_id: UUID,
    payload: UserProfileUpdate,
    session: SessionDep,
) -> UserProfileRead:
    try:
        profile = profile_service.update_user_profile(session, user_id, payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user not found")
    return profile


@user_router.delete(
    "/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a user profile",
)
def delete_user_profile(user_id: UUID, session: SessionDep) -> Response:
    deleted = profile_service.delete_user_profile(session, user_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@user_router.get(
    "/{user_id}/export",
    response_model=UserDataBackupRead,
    summary="Export a user's full data package",
)
def export_user_data(user_id: UUID, session: SessionDep) -> UserDataBackupRead:
    payload = backup_service.export_user_backup(session, user_id)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user not found")
    return payload


@user_router.post(
    "/import",
    response_model=UserDataBackupRead,
    summary="Import a user's full data package",
)
def import_user_data(payload: UserDataBackupRead, session: SessionDep) -> UserDataBackupRead:
    return backup_service.import_user_backup(session, payload)


@user_router.post(
    "/{user_id}/backup",
    status_code=status.HTTP_200_OK,
    summary="Trigger server-side backup save",
)
def trigger_backup(user_id: UUID, session: SessionDep) -> dict:
    data_json = backup_service.save_user_backup(session, user_id)
    if data_json is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="user not found")
    return {"status": "ok", "size_bytes": len(data_json)}


@user_router.get(
    "/{user_id}/backup",
    summary="Download stored backup as JSON",
)
def download_backup(user_id: UUID, session: SessionDep) -> FastAPIResponse:
    data_json = backup_service.get_user_backup(session, user_id)
    if data_json is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="no backup found")
    return FastAPIResponse(
        content=data_json,
        media_type="application/json",
        headers={"Content-Disposition": f"attachment; filename=RiverReader_backup.json"},
    )
