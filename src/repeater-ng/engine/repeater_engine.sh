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

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting Repeater Engine..."

# 1. Load dynamic config
if [ ! -f "$CONFIG_FILE" ]; then
    log "FATAL: Config file $CONFIG_FILE not found!"
    exit 1
fi

if [ -f "$HELPER_LUA" ] && [ -x "$LUA_BIN" ]; then
    eval $("$LUA_BIN" "$HELPER_LUA" "$CONFIG_FILE" 2>/dev/null)
else
    log "FATAL: Lua helper $HELPER_LUA or Lua binary $LUA_BIN missing!"
    exit 1
fi

if [ -z "$CONFIG_UPSTREAM_SSID" ] || [ -z "$CONFIG_UPSTREAM_PSK" ]; then
    log "FATAL: Upstream SSID or PSK is missing in config!"
    exit 1
fi

# Auto-discover BSSID if omitted or set to hidden wildcard
if [ -z "$CONFIG_UPSTREAM_BSSID" ] || [ "$CONFIG_UPSTREAM_BSSID" = "00:00:00:00:00:00" ]; then
    log "BSSID omitted for SSID '$CONFIG_UPSTREAM_SSID'. Resolving via targeted driver probe..."
    wl -i wl0 scan -s "$CONFIG_UPSTREAM_SSID" 2>/dev/null || wl -i wl0 scan 2>/dev/null
    sleep 3
    FOUND_BSSID=$(wl -i wl0 scanresults 2>/dev/null | grep -B 2 -F "SSID: \"$CONFIG_UPSTREAM_SSID\"" | grep -i 'BSSID:' | awk '{print $2}' | sed -n '1p')
    if [ -n "$FOUND_BSSID" ] && [ ${#FOUND_BSSID} -eq 17 ]; then
        CONFIG_UPSTREAM_BSSID="$FOUND_BSSID"
        log "Resolved BSSID: $CONFIG_UPSTREAM_BSSID"
    fi
fi

UPSTREAM_GATEWAY="${CONFIG_UPSTREAM_GATEWAY:-192.168.1.1}"

log "Target Upstream: SSID='$CONFIG_UPSTREAM_SSID', BSSID='${CONFIG_UPSTREAM_BSSID:-<driver-select>}', Gateway='$UPSTREAM_GATEWAY'"

# 2. Stop conflicting vendor daemons
log "Stopping vendor mesh and router daemons..."
killall dot11d easyMeshd radvd wide-dhcp6s 2>/dev/null
sleep 2
killall dot11d easyMeshd 2>/dev/null

# 3. Create wpa_supplicant directory and configuration
# CRITICAL: If PSK is 64 hex characters, wpa_supplicant syntax forbids quotes!
# If PSK is an ASCII passphrase (8-63 chars), it MUST have quotes.
mkdir -p /var/run/wpa_supplicant

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
    scan_ssid=1
}
EOF

# 4. Generate persistent DHCP helper script for udhcpc
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

# 5. Connection retry loop (up to 4 attempts)
attempt=1
while [ "$attempt" -le 4 ]; do
    log "Connection attempt $attempt of 4..."

    killall wpa_supplicant udhcpc 2>/dev/null
    route del default dev wl0 2>/dev/null
    rm -f /var/run/wpa_supplicant/wl0

    # Clean up virtual SSIDs and reset wl0 into station / managed mode
    ifconfig wl0.1 down 2>/dev/null
    ifconfig wl0.2 down 2>/dev/null
    wl -i wl0 down
    wl -i wl0 ap 0
    wl -i wl0 infra 1
    wl -i wl0 mfp 0
    wl -i wl0 up

    # Ensure wl0 and sub-interfaces are detached from LAN bridge
    brctl delif "$LAN_BRIDGE" wl0 2>/dev/null
    brctl delif "$LAN_BRIDGE" wl0.1 2>/dev/null
    brctl delif "$LAN_BRIDGE" wl0.2 2>/dev/null
    ifconfig wl0 up

    # Start wpa_supplicant
    wpa_supplicant -B -i wl0 -D nl80211 -c "$WPA_CONF" -f /tmp/wpa.log -dd
    sleep 3

    # Force network selection and reassociation
    wpa_cli -i wl0 enable_network 0 2>/dev/null
    wpa_cli -i wl0 select_network 0 2>/dev/null
    wpa_cli -i wl0 reassociate 2>/dev/null

    # Wait for association loop
    wait_count=0
    while [ "$wait_count" -lt 10 ]; do
        sleep 3
        if wpa_cli -i wl0 status 2>/dev/null | grep -q 'wpa_state=COMPLETED'; then
            break
        fi
        wait_count=$(expr "$wait_count" + 1)
    done

    # Check association state
    if wpa_cli -i wl0 status 2>/dev/null | grep -q 'wpa_state=COMPLETED'; then
        log "Association COMPLETED on wl0. Requesting DHCP lease..."
        udhcpc -i wl0 -s /tmp/udhcpc.script -b -p /tmp/udhcpc-wl0.pid
        sleep 10

        # Verify gateway reachability
        if ping -c 2 -W 3 -I wl0 "$UPSTREAM_GATEWAY" >/dev/null 2>&1; then
            log "Gateway $UPSTREAM_GATEWAY reachable! Applying NAT & routing rules..."

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

            # Explicitly disable all 2.4G AP virtual interfaces (wl0 dedicated to upstream station)
            ifconfig wl0.1 down 2>/dev/null; wl -i wl0.1 bss down 2>/dev/null
            ifconfig wl0.2 down 2>/dev/null; wl -i wl0.2 bss down 2>/dev/null
            ifconfig wl1.1 down 2>/dev/null; wl -i wl1.1 bss down 2>/dev/null
            ifconfig wl1.2 down 2>/dev/null; wl -i wl1.2 bss down 2>/dev/null

            # Apply local 5G AP config if defined
            if [ -n "$CONFIG_LOCAL_5G_SSID" ]; then
                wl -i wl1 ssid "$CONFIG_LOCAL_5G_SSID" 2>/dev/null
                wl -i wl1 closed "${CONFIG_LOCAL_5G_HIDDEN:-0}" 2>/dev/null
                if [ -n "$CONFIG_LOCAL_5G_PASS" ]; then
                    wl -i wl1 wsec 4 2>/dev/null
                    wl -i wl1 wpa_auth 128 2>/dev/null
                    wl -i wl1 set_pmk "$CONFIG_LOCAL_5G_PASS" 2>/dev/null
                fi
            fi

            # Ensure hostapd is running solely on 5GHz wl1
            killall -9 hostapd 2>/dev/null
            sleep 1
            rm -f /var/run/hostapd/* 2>/dev/null
            hostapd -B /tmp/wl1_hapd.conf 2>/dev/null

            log "Repeater engine successfully configured and operational."
            exit 0
        else
            log "WARNING: DHCP succeeded but gateway $UPSTREAM_GATEWAY is unreachable (ARP/Boot race)."
        fi
    else
        log "WARNING: Association did not complete (wpa_state != COMPLETED)."
    fi

    attempt=$(expr "$attempt" + 1)
    if [ "$attempt" -le 4 ]; then
        log "Waiting 30 seconds before next attempt..."
        sleep 30
    fi
done

log "ERROR: All 4 connection attempts failed!"
exit 1
