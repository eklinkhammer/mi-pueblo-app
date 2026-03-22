# /test-mobile

Run the full mobile check pipeline (static analysis + tests).

## When to use
When the user invokes `/test-mobile` or asks to run mobile tests/checks.

## Instructions
Run the following command:
```bash
cd mobile && /Users/eklinkhammer/development/flutter/bin/flutter analyze --fatal-infos --fatal-warnings && /Users/eklinkhammer/development/flutter/bin/flutter test
```

If any step fails, stop and report the failure to the user.
