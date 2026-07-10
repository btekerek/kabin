"""
Django Channels consumers. Empty until the first real-time feature
(session status / queue / floor / co-interpreter mic indicators) is
built. Every consumer added here must authorize on every action —
channel membership for interpreter-scoped actions, ownership for
guide-only actions — and must push a full state snapshot on connect and
on an explicit client "sync" request (clients reconnect mid-session and
must never trust stale local state).
"""
