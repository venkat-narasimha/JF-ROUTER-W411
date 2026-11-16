#!/bin/sh
# /pfrm2.0/bin/watchdog.sh
# Ping monitor that restarts repeater_engine.sh if the gateway is unreachable.

LOG_FILE="/tmp/repeater_watchdog.log"
CONFIG_FILE="/pfrm2.0/etc/repeater_config.json"
LUA_BIN="/pfrm2.0/bin/lua"
HELPER_LUA="/pfrm2.0/bin/config_env.lua"
FAIL_COUNT_FILE="/tmp/watchdog_fail_count"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Read config
if [ -f "$HELPER_LUA" ] && [ -x "$LUA_BIN" ] && [ -f "$CONFIG_FILE" ]; then
    eval $("$LUA_BIN" "$HELPER_LUA" "$CONFIG_FILE" 2>/dev/null)
fi

if [ "$CONFIG_WATCHDOG_ENABLED" = "0" ]; then
    exit 0
fi

GATEWAY="${CONFIG_UPSTREAM_GATEWAY:-192.168.1.1}"
MAX_FAILS="${CONFIG_WATCHDOG_MAX_FAILS:-3}"

# Read previous fail count
FAILS=0
if [ -f "$FAIL_COUNT_FILE" ]; then
    FAILS=$(cat "$FAIL_COUNT_FILE" 2>/dev/null)
    [ -z "$FAILS" ] && FAILS=0
fi

# Ping check
if ping -c 2 -W 3 -I wl0 "$GATEWAY" >/dev/null 2>&1; then
    if [ "$FAILS" -gt 0 ]; then
        log "Gateway $GATEWAY is back online. Resetting fail count."
        echo 0 > "$FAIL_COUNT_FILE"
    fi
    exit 0
else
    FAILS=$(expr "$FAILS" + 1)
    echo "$FAILS" > "$FAIL_COUNT_FILE"
    log "Gateway $GATEWAY ping check failed (fail $FAILS of $MAX_FAILS)."

    if [ "$FAILS" -ge "$MAX_FAILS" ]; then
        log "Max fails reached ($FAILS). Restarting repeater_engine.sh..."
        echo 0 > "$FAIL_COUNT_FILE"
        /pfrm2.0/bin/repeater_engine.sh &
    fi
fi
