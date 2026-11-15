# Run NextDNS on Router

## Purpose
Run NextDNS daemon on the router for network-wide DNS filtering and ad blocking.

## Compatibility / Verification Status
- Legacy repository claim; script `nextdns.sh` exists in `src/scripts/`.
- Not reverified in this fork — treat as experimental.
- Requires NextDNS binary compiled for router architecture (likely MIPS/ARM).

## Risk
- Rewrites `/etc/resolv/resolv.conf.IF1` in a loop; may conflict with vendor DNS.
- Daemon runs as root; binary must be trusted.
- Profile ID required for personalized filtering.

## Prerequisites
- Root Telnet access.
- NextDNS binary for router architecture (place in `/flash/nextdns`).
- NextDNS account and Profile ID.

## Procedure
1. Download/copy NextDNS binary to router:
   ```bash
   cd /flash
   wget --no-check-certificate <nextdns-binary-url>
   chmod +x nextdns
   ```

2. Edit `src/scripts/nextdns.sh` — replace `YOUR PROFILE ID` with your actual Profile ID.

3. Deploy script to router and run:
   ```bash
   sh /flash/nextdns.sh
   ```

4. Script runs two background loops:
   - DNS override loop: forces `nameserver 127.0.0.1` every 10s.
   - Supervisor loop: restarts `nextdns` daemon if it dies (checks every 15s).

## Validation
- `ps | grep nextdns` shows daemon running.
- `cat /etc/resolv/resolv.conf.IF1` shows `127.0.0.1`.
- DNS queries from LAN clients go through NextDNS (check NextDNS logs).

## Rollback / Recovery
- Kill loops: `pkill -f nextdns.sh`.
- Restore resolv.conf: vendor DHCP client should repopulate on lease renewal.
- Reboot router to clear all.

## Troubleshooting
- "No such file" — binary architecture mismatch; compile for router.
- DNS not filtering — verify Profile ID and that daemon is running.
- Conflicts with vendor IPv6 DNS — script only overrides IPv4 resolv.conf.