# Capture Firmware Upgrade Link

## Purpose
Intercept the firmware upgrade process to capture the download URL and firmware files for offline analysis.

## Compatibility / Verification Status
- Legacy repository claim; paired scripts `firmware.sh` / `firmd.sh` exist.
- Not reverified in this fork — treat as experimental.
- Requires root access and TR-069 client (`dimclient`) active.

## Risk
- Intercepts ISP firmware delivery; may prevent automatic updates.
- Firmware files are large (~66 MB); ensure `/flash2` has space.
- Modifying upgrade path can brick device if interrupted.

## Prerequisites
- Root Telnet access.
- `/flash2` directory exists or can be created.

## Procedure
1. Ensure `/flash2` exists:
   ```bash
   mkdir -p /flash2
   ```

2. Deploy `firmd.sh` to replace `UPGRADE_PROGRAM` in `/tmp/system.db`:
   ```bash
   sqlite3 "/tmp/system.db" "UPDATE environment SET value = '/flash2/firmware.sh' WHERE name = 'UPGRADE_PROGRAM';"
   ```

3. Place `firmware.sh` in `/flash2/` (see `src/scripts/firmware.sh`).

4. Trigger firmware check from web UI or wait for TR-069 check-in.

5. Captured files appear in `/flash2/firmd/<timestamp>/` including `tr69*` request/response files.

## Validation
- Check `/flash2/firmd/firmd.log` for captured arguments and environment.
- Verify firmware URL and signature file are logged.

## Rollback / Recovery
- Restore original `UPGRADE_PROGRAM` value in `/tmp/system.db`.
- Remove `/flash2/firmd/` directory.
- Reboot to re-enable normal upgrade path.

## Troubleshooting
- No files captured — `dimclient` may not be checking for upgrades.
- `sqlite3` not found — install or use alternative method to edit `system.db`.
- Upgrade fails — restore original `UPGRADE_PROGRAM` immediately.