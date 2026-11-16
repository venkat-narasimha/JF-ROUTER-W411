#!/bin/sh
# /pfrm2.0/bin/repeater_engine.sh
# Next-Gen Config-Driven WISP Repeater Engine for JCOW411 (R2.3)
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/pfrm2.0/bin:$PATH

LOG_FILE="/tmp/repeater_engine.log"
CONFIG_FILE="/pfrm2.0/etc/repeater_config.json"
LUA_BIN="/pfrm2.0/bin/lua"
HELPER_LUA="/pfrm2.0/bin/config_env.lua"
WPA_CONF="/tmp/wpa.conf"
LAN_BRIDGE="bdg2"
PID_FILE="/var/run/repeater_engine.pid"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

set_led() {
    [ -x /pfrm2.0/bin/set_led.sh ] && /pfrm2.0/bin/set_led.sh "$1" 2>/dev/null
}

# 1. Enforce single instance via PID lock
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        log "Repeater engine already running (PID $OLD_PID). Exiting."
        exit 0
    fi
fi
echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT INT TERM

log "Starting Repeater Engine..."
set_led boot

# 2. Stop conflicting vendor daemons, stock hostapd, and block TR-069
log "Stopping vendor mesh, router daemons, stock hostapd, and locking down TR-069..."
killall -9 hostapd acsd2 wps_pbcd wlevt2 ceventd 2>/dev/null
killall dot11d easyMeshd radvd wide-dhcp6s tr69 tr069 tr69c cwmp 2>/dev/null
kill -9 $(ps | grep -E 'notificationToAcs|tr69Init|configUpdate|script\.sh|script\.lua|watchdog\.sh' | grep -v grep | awk '{print $1}') 2>/dev/null
iptables -I OUTPUT -p tcp --dport 7547 -j DROP 2>/dev/null
iptables -I INPUT -p tcp --dport 7547 -j DROP 2>/dev/null

# Clean up stock virtual AP interfaces immediately
ifconfig wl0.1 down 2>/dev/null; wl -i wl0.1 bss down 2>/dev/null
ifconfig wl0.2 down 2>/dev/null; wl -i wl0.2 bss down 2>/dev/null
ifconfig wl1.1 down 2>/dev/null; wl -i wl1.1 bss down 2>/dev/null
ifconfig wl1.2 down 2>/dev/null; wl -i wl1.2 bss down 2>/dev/null

# 3. Load dynamic config
if [ ! -f "$CONFIG_FILE" ]; then
    log "FATAL: Config file $CONFIG_FILE not found!"
    set_led fatal
    exit 1
fi

if [ -f "$HELPER_LUA" ] && [ -x "$LUA_BIN" ]; then
    eval $("$LUA_BIN" "$HELPER_LUA" "$CONFIG_FILE" 2>/dev/null)
else
    log "FATAL: Lua helper $HELPER_LUA or Lua binary $LUA_BIN missing!"
    set_led fatal
    exit 1
fi

