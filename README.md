<div align="center">

# IQRA — Library Registration App

Offline-first admin app for library/student subscriptions with modern, responsive UI, biometric/passcode auth, robust local database (Drift), and production-ready UX (friendly error handling, telemetry, backup/restore).

</div>

---

## Contents
- Overview
- Features
- Architecture
- Screenshots (placeholders)
- Tech Stack
- Getting Started
- Environment/Build Flavors
- Database & Migrations
- Authentication
- Backup & Restore
- Error Handling & Telemetry
- Accessibility & Performance
- Project Structure
- Scripts & Commands
- Contributing
- License

## Overview
IQRA helps admins manage students and subscriptions completely offline with a polished UI and reliable local storage. It is designed for tablets and phones, and it scales up to desktop.

Key goals:
- Consistent headers, spacing, and responsive layouts across screens
- Compact dashboard metrics and minimalist filters
- Robust date handling (UTC storage, local display) and non-overlapping subscriptions
- Admin-friendly guidance without exposing technical errors

## Features
- Students: create, edit, details, search/typeahead; optional seat number support
- Subscriptions: list/grid, filters, add/edit/renew/cancel; date validation and overlap checks
- Dashboard: compact stats, quick actions (Export Data), recent activity
- Settings: theme, security, backup/restore controls
- Authentication: 4-digit passcode with optional biometrics (fingerprint/face)
- Backup/Restore: full data export/import (.zip/.csv), share to other devices
- Responsive UI: mobile/tablet/desktop using custom `ResponsiveUtils`

## Architecture
- State management: Riverpod (providers, notifiers)
- Database: Drift (tables, DAOs, migrations)
- Navigation: go_router (declarative routes, shell)
- UI: Material 3 with custom widgets (cards, tiles, filters)

## Screenshots
- Add your screenshots in `assets/README.md` and reference them here.

## Tech Stack
- Flutter 3.x
- Riverpod 2.x
- Drift 2.x
- go_router 12.x
- local_auth, path_provider, share_plus, image_picker, permission_handler

## Getting Started
1) Prerequisites
   - Flutter SDK installed and set up
   - Android Studio/Xcode (for device emulators)
   - Dart >= 3.8

2) Install
```bash
flutter pub get
```

3) Run
```bash
flutter run
```

4) Analyze and format
```bash
flutter analyze
dart format .
```

## Environment / Build Flavors
- App config lives in `lib/core/config/app_config.dart`.
- `developerMode` controls the diagnostics overlay (OFF by default). Do not enable in production.

## Database & Migrations
- Drift schema versioning in `lib/data/database/app_database.dart`
- Tables in `lib/data/database/tables/`
- DAOs in `lib/data/database/dao/`
- New column: `seatNumber` on students (schema v3); migrations included

## Authentication
- 4-digit passcode flow on startup
- Optional biometrics (checks hardware support, enrollment, settings); device credential fallback is configurable

## Backup & Restore
- Dedicated Backup page (`/backup`)—manual export (full/CSV) and import (.zip/.csv)
- `BackupService` integrates with file pickers and share targets
- Progress dialogs and safe `setState` with `mounted` checks

## Error Handling & Telemetry
- Global error boundary: friendly fallback UI with Retry; no stack traces shown to admins
- Developer-only diagnostics overlay gated by `AppConfig.developerMode`
- Telemetry service (`TelemetryService`):
  - Captures events/exceptions with PII redaction (names, IDs, phones, etc.)
  - Simple rate limiting; ready to wire to Sentry/Crashlytics
- Friendly error mapping (`ErrorMapper`): maps backend/validation errors to admin-safe messages
- Subscriptions sheets: inline date validation, overlap banner, buttons disabled when invalid; confirm to proceed when intentionally backdating

## Accessibility & Performance
- High-contrast-friendly colors via Material 3
- Text scaling clamped for consistent layout
- Avoids jank: light logging, no heavy work on UI thread

## Project Structure
```
lib/
  core/
    config/           # AppConfig
    routing/          # go_router setup
    theme/            # Material theme
    utils/            # telemetry, error mapping, responsive
  data/
    database/         # drift tables, DAOs, migrations
    models/           # data models
    repositories/     # impl of domain repos
    services/         # backup, etc.
  domain/
    entities/         # core types
    repositories/     # contracts
  presentation/
    layouts/          # app layout
    pages/            # dashboard, students, subscriptions, settings, auth, backup
    providers/        # riverpod providers/notifiers
    widgets/          # shared components
```

## Scripts & Commands
```bash
flutter pub get
flutter analyze
dart format .
flutter run -d chrome # or emulator id
```

## Contributing
1. Fork and create a feature branch
2. Run analyzer and formatters
3. Submit PR with a concise description and screenshots

## License
Proprietary. All rights reserved unless explicitly stated otherwise.

