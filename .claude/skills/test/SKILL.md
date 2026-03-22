# /test

Run the full test suite for both backend and mobile.

## When to use
When the user invokes `/test` or asks to run all tests/checks.

## Instructions
Run backend checks first, then mobile checks. Stop and report if either fails.

### Backend
```bash
cd fence && mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix sobelow --config && mix deps.audit --ignore-package-names hackney && mix test
```

### Mobile
```bash
cd mobile && /Users/eklinkhammer/development/flutter/bin/flutter analyze --fatal-infos --fatal-warnings && /Users/eklinkhammer/development/flutter/bin/flutter test
```