# 4. Local 5GHz AP bringup function (executed after uplink settles to prevent driver race conditions)
start_local_ap() {
    log "Ensuring local 5GHz AP (wl1) is active..."
    if [ -n "$CONFIG_LOCAL_5G_SSID" ]; then
        if [ -f /tmp/wl1_hapd.conf ]; then
            sed -i "s/^ssid=.*/ssid=$CONFIG_LOCAL_5G_SSID/" /tmp/wl1_hapd.conf
            [ -n "$CONFIG_LOCAL_5G_PASS" ] && sed -i "s/^wpa_passphrase=.*/wpa_passphrase=$CONFIG_LOCAL_5G_PASS/" /tmp/wl1_hapd.conf
            sed -i "s/^ignore_broadcast_ssid=.*/ignore_broadcast_ssid=${CONFIG_LOCAL_5G_HIDDEN:-0}/" /tmp/wl1_hapd.conf
        fi
        wl -i wl1 ssid "$CONFIG_LOCAL_5G_SSID" 2>/dev/null
        wl -i wl1 closed "${CONFIG_LOCAL_5G_HIDDEN:-0}" 2>/dev/null
        if [ -n "$CONFIG_LOCAL_5G_PASS" ]; then
            wl -i wl1 wsec 4 2>/dev/null
            wl -i wl1 wpa_auth 128 2>/dev/null
            wl -i wl1 set_pmk "$CONFIG_LOCAL_5G_PASS" 2>/dev/null
        fi
    fi

    # Ensure wl1 interfaces are bridged to LAN
    brctl addif "$LAN_BRIDGE" wl1 2>/dev/null
    brctl addif "$LAN_BRIDGE" wl1.1 2>/dev/null
    brctl addif "$LAN_BRIDGE" wl1.2 2>/dev/null

    # Restart eapd and hostapd together to guarantee clean EAPOL socket coupling
    if ! ps | grep -E 'hostapd /tmp/wl1_hapd.conf|hostapd -B /tmp/wl1_hapd.conf' | grep -v grep >/dev/null; then
        log "Starting eapd and hostapd for wl1..."
        killall -9 hostapd eapd 2>/dev/null
        sleep 1
        eapd &
        sleep 1
        rm -f /var/run/hostapd/* 2>/dev/null
        hostapd -B /tmp/wl1_hapd.conf
        sleep 2
        if ps | grep hostapd | grep -v grep >/dev/null; then
            log "Local 5GHz AP (hostapd) successfully enabled."
        else
            log "WARNING: hostapd background launch failed. Retrying in foreground-background..."
            hostapd -B /tmp/wl1_hapd.conf
        fi
    else
        log "Local 5GHz AP hostapd is already running."
    fi
}

# 5. Clean up wl0 and initialize station mode
# Full security state reset required: stock hostapd leaves Broadcom firmware in AP EAPOL mode
# which blocks 4-way WPA2 handshake delivery to wpa_supplicant unless explicitly cleared
brctl delif "$LAN_BRIDGE" wl0 2>/dev/null
brctl delif "$LAN_BRIDGE" wl0.1 2>/dev/null
brctl delif "$LAN_BRIDGE" wl0.2 2>/dev/null
wl -i wl0 down 2>/dev/null
wl -i wl0 ap 0 2>/dev/null
wl -i wl0 infra 1 2>/dev/null
wl -i wl0 mfp 0 2>/dev/null
wl -i wl0 wsec 0 2>/dev/null
wl -i wl0 wpa_auth 0 2>/dev/null
wl -i wl0 deauth 2>/dev/null
wl -i wl0 up 2>/dev/null
ifconfig wl0 up 2>/dev/null
sleep 2

# 6. Live spectrum scan & dynamic BSSID / candidate ranking (Zero Hardcoding)
log "Triggering live spectrum scan on wl0..."
set_led scanning
wl -i wl0 scan >/dev/null 2>&1
sleep 4

# Re-eval config with dynamic scanresults resolution
eval $("$LUA_BIN" "$HELPER_LUA" "$CONFIG_FILE" auto_select 2>/dev/null)

log "Selected upstream target: SSID='$CONFIG_UPSTREAM_SSID', BSSID='$CONFIG_UPSTREAM_BSSID', CH='$CONFIG_UPSTREAM_CHANNEL'"

# Set radio channel if discovered to avoid channel search delay
if [ -n "$CONFIG_UPSTREAM_CHANNEL" ]; then
    wl -i wl0 channel "$CONFIG_UPSTREAM_CHANNEL" 2>/dev/null
fi

# 7. Generate persistent DHCP helper script for udhcpc
cat > /tmp/udhcpc.script << 'UEOF'
#!/bin/sh
case "$1" in
  bound|renew)
    ifconfig "$interface" "$ip" netmask "${subnet:-255.255.255.0}"
    route del default dev "$interface" 2>/dev/null
    [ -n "$router" ] && route add default gw "$router" dev "$interface"
    ;;
esac
UEOF
chmod +x /tmp/udhcpc.script

# 8. Connection retry loop (up to 4 attempts)
attempt=1
while [ "$attempt" -le 4 ]; do
    log "Connection attempt $attempt of 4..."

    killall wpa_supplicant udhcpc 2>/dev/null
    route del default dev wl0 2>/dev/null
    rm -f /var/run/wpa_supplicant/wl0
    mkdir -p /var/run/wpa_supplicant

    # Reset Broadcom radio security and channel state
    wl -i wl0 down 2>/dev/null
    wl -i wl0 ap 0 2>/dev/null
    wl -i wl0 infra 1 2>/dev/null
    wl -i wl0 mfp 0 2>/dev/null
    wl -i wl0 wsec 0 2>/dev/null
    wl -i wl0 wpa_auth 0 2>/dev/null
    wl -i wl0 deauth 2>/dev/null
    if [ -n "$CONFIG_UPSTREAM_CHANNEL" ]; then
        wl -i wl0 channel "$CONFIG_UPSTREAM_CHANNEL" 2>/dev/null
    fi
    wl -i wl0 up 2>/dev/null
    ifconfig wl0 up 2>/dev/null
    sleep 1

    if [ ${#CONFIG_UPSTREAM_PSK} -eq 64 ]; then
        PSK_LINE="psk=$CONFIG_UPSTREAM_PSK"
    else
        PSK_LINE="psk=\"$CONFIG_UPSTREAM_PSK\""
    fi

    BSSID_LINE=""
    if [ -n "$CONFIG_UPSTREAM_BSSID" ] && [ "$CONFIG_UPSTREAM_BSSID" != "00:00:00:00:00:00" ]; then
        BSSID_LINE="bssid=$CONFIG_UPSTREAM_BSSID"
    fi

    cat > "$WPA_CONF" <<EOF
ctrl_interface=/var/run/wpa_supplicant
ap_scan=2
network={
    ssid="$CONFIG_UPSTREAM_SSID"
    $BSSID_LINE
    $PSK_LINE
    key_mgmt=WPA-PSK
}
EOF

    # Start wpa_supplicant & set LED to Associating (Solid Blue)
    set_led associating
    wpa_supplicant -B -i wl0 -D nl80211 -c "$WPA_CONF" -f /tmp/wpa.log -dd
    sleep 2

    # Activate network without forcing 802.1X reassociate packet
    wpa_cli -i wl0 enable_network 0 2>/dev/null
    wpa_cli -i wl0 select_network 0 2>/dev/null

    # Wait for association loop (up to 30 seconds)
    wait_count=0
    while [ "$wait_count" -lt 15 ]; do
        sleep 2
        if wpa_cli -i wl0 status 2>/dev/null | grep -q 'wpa_state=COMPLETED'; then
            break
        fi
        wait_count=$(expr "$wait_count" + 1)
    done

    # Check association state
    if wpa_cli -i wl0 status 2>/dev/null | grep -q 'wpa_state=COMPLETED'; then
        log "Association COMPLETED on wl0. Requesting DHCP lease..."
        set_led obtaining_ip
        udhcpc -i wl0 -s /tmp/udhcpc.script -b -p /tmp/udhcpc-wl0.pid
        sleep 8

        # Dynamically discover active gateway from route, fallback to config
        ACTIVE_GW=$(route -n 2>/dev/null | awk '$1 == "0.0.0.0" && $8 == "wl0" {print $2; exit}')
        [ -z "$ACTIVE_GW" ] && ACTIVE_GW="$CONFIG_UPSTREAM_GATEWAY"
        [ -z "$ACTIVE_GW" ] && ACTIVE_GW="192.168.1.1"

        # Verify gateway reachability
        if ping -c 2 -W 3 -I wl0 "$ACTIVE_GW" >/dev/null 2>&1; then
            log "Gateway $ACTIVE_GW reachable! Applying NAT & routing rules..."

            echo 1 > /proc/sys/net/ipv4/ip_forward

            # Delete old NAT rules before prepending new ones to prevent duplication
            iptables -t nat -D POSTROUTING -o wl0 -j MASQUERADE 2>/dev/null
            iptables -t nat -I POSTROUTING 1 -o wl0 -j MASQUERADE

            iptables -D FORWARD -i "$LAN_BRIDGE" -o wl0 -j ACCEPT 2>/dev/null
            iptables -I FORWARD 1 -i "$LAN_BRIDGE" -o wl0 -j ACCEPT

            iptables -D FORWARD -i wl0 -o "$LAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
            iptables -I FORWARD 1 -i wl0 -o "$LAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT

            # Ensure DNS forwarding / redirection
            iptables -t nat -D PREROUTING -i "$LAN_BRIDGE" -p udp --dport 53 -j DNAT --to-destination 8.8.8.8 2>/dev/null
            iptables -t nat -I PREROUTING 1 -i "$LAN_BRIDGE" -p udp --dport 53 -j DNAT --to-destination 8.8.8.8
            iptables -t nat -D PREROUTING -i "$LAN_BRIDGE" -p tcp --dport 53 -j DNAT --to-destination 8.8.8.8 2>/dev/null
            iptables -t nat -I PREROUTING 1 -i "$LAN_BRIDGE" -p tcp --dport 53 -j DNAT --to-destination 8.8.8.8

            # Ensure local 5GHz AP is active once upstream link and routing are verified
            start_local_ap

            # Automatically synchronize real-world time via NTP once internet is live
            (
                sleep 2
                /pfrm2.0/bin/ntpclient -s -h time.google.com 2>/dev/null || \
                ntpd -q -p time.google.com 2>/dev/null || \
                ntpd -q -p pool.ntp.org 2>/dev/null || \
                rdate -s time.google.com 2>/dev/null
            ) &

            log "Repeater engine successfully configured and online."
            set_led online
            exit 0
        else
            log "WARNING: DHCP completed but gateway $ACTIVE_GW is unreachable."
        fi
    else
        log "WARNING: Association did not complete (wpa_state != COMPLETED)."
    fi

    attempt=$(expr "$attempt" + 1)
    if [ "$attempt" -le 4 ]; then
        set_led retrying
        if [ "$attempt" -ge 3 ] && [ -f "$HELPER_LUA" ] && [ -x "$LUA_BIN" ]; then
            log "Attempting failover to alternative saved network profile..."
            wl -i wl0 scan >/dev/null 2>&1
            sleep 3
            eval $("$LUA_BIN" "$HELPER_LUA" "$CONFIG_FILE" auto_select "$CONFIG_UPSTREAM_BSSID" 2>/dev/null)
        fi
        log "Waiting 15 seconds before next attempt..."
        sleep 15
    fi
done

log "ERROR: All 4 connection attempts failed!"
start_local_ap
set_led fatal
sleep 2
exit 1
