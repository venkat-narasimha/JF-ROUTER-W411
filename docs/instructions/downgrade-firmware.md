# Firmware Downgrade

## Purpose
Flash an older firmware image to the router, typically to reach a version with known root access or configuration-modification paths.

## Compatibility / Verification Status
- Legacy repository claim: "Successfully tested on multiple JCOW404 and JCOW411."
- Not reverified in this fork — treat as experimental.
- **Critical**: JCOW411 R2.3 downgrade was achieved in this fork but via a specific offline extraction + config-restore path, not the generic web UI method described here.

## Risk
- **High brick risk** — wrong image, interrupted flash, or signature mismatch can permanently disable the router.
- TR-069 may auto-upgrade back; disable TR-069 first if persistence needed (see [Disable TR-069](disable-tr-069.md)).
- Some services (JioTV, VoIP) may break until TR-069 re-provisions.

## Prerequisites
- Root Telnet access (see [Get Root Access](get-root-access-jf-ont.md)).
- Correct firmware `.img` and matching `.sig` for your model (JCOW404 or JCOW411).
- Wired Ethernet connection.
- Recovery plan (serial/UART or known-good firmware).

## Procedure
1. Download firmware `.img` and `.sig` to local machine.
2. Enable root FTP (see [Enable Root FTP](enable-root-ftp-jf-router.md)) or use `wget` on router to fetch files to `/tmp/`.
3. On router, create the firmware-check trigger:
   ```bash
   mkdir -p /tmp/firmCheckRes.txt
   ```
4. In web UI: **Administrator → Maintenance → Firmware Upgrade**.
5. Upload `.img` and `.sig` files.
6. Click **Upgrade** and wait for reboot (5–10 minutes).
7. Verify version in web UI dashboard.

## Validation
- Web UI shows target firmware version.
- Root Telnet still works (if persistence was configured).
- LAN/WAN connectivity functional.

## Rollback / Recovery
- If web UI accessible: flash a known-good firmware via same method.
- If bricked: hardware recovery via UART/serial console with bootloader.
- Keep original firmware `.img`/`.sig` in `artifacts/firmware/` for recovery.

## Troubleshooting
- "Invalid firmware" — signature mismatch or wrong model; verify `.sig` matches `.img`.
- Upgrade button disabled — run `mkdir -p /tmp/firmCheckRes.txt` via Telnet first.
- Stuck on reboot > 15 min — power cycle; try recovery firmware.
- Services broken post-downgrade — TR-069 re-provision may fix; or accept as known limitation.