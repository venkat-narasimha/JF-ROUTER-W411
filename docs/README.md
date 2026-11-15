# Documentation index

Use the root [README](../README.md) for project scope. Start with
[safety and recovery](reference/safety-and-recovery.md),
[compatibility](reference/compatibility.md), and the [script catalog](reference/script-catalog.md).

## Guides

- [JCOW411 Wi-Fi repeater](instructions/wifi-repeater-jcow411.md) — verified on R2.3.
- Existing guides below are retained for compatibility but should be treated as
  legacy/experimental until rewritten against a tested device.

---

# Legacy toolkit overview
© 2026 Naitik1208. <br>
All rights reserved.
Advanced modification and control methods for Jio Fiber ONT devices (JCOW404 / JCOW411)
---

## Overview
This repository provides methods to gain deeper control over JF ONT routers.
It consolidates multiple low-level techniques into a single structured resource.

---

## Capabilities

### Core Access
- **Root Access (Telnet)**
  Gain full shell access to the device for system-level control.
  See [Get Root Access](instructions/get-root-access-jf-ont.md).

- **Decrypt Config File**
  Extract and analyze router configuration data.
  See [Decrypt Configuration File](instructions/decrypt-config-file.md).

### System Control
- **Disable TR-069 (Hard Disable)**
  Removes or disables the TR-069 client binary.

  **Effect:**
  - ISP cannot initiate remote management sessions
  - Firmware updates via TR-069 are no longer possible
  - Remote configuration pushes are blocked

  **Persistence:**
  - Remains effective until you manually flash a firmware

  **Implication:**
  - Full local control over device configuration
  - No automatic ISP-side recovery or updates
  See [Disable TR-069](instructions/disable-tr-069.md).

- **Run Custom Scripts**
  Execute persistent scripts to modify router behavior.
  See [Run Custom Scripts](instructions/run-custom-scripts-on-your-router.md).

### File & Storage Access
- **Filesystem Extraction to USB**
  Copy internal router files directly to external storage.
  (Guide pending rewrite; legacy claim only.)

- **Enable FTP Server (Root Access)**
  Access entire filesystem over FTP with `/` as root.
  See [Enable Root FTP](instructions/enable-root-ftp-jf-router.md).

### Firmware Management
- **Firmware Downgrade**
  Revert to older firmware versions for compatibility or exploit access.
  See [Firmware Downgrade](instructions/downgrade-firmware.md).

- **Capture Firmware Upgrade Link**
  Intercept the firmware upgrade process to capture download URLs.
  See [Capture Firmware Link](instructions/capture-jf-firmware-link.md).

### Network Modifications
- **Run NextDNS (Ad Blocking)**
  Apply network-wide DNS-level filtering directly on the router.
  See [Run NextDNS](instructions/run-nextdns.md).

- **JCOW411 Wi-Fi Repeater**
  Routed repeater workflow verified on R2.3.
  See [Wi-Fi Repeater](instructions/wifi-repeater-jcow411.md).

---

## Instructions

1. [Get Router Configuration](instructions/get-router-configuration.md)
2. [Decrypt Configuration File](instructions/decrypt-config-file.md)
3. [Encrypt Configuration File](instructions/encrypt-router-configuration-file.md)
4. [Get Root Access (Telnet)](instructions/get-root-access-jf-ont.md)
5. [Enable Root FTP Access](instructions/enable-root-ftp-jf-router.md)
6. [Run Custom Scripts on Router](instructions/run-custom-scripts-on-your-router.md)
7. [Firmware Downgrade](instructions/downgrade-firmware.md)
8. [Disable TR-069](instructions/disable-tr-069.md)
9. [Capture Firmware Upgrade Link](instructions/capture-jf-firmware-link.md)
10. [Run NextDNS](instructions/run-nextdns.md)
11. [JCOW411 Wi-Fi Repeater](instructions/wifi-repeater-jcow411.md)

---

## Scripts

The `src/scripts/` directory contains reusable scripts for:
- DNS control and overrides (`nextdns.sh`, `agh2.sh`)
- Startup execution hooks (`service.sh`, `firmd.sh`, `firmware.sh`)
- Router behavior modification (`ftp.sh`, `wpa3.sh`, `softreset.sh`, `repeater.sh`)

Refer to the [Script Catalog](reference/script-catalog.md) for status and risk of each.

---

## Tested Devices

- JCOW411 R2.3 — root/config workflow and routed Wi-Fi repeater verified in this fork.
- JCOW404 — legacy repository claim; not reverified here.
- Other firmware — unknown; do not assume instructions apply.

---

## Warning

These methods involve low-level system modifications.

- Incorrect usage may brick your router
- Proceed only if you understand the risks
- Always keep a recovery option available

---

## Notes

- Methods are tested but may break with firmware updates
- Only JCOW411 R2.3 is verified in this fork; all other claims are legacy/experimental
- Real credentials, backups, and router-specific data must stay in ignored `artifacts/`

---

## Contribution

Improvements and additional methods are welcome.

---

## License

**Copyright (c) 2026 Naitik1208. All Rights Reserved.**

This repository and its contents (including firmware, scripts, and documentation) are proprietary.
- **Ownership:** All rights remain with Naitik1208.
- **Usage:** You may view and use this for personal use.
- **Restrictions:** Redistribution, claiming authorship, or creating similar derivative works is strictly prohibited.
- **Contributions:** Pull Requests are welcome, but remain the property of the project owner. See the [LICENSE](../LICENSE) file for full terms.

---

If this repository helped you, consider starring it.