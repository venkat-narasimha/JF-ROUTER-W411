#!/bin/sh
# JCOW411 R2.3 routed Wi-Fi repeater template. Fill placeholders before use.
UPLINK_SSID="REPLACE_WITH_UPLINK_SSID"
UPLINK_BSSID="00:00:00:00:00:00"
UPLINK_PSK="REPLACE_WITH_64_HEX_PSK"
LAN_BRIDGE="bdg2"

sleep 60
killall dot11d easyMeshd radvd wide-dhcp6s 2>/dev/null

cat > /tmp/wpa.conf <<EOF
ctrl_interface=/var/run/wpa_supplicant
ap_scan=2
network={
    ssid="$UPLINK_SSID"
    bssid=$UPLINK_BSSID
    psk="$UPLINK_PSK"
    key_mgmt=WPA-PSK
}
EOF

attempt=1
while [ "$attempt" -le 4 ]; do
    killall wpa_supplicant udhcpc 2>/dev/null
    route del default dev wl0 2>/dev/null
    wl -i wl0 down; wl -i wl0 ap 0; wl -i wl0 infra 1; wl -i wl0 mfp 0; wl -i wl0 up
    brctl delif "$LAN_BRIDGE" wl0 2>/dev/null
    wpa_supplicant -B -i wl0 -D nl80211 -c /tmp/wpa.conf -f /tmp/wpa.log -dd
    sleep 3
    wpa_cli -i wl0 enable_network 0; wpa_cli -i wl0 select_network 0; wpa_cli -i wl0 reassociate
    sleep 15
    if wpa_cli -i wl0 status | grep -q 'wpa_state=COMPLETED'; then
        udhcpc -i wl0 -b
        sleep 10
        if ping -c 1 -I wl0 192.168.1.1 >/dev/null 2>&1; then
            echo 1 > /proc/sys/net/ipv4/ip_forward
            iptables -t nat -I POSTROUTING -o wl0 -j MASQUERADE
            iptables -I FORWARD -i "$LAN_BRIDGE" -o wl0 -j ACCEPT
            iptables -I FORWARD -i wl0 -o "$LAN_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT
            exit 0
        fi
    fi
    attempt=$(expr "$attempt" + 1)
    sleep 45
done
exit 1
