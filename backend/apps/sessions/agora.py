"""
Agora RTC token issuance.

Tokens are signed locally with the app certificate (no network call to
Agora is needed to mint one). Every client join in this app uses the
numeric wildcard uid 0 (see AgoraChannelController.join in the
frontend), so tokens must be signed with buildTokenWithUid(uid=0) to
match - buildTokenWithAccount signs for a string user account and
requires the client to join via the user-account API instead, which we
don't do. Signing account-based tokens for a uid-based join causes
Agora's edge to reject the connection silently (no local onError,
join just never completes). See ADR-002 for why listeners get an
audience-role, short-TTL token bound to a single channel; ADR-003 for
why interpreters get a separate publisher-role builder rather than a
shared function with a role flag. Q&A (raise hand / floor / speak) is
not implemented yet - see ADR-004 for the deferred design.
"""

import time

from agora_token_builder.RtcTokenBuilder import (
    Role_Publisher,
    Role_Subscriber,
    RtcTokenBuilder,
)
from django.conf import settings

# All clients join with this wildcard uid and let Agora assign the real
# one - see the module docstring for why the token must match.
_JOIN_UID = 0


def build_listener_token(channel_name: str) -> str:
    """Audience-role token: can subscribe, cannot publish."""
    expire_at = int(time.time()) + settings.AGORA_TOKEN_TTL_SECONDS
    return RtcTokenBuilder.buildTokenWithUid(
        settings.AGORA_APP_ID,
        settings.AGORA_APP_CERTIFICATE,
        channel_name,
        _JOIN_UID,
        Role_Subscriber,
        expire_at,
    )


def build_interpreter_token(channel_name: str) -> str:
    """Publisher-role token: can broadcast audio into the channel."""
    expire_at = int(time.time()) + settings.AGORA_TOKEN_TTL_SECONDS
    return RtcTokenBuilder.buildTokenWithUid(
        settings.AGORA_APP_ID,
        settings.AGORA_APP_CERTIFICATE,
        channel_name,
        _JOIN_UID,
        Role_Publisher,
        expire_at,
    )


def build_guide_broadcast_token(channel_name: str) -> str:
    """Publisher-role token for the Guide's own live mic into the
    session's source channel - this is what interpreters and any
    listener who picks "original audio" actually hear.

    Same role as build_interpreter_token - kept as a separate function
    (matching the build_floor_token precedent) so each caller's intent
    is obvious from the name it imports.
    """
    expire_at = int(time.time()) + settings.AGORA_TOKEN_TTL_SECONDS
    return RtcTokenBuilder.buildTokenWithUid(
        settings.AGORA_APP_ID,
        settings.AGORA_APP_CERTIFICATE,
        channel_name,
        _JOIN_UID,
        Role_Publisher,
        expire_at,
    )
