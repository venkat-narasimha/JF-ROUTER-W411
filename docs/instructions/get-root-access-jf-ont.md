# Get Root Access (Telnet)

## Purpose
Enable persistent root Telnet access on Jio Fiber ONT by modifying and restoring the configuration backup.

## Compatibility / Verification Status
- Verified on JCOW411 R2.3.
- JCOW404 and newer firmwares (3.10+): legacy repository claims only; not reverified here.
- Uses vendor configuration-restore path, not a generic exploit.

## Risk
- Modifies router configuration; incorrect payload can brick the device.
- Root password is set in the payload — use a strong password.
- Persistence survives reboot via `customInit` hook on verified firmware.

## Prerequisites
- Encrypted configuration backup (see [Get Router Configuration](get-router-configuration.md)).
- Key file (`server.key`) for decryption/re-encryption.
- Python 3 with `openssl` on `PATH`.
- Wired Ethernet access to router (Telnet is LAN-only).

## Procedure
1. Decrypt the backup:
   ```bash
   python src/crypto/config_decrypt.py artifacts/router-backups/RSTXXXXXXX_JCXXXXX.enc \
     --key-file server.key
   ```
   Output: `artifacts/config/cfg.txt`.

2. Edit `artifacts/config/cfg.txt` — replace the first line with:
   ```
   config.userdb = {} os.execute("/usr/sbin/telnetd"); os.execute("/pfrm2.0/bin/iptables -I fwInBypass -p tcp --dport 23 -m ifgroup --ifgroup-in 0x1/0x1 -j ACCEPT"); os.execute("echo -e \"YOUR_PASSWORD\nYOUR_PASSWORD\" | passwd root");
   ```
   - Must be a single line, no line breaks.
   - Replace `YOUR_PASSWORD` with a strong password.

3. Re-encrypt:
   ```bash
   openssl aes-128-cbc -pass file:server.key -md sha256 \
     -in artifacts/config/cfg.txt \
     -out artifacts/router-backups/RSTXXXXXXX_JCOW411_MODIFIED.enc
   ```
   - Filename must match `<serial>_<model>.enc` pattern.

4. Restore via web UI: **Administrator → Maintenance → Restore** using the modified `.enc`.

5. Connect via Telnet:
   ```bash
   telnet 192.168.29.1
   ```
   Login: `root` / `YOUR_PASSWORD`.

6. For persistence across reboots, install the `customInit` script (see [Run Custom Scripts](run-custom-scripts-on-your-router.md)).

## Validation
- Telnet connects and drops to root shell.
- `iptables -L fwInBypass` shows the ACCEPT rule for port 23.
- After reboot, Telnet still works.

## Rollback / Recovery
- Restore the original unmodified `.enc` backup from `artifacts/router-backups/`.
- If Telnet fails but web UI works, repeat with corrected payload.
- If web UI is inaccessible, use hardware recovery (serial/UART or firmware reflash).

## Troubleshooting
- "Invalid backup" on restore — filename pattern mismatch; rename to `<serial>_<model>.enc`.
- Telnet connects but no shell — payload syntax error; verify single-line format.
- Password not accepted — re-check the `echo -e` escape sequence in the payload.
- Telnet disabled after reboot — `customInit` not installed or `telnetDisableACS` file present; remove `/flash/telnetDisableACS`.