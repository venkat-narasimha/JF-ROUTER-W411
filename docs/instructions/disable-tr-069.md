# Disable TR-069 (CWMP Client)

## Purpose
Replace or disable the TR-069 client (`dimclient`) to prevent ISP remote management and automatic firmware upgrades.

## Compatibility / Verification Status
- **Warning**: "Any Firmware After 2021 is fully dependent on TR069 for essential services like dimclient. Don't disable Tr069 on them or your router will be bricked." — legacy repository claim.
- Not reverified in this fork — treat as high-risk experimental.
- JCOW411 R2.3: TR-069 client exists but dependency level unverified.

## Risk
- **Potential brick** — newer firmwares may require `dimclient` for boot-time services (DHCP, voice, etc.).
- ISP loses remote management; no automatic firmware updates.
- May break VoIP, TR-069-provisioned services, and ACS connectivity.

## Prerequisites
- Root Telnet access.
- Backup of original `/pfrm2.0/bin/dimclient`.
- Recovery plan (serial/UART).

## Procedure
1. Gain root access (see [Get Root Access](get-root-access-jf-ont.md)).
2. Backup original:
   ```bash
   cp /pfrm2.0/bin/dimclient /pfrm2.0/bin/dimclient.bak
   ```
3. Create replacement script (stub that exits cleanly):
   ```bash
   cat > /pfrm2.0/bin/dimclient << 'EOF'
   #!/bin/sh
   # TR-069 client disabled
   exit 0
   EOF
   ```
4. Make executable:
   ```bash
   chmod +x /pfrm2.0/bin/dimclient
   ```
5. Verify: `cat /pfrm2.0/bin/dimclient`.

## Validation
- `ps | grep dimclient` shows stub running (or not running).
- No TR-069 traffic to ACS in packet capture.
- Router still boots and provides LAN/WAN.

## Rollback / Recovery
- Restore original: `cp /pfrm2.0/bin/dimclient.bak /pfrm2.0/bin/dimclient`.
- If brick: hardware recovery via UART with stock firmware.

## Troubleshooting
- Router fails to boot — restore `dimclient.bak` immediately via serial.
- Services stop working — TR-069 was provisioning them; re-enable or manually configure.
- Auto-upgrade still occurs — check if `UPGRADE_PROGRAM` in `/tmp/system.db` points elsewhere.