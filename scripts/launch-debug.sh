#!/bin/bash
# Launch Project Launcher with full crash diagnostics.
# Captures: stderr, stdout, system log, and crash reports.

set -u

APP="/Applications/Project Launcher.app"
CRASH_LOG_DIR="$HOME/Library/Logs/DiagnosticReports"
SUPPORT_DIR="$HOME/Library/Application Support/com.stringswaytech.projectbrowser"
OUT_DIR="${1:-/tmp/plauncher-crash}"

mkdir -p "$OUT_DIR"

echo "=== Project Launcher — Crash Diagnostics ==="
echo "Output dir: $OUT_DIR"
echo ""

# Kill any existing instance
pkill -f "Project Launcher" 2>/dev/null
sleep 1

# Snapshot existing crash reports so we can diff later
ls "$CRASH_LOG_DIR" > "$OUT_DIR/crash-reports-before.txt" 2>/dev/null

# Clear the app log
> "$SUPPORT_DIR/app.log" 2>/dev/null

# Launch from the binary directly (captures stdout + stderr)
echo "Launching app..."
"$APP/Contents/MacOS/Project Launcher" \
  > "$OUT_DIR/stdout.log" \
  2> "$OUT_DIR/stderr.log" &
APP_PID=$!
echo "PID: $APP_PID"

# Also capture system log for this process
/usr/bin/log stream --predicate "processID == $APP_PID" --style compact \
  > "$OUT_DIR/syslog.log" 2>/dev/null &
LOG_PID=$!

# Wait for the app to exit (crash or user quit)
echo "Waiting for app to exit (Ctrl+C to stop early)..."
wait $APP_PID 2>/dev/null
EXIT_CODE=$?

# Stop log stream
kill $LOG_PID 2>/dev/null

# Copy the app log
cp "$SUPPORT_DIR/app.log" "$OUT_DIR/app.log" 2>/dev/null

# Check for new crash reports
sleep 2
ls "$CRASH_LOG_DIR" > "$OUT_DIR/crash-reports-after.txt" 2>/dev/null
NEW_REPORTS=$(comm -13 "$OUT_DIR/crash-reports-before.txt" "$OUT_DIR/crash-reports-after.txt" 2>/dev/null)

echo ""
echo "=== Results ==="
echo "Exit code: $EXIT_CODE"
echo ""

if [ -s "$OUT_DIR/stderr.log" ]; then
  echo "--- stderr ---"
  cat "$OUT_DIR/stderr.log"
  echo ""
fi

if [ -n "$NEW_REPORTS" ]; then
  echo "--- New crash reports ---"
  for report in $NEW_REPORTS; do
    echo "  $CRASH_LOG_DIR/$report"
    cp "$CRASH_LOG_DIR/$report" "$OUT_DIR/" 2>/dev/null
  done
  echo ""
else
  echo "No new crash reports found."
fi

echo ""
echo "All logs saved to: $OUT_DIR"
echo "  stdout.log    — app stdout"
echo "  stderr.log    — app stderr"
echo "  syslog.log    — system log for this PID"
echo "  app.log       — Flutter app log"
ls "$OUT_DIR"
