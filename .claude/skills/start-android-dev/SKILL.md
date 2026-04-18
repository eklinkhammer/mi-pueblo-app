# /start-android-dev

Launch the full Fence Android development environment: emulator + database + Phoenix backend + Flutter app.

## When to use
When the user invokes `/start-android-dev` or asks to start the dev environment / dev stack.

## Instructions

### Step 1: Check for a connected Android device

```bash
$HOME/Library/Android/sdk/platform-tools/adb devices | grep -E "^[a-zA-Z0-9]+" | grep -w "device$"
```

If no device is connected, invoke `/start-android-emulator`, then run:

```bash
$HOME/Library/Android/sdk/platform-tools/adb wait-for-device
```

### Step 2: Check the database

```bash
cd fence && docker compose ps --status running
```

If no containers are running, start them:

```bash
cd fence && docker compose up -d
```

Then verify the database is accepting connections:

```bash
pg_isready -h localhost -p 5432
```

### Step 3: Check the Phoenix backend

```bash
lsof -ti :4000 2>/dev/null
```

If nothing is listening on port 4000, start the Phoenix server with `run_in_background: true`:

```bash
cd fence && mix phx.server
```

### Step 4: Start the Flutter app

Run with `run_in_background: true`:

```bash
cd mobile && /Users/eklinkhammer/development/flutter/bin/flutter run
```

### Step 5: Report

Summarize what was started vs what was already running:
- Android device/emulator status
- Database status
- Phoenix backend status
- Flutter app launch status
