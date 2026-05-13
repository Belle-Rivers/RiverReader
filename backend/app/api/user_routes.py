from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Response, status

from app.db import SessionDep
from app.schemas import UserProfileCreate, UserProfileRead, UserProfileUpdate, UserLogin
from app.services import profile_service

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
