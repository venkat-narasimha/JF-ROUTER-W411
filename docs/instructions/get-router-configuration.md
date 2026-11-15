# Get Router Configuration Backup

## Purpose
Download the encrypted configuration backup from the router web UI for offline decryption and analysis.

## Compatibility / Verification Status
- Verified on JCOW411 R2.3 web UI.
- JCOW404 and other firmware: likely compatible but unverified in this fork.
- Web UI path: Administrator → Maintenance → Backup.

## Risk
- Backup file (`.enc`) contains encrypted Wi-Fi PSKs, TR-069 credentials, and device identifiers.
- Store only in ignored `artifacts/router-backups/` — never commit to Git.

## Prerequisites
- Router web UI accessible at `http://192.168.29.1`.
- Admin credentials (default: `admin` / `Jiocentrum`).

## Procedure
1. Open browser dev tools (F12) on the Maintenance page.
2. In Console, paste the contents of `src/scripts/backup-restore.js` (or equivalent) to enable the backup button if hidden.
3. Go to **Administrator → Maintenance** and click **Backup**.
4. Save the downloaded file as `artifacts/router-backups/RSTXXXXXXX_JCXXXXX.enc`.
5. Proceed to [Decrypt Configuration File](decrypt-config-file.md).

## Validation
- File has `.enc` extension and non-zero size (typically 50–100 KB).
- Filename follows pattern `RST<serial>_JC<model>.enc`.

## Rollback / Recovery
- This is a read-only operation; no router state is modified.
- Keep the original `.enc` as your recovery anchor.

## Troubleshooting
- Backup button missing — run the console script from step 2.
- Download fails — check browser popup blocker and router connectivity.
- File is 0 bytes — router may have no configuration to export; try after a configuration change.