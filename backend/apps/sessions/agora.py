"""
Agora RTC token issuance.

Tokens are signed locally with the app certificate (no network call to
Agora is needed to mint one). See ADR-002 for why listeners get an
audience-role, account-identified, short-TTL token bound to a single
channel.
"""

import time

from agora_token_builder.RtcTokenBuilder import Role_Subscriber, RtcTokenBuilder
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
