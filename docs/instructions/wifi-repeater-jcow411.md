# JCOW411 Wi-Fi Repeater (Verified R2.3 Workflow)

## Scope
Routed repeater (WISP-style): `wl0` joins an upstream 2.4 GHz WPA2 network as station; router NATs LAN clients behind `bdg2`. Verified on JCOW411 R2.3 only. Not a transparent bridge.

## Compatibility / Verification Status
- **Verified**: JCOW411 R2.3 (this fork, end-to-end cold-boot success).
- JCOW404, other firmware, other models: untested.
- Upstream must be 2.4 GHz WPA2-PSK/AES; WPA3/Enterprise untested.

## Risk
- Modifies radio configuration and routing; wrong settings can lose management access.
- Requires root Telnet and recovery path (serial/UART or stock firmware).
- Boot-time race with vendor services (`dot11d`, `easyMeshd`) handled by bounded retry.

## Prerequisites
- Root Telnet access (see [Get Root Access](get-root-access-jf-ont.md)).
- Upstream network: SSID, BSSID (MAC), WPA2 passphrase.
- Wired management client; disable its Wi-Fi during testing.
- `artifacts/router-backups/` for real script/backups (gitignored).

## Procedure

### 1. Prepare the script template
Copy `src/scripts/repeater.sh` to router (e.g., `/pfrm2.0/etc/repeater.sh`) and fill placeholders:
```bash
UPLINK_SSID="REPLACE_WITH_UPLINK_SSID"
UPLINK_BSSID="00:00:00:00:00:00"  # upstream AP MAC
UPLINK_PSK="REPLACE_WITH_64_HEX_PSK"  # 64-char hex from `wpa_passphrase`
LAN_BRIDGE="bdg2"
```

Convert passphrase to 64-hex PSK:
```bash
wpa_passphrase "SSID" "passphrase" | grep psk= | cut -d= -f2
```

### 2. Make executable and invoke
```bash
chmod +x /pfrm2.0/etc/repeater.sh
/pfrm2.0/etc/repeater.sh &
```

### 3. Persist across reboots (verified hook)
Add to `/pfrm2.0/etc/userInit` (or `customInit`):
```bash
sleep 60
/pfrm2.0/etc/repeater.sh &
```
The `platformInit` → `userInit` chain runs this on boot.

## Validation
Wait up to 6 minutes after cold boot, then verify:
```bash
# 1. Association complete
wpa_cli -i wl0 status | grep 'wpa_state=COMPLETED'

# 2. DHCP lease on wl0
ifconfig wl0 | grep 'inet addr'

# 3. Gateway reachable
ping -c 1 -I wl0 192.168.1.1

# 4. NAT/forwarding active
iptables -t nat -L POSTROUTING | grep MASQUERADE
iptables -L FORWARD | grep -E '(bdg2|wl0)'

# 5. Laptop traceroute
traceroute 8.8.8.8
# Expected: 192.168.29.1 -> 192.168.1.1 -> upstream
```

## Recovery
If association fails:
1. Wired Telnet to router.
2. Check logs: `/tmp/wpa.log`, `/tmp/repeater.log` (if added).
3. Manual test: run script steps interactively to isolate failure.
4. Restore prior script from `artifacts/router-backups/`.
5. Full evidence trail in [`TIMELINE.md`](../../TIMELINE.md).

## Troubleshooting
- `wpa_state=DISCONNECTED` — wrong BSSID/PSK, or vendor `dot11d`/`easyMeshd` reclaiming `wl0`. Script kills them twice with delay.
- `nl80211 scan ret=-95` — driver scan path broken; script uses `ap_scan=2` with pinned BSSID (workaround).
- Gateway ping fails but DHCP succeeded — boot race with vendor init; script retries up to 4 times with 45s delay.
- No `head` applet — BusyBox lacks `head`; script avoids it.
- Laptop has dual Wi-Fi+Ethernet — disable laptop Wi-Fi to validate Ethernet path.

## Key Technical Details
- Radio: `wl0` (2.4 GHz), `wl1` (5 GHz).
- Driver: proprietary `wl`/`dhd` with `cfg80211` + `nl80211` supplicant backend.
- Bridge: `bdg2` (LAN).
- Upstream gateway observed at `192.168.1.1` (DHCP lease).
- Router LAN IP: `192.168.29.1`.
- IPv4 forwarding + `MASQUERADE` on `wl0` + `FORWARD` rules between `bdg2` and `wl0`.
- Vendor IPv6 daemons (`radvd`, `wide-dhcp6s`) stopped to avoid DNS conflicts.