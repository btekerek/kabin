# ADR-007: Frontend state management and routing

## Context

The Flutter app has had a networking/auth-storage layer since the auth
slice (`DioClientFactory`, `AuthSession`, `TokenStorage`) but no actual
screens, no state management library, and no routing library. Building
the first real screens (Guide login/register, session creation,
session dashboard) requires picking both before writing a single
widget, since retrofitting either one under a growing set of screens
is expensive.

## Decision

**Riverpod** (`flutter_riverpod`) for state management. The app's
shared state is inherently asynchronous - login status, session
status, and (in later slices) chat/Q&A updates arriving over a
WebSocket - and Riverpod's providers model "loading / data / error"
for exactly that shape without hand-rolled boilerplate. It also
doesn't depend on `BuildContext` to locate state (unlike `Provider`),
so a provider used from the wrong place fails at compile time instead
of at runtime.

**go_router** for routing. The app needs auth-gated redirects (bounce
back to `/login` if the access token is gone) and, in later slices,
deep links (open straight to a join screen from a shared code). Both
are go_router's reason for existing; plain `Navigator` would mean
hand-writing the auth check on every route push.

**Router rebuilds on auth state change.** `appRouterProvider` is a
plain `Provider<GoRouter>` that watches `authControllerProvider` and
recomputes its `redirect` callback from the current `AsyncValue<User?>`
(loading -> `/splash`, no user -> `/login`, logged-in user on an auth
route -> `/sessions`). Recreating the router on login/logout is a
coarse-grained, rare event, so the simplicity is worth it over wiring
a `GoRouterRefreshStream` bridge - revisit only if this ever causes a
visible navigation glitch.

**Project structure**: `lib/core/` stays cross-cutting infra (network,
auth-session, router); each vertical slice gets its own
`lib/features/<name>/` with `data/` (repository - raw Dio calls),
`domain/` (plain Dart models), `state/` (Riverpod providers), and
`presentation/` (screens/widgets). This mirrors the backend's
per-app structure (`apps/sessions/`, `apps/accounts/`) so the same
mental model applies on both sides of the codebase.

**Auth state lives in one `AsyncNotifier<User?>`**
(`authControllerProvider`), not a boolean "logged in" flag. `null`
means logged out; a `User` means logged in with that account's `id`/
`email`/`role` already loaded (fetched via `/api/auth/me/` right after
login or on app start if a refresh token is already stored). Screens
that need to know the current role (e.g. gating Guide-only screens)
read this one provider rather than re-fetching `/me` themselves.

**Role gating happens in the router, not per-screen.** Only Guide
screens exist so far (Interpreter and Listener flows are later
slices). If a logged-in user's role isn't `guide`, the router sends
them to a plain "not supported yet" screen instead of into
Guide-specific screens that would just 403 against the backend anyway.

## Alternatives considered

- **Provider + plain `Navigator`.** Rejected per the tradeoffs above -
  weaker on async state and auth-gated redirects, the two things this
  app needs most.
- **`flutter_bloc`.** Rejected as more ceremony than a solo-dev project
  needs per screen; revisit only if a specific flow's state genuinely
  outgrows Riverpod's shape (unlikely at this app's scale).
- **`GoRouterRefreshStream` from day one.** More correct in the
  abstract (routes recompute the instant auth state changes rather
  than requiring a `Provider<GoRouter>` rebuild), but auth state
  changes are infrequent enough that this would be complexity paid for
  upfront with no visible benefit yet.

## Consequences

- Every future feature slice (Interpreter join, Q&A, chat) follows the
  same `data/domain/state/presentation` shape already established
  here, rather than each slice inventing its own structure.
- `authControllerProvider` becomes the one place that has to handle
  `AuthSession.onLoggedOut` (fired when a token refresh fails deep
  inside `DioClientFactory`) - it subscribes to that stream and clears
  its own state, which is what causes the router to redirect to
  `/login` automatically without any screen needing to know a refresh
  failed.
- No code-gen (no `freezed`, no `json_serializable`) - models are
  plain Dart classes with a hand-written `fromJson`. Fine at this
  app's current size; worth revisiting only if models grow enough
  that hand-written parsing becomes the tedious part.
