#!/bin/bash

# Ralph Watchdog - Monitors Ralph's progress and detects stalls
# Runs independently, logs issues, and can restart Ralph if needed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/../prd.json"
LOG_FILE="$SCRIPT_DIR/ralph_watchdog.log"
CHECK_INTERVAL=600  # 10 minutes in seconds
STALL_THRESHOLD=1800  # 30 minutes without progress = stalled

# Track state
LAST_COMMIT=""
LAST_COMMIT_TIME=0
STALL_ALERTED=false

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

get_completed_count() {
    jq '[.stories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null || echo "0"
}

get_next_story() {
    jq -r '[.stories[] | select(.passes == false)][0] | "\(.id): \(.title)"' "$PRD_FILE" 2>/dev/null || echo "unknown"
}

get_latest_commit() {
    git log --oneline -1 --format="%h" 2>/dev/null || echo ""
}

get_latest_commit_time() {
    git log -1 --format="%ct" 2>/dev/null || echo "0"
}

is_ralph_running() {
    pgrep -f "ralph.sh" > /dev/null 2>&1
}

is_claude_running() {
    pgrep -f "claude" > /dev/null 2>&1
}

check_progress() {
    local current_commit=$(get_latest_commit)
    local current_time=$(date +%s)
    local completed=$(get_completed_count)
    local total=$(jq '[.stories[]] | length' "$PRD_FILE" 2>/dev/null || echo "14")
    local next=$(get_next_story)

    # Check if all done
    if [[ "$completed" == "$total" ]]; then
        log "ALL STORIES COMPLETE! ($completed/$total)"
        log "Ralph has finished building the JTF News app."
        exit 0
    fi

    # Check for new commit
    if [[ "$current_commit" != "$LAST_COMMIT" ]]; then
        LAST_COMMIT="$current_commit"
        LAST_COMMIT_TIME=$(get_latest_commit_time)
        STALL_ALERTED=false
        log "Progress: $completed/$total complete | Next: $next | Commit: $current_commit"
    else
        # No new commit - check for stall
        local time_since_commit=$((current_time - LAST_COMMIT_TIME))

        if [[ $time_since_commit -gt $STALL_THRESHOLD ]] && [[ "$STALL_ALERTED" == "false" ]]; then
            STALL_ALERTED=true
            log "STALL DETECTED: No commits for $((time_since_commit / 60)) minutes"
            log "    Last story: $next"
            log "    Claude running: $(is_claude_running && echo 'yes' || echo 'NO')"
            log "    Ralph running: $(is_ralph_running && echo 'yes' || echo 'NO')"

            # Check for errors in recent output
            if [[ -f "$SCRIPT_DIR/ralph_output.log" ]]; then
                local errors=$(tail -100 "$SCRIPT_DIR/ralph_output.log" | grep -i "error\|failed\|exception" | tail -3)
                if [[ -n "$errors" ]]; then
                    log "    Recent errors found:"
                    echo "$errors" | while read line; do log "      $line"; done
                fi
            fi
        elif [[ $time_since_commit -le $STALL_THRESHOLD ]]; then
            log "Waiting: $completed/$total | Working on: $next | ${time_since_commit}s since last commit"
        fi
    fi
}

main() {
    log "=========================================="
    log "Ralph Watchdog Started - JTF News App"
    log "Check interval: ${CHECK_INTERVAL}s ($(($CHECK_INTERVAL / 60)) min)"
    log "Stall threshold: ${STALL_THRESHOLD}s ($(($STALL_THRESHOLD / 60)) min)"
    log "=========================================="

    # Initialize
    LAST_COMMIT=$(get_latest_commit)
    LAST_COMMIT_TIME=$(get_latest_commit_time)

    local completed=$(get_completed_count)
    local total=$(jq '[.stories[]] | length' "$PRD_FILE" 2>/dev/null || echo "14")
    log "Starting state: $completed/$total stories complete"

    while true; do
        check_progress
        sleep "$CHECK_INTERVAL"
    done
}

# Handle Ctrl+C gracefully
trap 'log "Watchdog stopped by user"; exit 0' SIGINT SIGTERM

main
