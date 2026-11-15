# Encrypt Configuration File

## Purpose
Re-encrypt a modified Lua configuration file back to the vendor `.enc` format using AES-128-CBC with SHA-256 key derivation.

## Compatibility / Verification Status
- Verified on JCOW411 R2.3 with vendor `server.key`.
- JCOW404 and other firmware: untested in this fork.
- Restored backup filename must match vendor pattern: `<serial>_<model>.enc`.

## Risk
- Encrypted output contains sensitive credentials — store only in ignored `artifacts/`.
- Incorrect encryption or wrong filename will cause restore to fail.

## Prerequisites
- `openssl` on `PATH`.
- Decrypted Lua config (e.g., from `artifacts/config/cfg.txt`).
- Key file (`server.key`) or known hex key.

## Procedure
```bash
openssl aes-128-cbc -pass file:server.key -md sha256 \
  -in artifacts/config/cfg.txt \
  -out artifacts/config/RSTXXXXXXX_JCOW411_MODIFIED.enc
```
- The output filename must follow the pattern `<serial>_<model>.enc` for the router to accept it.

## Validation
- Router Maintenance → Backup/Restore accepts the file without error.
- After restore, Telnet/root access works as intended.

## Rollback / Recovery
- Keep the original `.enc` backup in `artifacts/router-backups/`.
- If restore fails, reflash stock firmware via recovery mode.

## Troubleshooting
- "bad decrypt" — wrong key or corrupted input.
- Restore rejected — filename pattern mismatch; rename to `<serial>_<model>.enc`.
- Config restored but no Telnet — verify first line is exactly `config.userdb = {} ...` with no line breaks.