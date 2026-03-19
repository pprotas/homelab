#!/bin/sh
set -eu

# ── Configuration ──────────────────────────────────────────────────
SALON_CLIENT="kenkkappers"
SALON_NAME="kenkkappers"
TREATMENT=2
EMPLOYEE=33
CHECK_DAYS=7          # look ahead window
POLL_INTERVAL=300     # seconds between checks

NTFY_URL="${NTFY_URL:-http://ntfy:80}"
NTFY_TOPIC="${NTFY_TOPIC:-barber}"
NTFY_TOKEN="${NTFY_TOKEN:-}"

BASE_URL="https://public.salonhub.nl/v2/api"
BOOKING_URL="https://widget.salonhub.nl/a/kenkkappers/kenkkappers/link.html"
LAST_FILE="/data/last_notification.txt"

# ── Helpers ────────────────────────────────────────────────────────
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"; }

notify() {
    title="$1"
    message="$2"
    if [ -n "$NTFY_TOKEN" ]; then
        curl -s -o /dev/null \
            -H "Authorization: Bearer ${NTFY_TOKEN}" \
            -H "Title: ${title}" \
            -H "Tags: scissors" \
            -H "Priority: high" \
            -H "Click: ${BOOKING_URL}" \
            -H "Actions: view, Book now, ${BOOKING_URL}" \
            -d "${message}" \
            "${NTFY_URL}/${NTFY_TOPIC}"
    else
        curl -s -o /dev/null \
            -H "Title: ${title}" \
            -H "Tags: scissors" \
            -H "Priority: high" \
            -H "Click: ${BOOKING_URL}" \
            -H "Actions: view, Book now, ${BOOKING_URL}" \
            -d "${message}" \
            "${NTFY_URL}/${NTFY_TOPIC}"
    fi
}

# ── Main loop ──────────────────────────────────────────────────────
mkdir -p /data
touch "$LAST_FILE"

log "Barber checker started (poll every ${POLL_INTERVAL}s, window ${CHECK_DAYS} days)"

while true; do
    today=$(date -u '+%Y-%m-%d')
    cutoff=$(date -u -d "@$(($(date +%s) + CHECK_DAYS*86400))" '+%Y-%m-%d')
    ts=$(date +%s%3N)

    log "Checking for dates between ${today} and ${cutoff}..."

    dates_json=$(curl -sf \
        "${BASE_URL}/OnlineAppointment.Remote.Dates/get?client=${SALON_CLIENT}&salon=${SALON_NAME}&treatment=${TREATMENT}&employee=${EMPLOYEE}&start=14&_=${ts}" \
        2>/dev/null) || {
        log "ERROR: Failed to fetch dates"
        sleep "$POLL_INTERVAL"
        continue
    }

    # Extract dates within our window
    available_dates=$(echo "$dates_json" | jq -r \
        --arg today "$today" \
        --arg cutoff "$cutoff" \
        '[.dates[]?.date // empty] | map(select(. >= $today and . <= $cutoff)) | .[]' \
        2>/dev/null) || {
        log "ERROR: Failed to parse dates response"
        sleep "$POLL_INTERVAL"
        continue
    }

    if [ -z "$available_dates" ]; then
        log "No available dates in the next ${CHECK_DAYS} days"
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Build a summary of dates + times
    summary=""
    for date in $available_dates; do
        ts_inner=$(date +%s%3N)
        times_json=$(curl -sf \
            "${BASE_URL}/OnlineAppointment.Remote.Times/get?client=${SALON_CLIENT}&salon=${SALON_NAME}&treatment=${TREATMENT}&employee=${EMPLOYEE}&date=${date}&_=${ts_inner}" \
            2>/dev/null) || {
            log "WARN: Failed to fetch times for ${date}"
            continue
        }

        times=$(echo "$times_json" | jq -r '[.times[]?.time // empty] | map(.[0:5]) | .[]' 2>/dev/null)
        if [ -n "$times" ]; then
            times_line=$(echo "$times" | tr '\n' ' ' | sed 's/ $//')
            summary="${summary}${date}: ${times_line}\n"
        else
            summary="${summary}${date}: times unavailable\n"
        fi
    done

    if [ -z "$summary" ]; then
        log "Dates found but no time slots available"
        sleep "$POLL_INTERVAL"
        continue
    fi

    # Deduplicate: only notify if results changed
    summary_hash=$(printf '%s' "$summary" | md5sum | cut -d' ' -f1)
    last_hash=$(cat "$LAST_FILE" 2>/dev/null || echo "")

    if [ "$summary_hash" != "$last_hash" ]; then
        message=$(printf '%b' "$summary")
        log "New availability found, sending notification"
        notify "Barber spot available!" "$message"
        printf '%s' "$summary_hash" > "$LAST_FILE"
    else
        log "Availability unchanged, skipping notification"
    fi

    sleep "$POLL_INTERVAL"
done
