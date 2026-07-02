# Mi Pueblo

Family location sharing app — know where your people are, in real time.

## Tech Stack

- **Backend:** Elixir / Phoenix (REST API + WebSockets)
- **Mobile:** Flutter (Android & iOS)
- **Database:** PostgreSQL 16 with PostGIS
- **Push Notifications:** Firebase Cloud Messaging (FCM)
- **Payments:** RevenueCat
- **Auth:** JWT + Google OAuth

## Project Structure

```
fence/          # Phoenix backend
  config/       # Environment configs (dev, test, prod, runtime)
  lib/
    fence/      # Domain logic (accounts, locations, geofences, groups)
    fence_web/  # Controllers, channels, router
  priv/repo/    # Ecto migrations
  docker-compose.yml       # Dev database (PostGIS)
  docker-compose.prod.yml  # Production stack

mobile/         # Flutter app
  lib/
    models/     # Data models
    providers/  # Riverpod state management
    screens/    # UI screens
    services/   # API client, location tracking
  l10n/         # Localizations (EN, ES)

Makefile        # Top-level check & setup commands
```

## Prerequisites

- Elixir ~> 1.15
- Flutter SDK ^3.11
- PostgreSQL 16 with PostGIS extension
- Docker (for local database)

## Getting Started

### Database

```sh
cd fence
docker compose up -d
```

This starts a PostGIS 16 container on port **5433**.

### Backend

```sh
cd fence
mix setup          # deps.get + ecto.create + ecto.migrate
mix phx.server     # starts on http://localhost:4000
```

### Mobile

```sh
cd mobile
flutter pub get
flutter run
```

## Environment Variables

The backend reads these at runtime (see `fence/config/runtime.exs`):

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | prod | Ecto connection string (`ecto://USER:PASS@HOST/DB`) |
| `SECRET_KEY_BASE` | prod | Phoenix secret — generate with `mix phx.gen.secret` |
| `JWT_SECRET` | prod | Token signing key — generate with `openssl rand -base64 64` |
| `PHX_HOST` | prod | Public hostname |
| `FCM_SERVICE_ACCOUNT_JSON` | optional | Firebase service account JSON for push notifications |
| `GOOGLE_OAUTH_CLIENT_IDS` | optional | Comma-separated Google OAuth client IDs |
| `REVENUECAT_API_KEY` | optional | RevenueCat API key |
| `REVENUECAT_WEBHOOK_SECRET` | optional | RevenueCat webhook auth secret |
| `INVITE_BASE_URL` | optional | Base URL for invite deep links |

For production, copy `fence/.env.production.example` to `fence/.env.production` and fill in the values.

## Testing

### Backend

```sh
cd fence
mix test                # run tests
mix precommit           # format + credo + sobelow + deps.audit + test
```

### Mobile

```sh
cd mobile
flutter test
flutter analyze
```

### Full Check (from repo root)

```sh
make check              # runs check-backend + check-mobile
```

## Deployment

Production uses Docker Compose (`fence/docker-compose.prod.yml`):

```sh
cd fence
docker compose -f docker-compose.prod.yml up -d
```

This runs the Phoenix app (port 4000) and PostGIS database behind a health check.

CI/CD is handled by GitHub Actions:

- **check-backend** — compile warnings, format, credo, sobelow, deps audit, tests
- **check-mobile** — flutter analyze + test
- **deploy-backend** — production deploy
- **build-and-distribute** — mobile build & distribution

## Key Features

- Real-time location sharing via WebSockets
- Geofence creation with enter/exit notifications
- Push notifications (FCM)
- Group management with invite links
- Google OAuth sign-in
- Multi-language support (English, Spanish)
- In-app subscriptions via RevenueCat
