# Decrypt Configuration File

## Purpose
Decrypt a Jio ONT configuration backup (`.enc`) to a Lua configuration file using the known AES-128-CBC key derivation with SHA-256 digest.

## Compatibility / Verification Status
- Verified on JCOW411 R2.3 with vendor `server.key`.
- JCOW404 and other firmware versions: untested in this fork.
- Requires the correct 128-bit key (hex) or the vendor key file.

## Risk
- Decrypted configuration contains Wi-Fi PSKs, TR-069 credentials, and device identifiers.
- Output must go to ignored `artifacts/config/` — never commit decrypted configs.

## Prerequisites
- Python 3 with `openssl` on `PATH`.
- Encrypted backup file (e.g., `RSTXXXXXXX_JCXXXXX.enc`).
- Key file (`server.key`) or known hex key.

## Procedure
```bash
python src/crypto/config_decrypt.py backup.enc --key-file server.key
```
- Output defaults to `artifacts/config/cfg.txt`.
- Custom output directory: `--output-dir artifacts/my-config`.

## Validation
- Decrypted file starts with `config.userdb = {}`.
- File size is non-trivial (several KB).

## Rollback / Recovery
- Original `.enc` backup is unchanged.
- Re-encrypt with `src/crypto/encrypt-config.py` (see encrypt guide) if you modified the decrypted file.

## Troubleshooting
- "backup and key file must both exist" — check paths.
- "decrypted file is not the expected Lua configuration" — wrong key or corrupt backup.
- "OpenSSL failed" — verify `openssl` is installed and the key file is valid.