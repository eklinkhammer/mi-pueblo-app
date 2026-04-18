# /start-android-emulator

Launch a local Android emulator for Fence mobile development.

## When to use
When the user invokes `/start-android-emulator` or asks to start/launch an Android emulator.

## Instructions

Two AVDs are available:
- `Pixel_6_Pro_User_1` (preferred / default)
- `Pixel_6_User_2` (fallback, also used as a second emulator for multi-account testing)

### Step 1: Check which AVDs are currently running

The Android emulator runs as a `qemu-system-*` process with `-avd <NAME>` in its command line. Check both AVDs:

```bash
pgrep -fl "qemu-system.*Pixel_6_Pro_User_1" >/dev/null && echo "user1 running" || echo "user1 free"
pgrep -fl "qemu-system.*Pixel_6_User_2" >/dev/null && echo "user2 running" || echo "user2 free"
```

### Step 2: Pick the AVD to launch

1. If `Pixel_6_Pro_User_1` is **not** running → launch it.
2. Else if `Pixel_6_User_2` is **not** running → launch it.
3. Else (both running) → do not launch anything; report that both emulators are already running.

### Step 3: Launch the chosen emulator

Run the emulator binary with `run_in_background: true`:

```bash
$HOME/Library/Android/sdk/emulator/emulator -avd <AVD_NAME>
```

Replace `<AVD_NAME>` with whichever AVD was chosen in Step 2.

### Step 4: Report

Tell the user which AVD was launched, or that both were already running and nothing was done.
