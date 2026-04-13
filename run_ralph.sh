#!/bin/bash
# Ralph Suite Launcher - Starts loop, monitor, and watchdog together

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments (pass through to ralph.sh)
RALPH_ARGS="$@"

# Cleanup function - kill all child processes on exit
cleanup() {
    echo "Stopping Ralph suite..."
    kill $MONITOR_PID $WATCHDOG_PID 2>/dev/null
    wait
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start watchdog in background (logs to file)
bash/ralph_watchdog.sh &
WATCHDOG_PID=$!
echo "Started watchdog (PID: $WATCHDOG_PID)"

# Start monitor in new terminal tab (macOS)
osascript -e 'tell app "Terminal" to do script "cd '"$SCRIPT_DIR"' && bash/ralph_monitor.sh"' &
MONITOR_PID=$!
echo "Started monitor in new Terminal tab"

# Run ralph loop in foreground
bash/ralph.sh $RALPH_ARGS

# Cleanup when ralph finishes
cleanup
