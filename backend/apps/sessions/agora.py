"""
Agora RTC token issuance.

Tokens are signed locally with the app certificate (no network call to
Agora is needed to mint one). See ADR-002 for why listeners get an
audience-role, account-identified, short-TTL token bound to a single
channel; ADR-003 for why interpreters get a separate publisher-role
builder rather than a shared function with a role flag; and ADR-004 for
why a listener granted the Q&A floor gets its own publisher-role
builder too, bound to the source channel rather than whatever channel
they were listening to.
"""

import time

from agora_token_builder.RtcTokenBuilder import (
    Role_Publisher,
    Role_Subscriber,
    RtcTokenBuilder,
)
from django.conf import settings


def build_listener_token(channel_name: str, listener_uuid: str) -> str:
    """Audience-role token: can subscribe, cannot publish."""
    expire_at = int(time.time()) + settings.AGORA_TOKEN_TTL_SECONDS
    return RtcTokenBuilder.buildTokenWithAccount(
        settings.AGORA_APP_ID,
        settings.AGORA_APP_CERTIFICATE,
        channel_name,
        listener_uuid,
        Role_Subscriber,
        expire_at,
    )


def build_interpreter_token(channel_name: str, interpreter_account: str) -> str:
    """Publisher-role token: can broadcast audio into the channel."""
    expire_at = int(time.time()) + settings.AGORA_TOKEN_TTL_SECONDS
    return RtcTokenBuilder.buildTokenWithAccount(
        settings.AGORA_APP_ID,
        settings.AGORA_APP_CERTIFICATE,
        channel_name,
        interpreter_account,
        Role_Publisher,
        expire_at,
    )


def build_floor_token(channel_name: str, listener_uuid: str) -> str:
    """Publisher-role token for a listener granted the Q&A floor.

    Same role as build_interpreter_token - kept as a separate function
    (see ADR-004) so each caller's intent is obvious from the name it
    imports, not from a role argument it has to pass correctly.
    """
    expire_at = int(time.time()) + settings.AGORA_TOKEN_TTL_SECONDS
    return RtcTokenBuilder.buildTokenWithAccount(
        settings.AGORA_APP_ID,
        settings.AGORA_APP_CERTIFICATE,
        channel_name,
        listener_uuid,
        Role_Publisher,
        expire_at,
    )
