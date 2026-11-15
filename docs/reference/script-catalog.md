# Script catalog

| Script | Status | Notes |
|---|---|---|
| `repeater.sh` | Verified template | JCOW411 R2.3; fill placeholders; see repeater guide. |
| `firmware.sh` / `firmd.sh` | Experimental | Intercepts upgrade handling; preserve logs and firmware recovery first. |
| `force.sh` | Legacy utility | Creates the firmware-check result path; retain until device behavior is verified. |
| `service.sh` | High risk legacy | Reopens Telnet and resets root credentials repeatedly; do not run unchanged. |
| `ftp.sh` | High risk | Exposes root FTP; use only on an isolated LAN and stop it afterward. |
| `nextdns.sh`, `agh2.sh` | Experimental | Rewrite resolver state in loops; verify DNS and rollback before persistence. |
| `softreset.sh` | Destructive | Deletes router state; use only with a tested recovery plan. |
| `wpa3.sh` | Experimental | Edits temporary hostapd files and restarts Wi-Fi. |
