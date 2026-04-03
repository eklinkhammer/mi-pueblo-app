# /validate

Run the same checks as GitHub CI (check-backend.yml and check-mobile.yml) locally.

## When to use
When the user invokes `/validate` or asks to run CI checks locally.

## Instructions
Run backend checks first, then mobile checks. Stop and report on first failure.

### Backend
```bash
cd fence && mix deps.get && mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix sobelow --config && mix deps.audit --ignore-package-names hackney && mix test
```

### Mobile
```bash
cd mobile && /Users/eklinkhammer/development/flutter/bin/flutter pub get && /Users/eklinkhammer/development/flutter/bin/flutter gen-l10n && /Users/eklinkhammer/development/flutter/bin/flutter analyze --fatal-infos --fatal-warnings && /Users/eklinkhammer/development/flutter/bin/flutter test
```
