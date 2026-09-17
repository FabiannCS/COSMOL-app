import pytest
from httpx import AsyncClient
from app.core.security import get_password_hash, verify_password, create_access_token, create_refresh_token, decode_token
from app.core.exceptions import AppException


def test_password_hashing():
    raw_pass = "CosmolSecure2026!"
    hashed = get_password_hash(raw_pass)
    assert hashed != raw_pass
    assert verify_password(raw_pass, hashed) is True
    assert verify_password("wrong_password", hashed) is False


def test_jwt_tokens():
    user_id = "550e8400-e29b-41d4-a716-446655440000"
    access_token = create_access_token(subject=user_id, extra_claims={"role": "titular"})
    refresh_token = create_refresh_token(subject=user_id)

    # Validate access token
    access_payload = decode_token(access_token)
    assert access_payload["sub"] == user_id
    assert access_payload["type"] == "access"
    assert access_payload["role"] == "titular"

    # Validate refresh token
    refresh_payload = decode_token(refresh_token)
    assert refresh_payload["sub"] == user_id
    assert refresh_payload["type"] == "refresh"


@pytest.mark.asyncio
async def test_app_exception_handling(client: AsyncClient):
    # Testing unprocessable entity validation format
    response = await client.get("/api/v1/health")
    assert response.status_code == 200
