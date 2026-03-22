# /test-backend

Run the full backend check pipeline (compile, format, lint, security, audit, tests).

## When to use
When the user invokes `/test-backend` or asks to run backend tests/checks.

## Instructions
Run the following command:
```bash
cd fence && mix compile --warnings-as-errors && mix format --check-formatted && mix credo --strict && mix sobelow --config && mix deps.audit --ignore-package-names hackney && mix test
```

If any step fails, stop and report the failure to the user.
