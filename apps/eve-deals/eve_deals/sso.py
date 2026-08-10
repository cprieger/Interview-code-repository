"""EVE SSO (OAuth2) login, callback token exchange, and refresh."""

import base64
import json
import secrets
import time

import requests

from eve_deals import db
from eve_deals.config import (
    ESI_CALLBACK_URL,
    ESI_CLIENT_ID,
    ESI_CLIENT_SECRET,
    ESI_SCOPES,
    ESI_SSO_AUTHORIZE_URL,
    ESI_SSO_TOKEN_URL,
)


def build_authorize_url(state):
    params = {
        "response_type": "code",
        "redirect_uri": ESI_CALLBACK_URL,
        "client_id": ESI_CLIENT_ID,
        "scope": ESI_SCOPES,
        "state": state,
    }
    query = "&".join(f"{k}={requests.utils.quote(v)}" for k, v in params.items())
    return f"{ESI_SSO_AUTHORIZE_URL}?{query}"


def new_state():
    return secrets.token_urlsafe(24)


def _basic_auth_header():
    raw = f"{ESI_CLIENT_ID}:{ESI_CLIENT_SECRET}".encode("utf-8")
    return base64.b64encode(raw).decode("utf-8")


def _decode_character_from_access_token(access_token):
    """Decode (without verifying signature) the JWT payload to get character id/name.

    Safe here because the token was just received directly from EVE's own token
    endpoint over TLS in this same request — we are not trusting a token supplied
    by an untrusted third party.
    """
    payload_b64 = access_token.split(".")[1]
    padding = "=" * (-len(payload_b64) % 4)
    payload = json.loads(base64.urlsafe_b64decode(payload_b64 + padding))
    # sub claim looks like "CHARACTER:EVE:123456789"
    character_id = int(payload["sub"].split(":")[-1])
    character_name = payload.get("name", "Unknown")
    return character_id, character_name


def exchange_code_for_tokens(code):
    resp = requests.post(
        ESI_SSO_TOKEN_URL,
        headers={
            "Authorization": f"Basic {_basic_auth_header()}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={"grant_type": "authorization_code", "code": code},
        timeout=10,
    )
    resp.raise_for_status()
    data = resp.json()
    character_id, character_name = _decode_character_from_access_token(data["access_token"])
    db.save_tokens(
        character_id,
        character_name,
        data["access_token"],
        data["refresh_token"],
        data["expires_in"],
    )
    return character_id, character_name


def _refresh(refresh_token):
    resp = requests.post(
        ESI_SSO_TOKEN_URL,
        headers={
            "Authorization": f"Basic {_basic_auth_header()}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={"grant_type": "refresh_token", "refresh_token": refresh_token},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()


def get_valid_access_token():
    """Returns a valid access token, refreshing it first if it's expired/near-expiry."""
    tokens = db.get_tokens()
    if not tokens:
        return None

    if tokens["expires_at"] > time.time() + 30:
        return tokens["access_token"]

    data = _refresh(tokens["refresh_token"])
    db.save_tokens(
        tokens["character_id"],
        tokens["character_name"],
        data["access_token"],
        data.get("refresh_token", tokens["refresh_token"]),
        data["expires_in"],
    )
    return data["access_token"]
