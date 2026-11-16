# JCOW411 repeater work — timeline and current state

This is a factual record of the work described in `chat-Unlock Jio Router.txt`.
It is deliberately more cautious than the chat: an observation is recorded as
**confirmed** only when the user supplied a command result, log, or successful
end-to-end test. Explanations that were proposed but not proved are labelled
**hypothesis**. Secrets, session cookies, router serials, and Wi-Fi credentials
are intentionally omitted.

## Objective

Reuse an old Jio JCOW411 as a wireless client/router for a Wi-Fi network that
is strong in Room A but weak in Room B. The desired layout is:

```text
friend's Wi-Fi  <-  wl0 (2.4 GHz station/uplink)  JCOW411  ->  LAN / wl1 AP
                                                              devices in Room B
```

The source Wi-Fi router is not under the user's control, so WDS is not a
viable option. The plan is routed repeater/WISP-style operation: wl0 obtains
an address from the upstream network and the JCOW411 NATs traffic for its own
LAN clients. It is not a transparent wireless bridge.

## 1. Initial assessment and root-access work

1. The work started with the stock JCOW411 firmware, whose web interface does
   not expose a generic wireless-client/repeater mode.
2. Early discussion considered OpenWrt, a config-backup modification path, and
   a command-injection path. OpenWrt was not treated as a safe solution: there
   was no verified, device-specific, recoverable image in the conversation.
3. The initial firmware was `ARCNTF1_JCOW411_R3.13`. The repository's
   config-decrypt workflow did not yield a usable plaintext configuration on
   that version; the decrypted output appeared binary/structured rather than
   the expected editable Lua text.
4. The exploit path did open Telnet on R3.13, proving that code execution/root
   access was possible. The password-setting portion was unreliable, so the
   first Telnet login required investigation rather than assuming the supplied
   password had been installed.
5. A root shell was eventually obtained. This was an important checkpoint:
   the device itself, rather than guesses about its web UI, could now be
   inspected.

## 2. Firmware downgrade to R2.3

1. R3.13 exposed an unavailable station-configuration function and was a poor
   target for repeatable configuration work.
2. The selected older image was `ARCNTF1_JCOW411_R2.3.img` with its matching
   signature file. The normal upload page initially reported that the firmware
   was invalid or corrupted, despite the image being a complete roughly
   66 MB download.
3. The downgrade ultimately completed. The router's dashboard and sidebar
   showed `ARCNTF1_JCOW411_R2.3`; an earlier claim that it was still on R3.13
   was corrected as a stale-output mistake.
4. R2.3 did not magically make every exported file plaintext. The important
   breakthrough was offline firmware extraction: the R2.3 root filesystem and
   its backup/restore implementation were inspected directly.
5. That inspection identified the vendor `server.key` and the backup import
   path. A locally modified configuration was encrypted successfully and a
   round-trip check matched the original format.
6. Restore still failed until the backup filename followed the vendor pattern
   `<device-serial>_<model>.enc`. With the expected filename, the modified
   backup was accepted.
7. **Confirmed result:** restoring that correctly named, encrypted backup gave
   root access on R2.3. This was a vendor-format/configuration route, not a
   claim that a generic downgrade exploit was sufficient.

## 3. Persistent administrative access

1. The boot sequence was examined and `/pfrm2.0/etc/platformInit` was found to
   invoke `userInit`.
2. `userInit` was used as the persistence hook for Telnet, its firewall allow
   rule, and the root-password setup. The writable UBIFS filesystem preserved
   these edits.
3. **Confirmed result:** Telnet survived reboots at several later checkpoints.
   Therefore the persistence hook itself works.
4. At one point Telnet disappeared after DHCP-related activity. Source/log
   investigation tied this to vendor Telnet handling rather than loss of root.
   Access was recovered, including a MAC-address workaround that caused the
   vendor hook to re-enable Telnet.

## 4. Hardware and driver reconnaissance

Early advice assumed an EcoNet/MediaTek-like platform and suggested `apcli0`
and `iwpriv`. That was wrong for this unit and should not be repeated.

The later device evidence established the following:

| Item | Confirmed finding |
|---|---|
| Firmware family | Broadcom BCA `17.10 RC99.39 (r789005)` |
| 2.4 GHz radio | `wl0` |
| 5 GHz radio | `wl1` |
| LAN bridge | `bdg2` |
| Driver stack | proprietary `wl`/`dhd` alongside `cfg80211`/`wl_evt_driver` |
| Client capability | `wl -i wl0 cap` included `sta` |
| Upstream discovery | native `wl -i wl0 scan` found the friend's 2.4 GHz network |

The upstream network was seen on channel 9 at usable signal strength and was
identified as WPA2-PSK/AES. Its SSID, BSSID, and passphrase are not recorded
here.

## 5. Choosing the connection mechanism

1. The vendor helper `/pfrm2.0/bin/dot11SetSTAConfig` reported
   `functionality is unavailable`; it could not configure client mode.
2. Direct `wl` commands could switch wl0 toward station mode, but the driver's
   key-management iovars were not usable for this network:
   `set_pmk` was unsupported and `wpa_psk` did not accept the intended value.
3. The router contained `wpa_supplicant`, `wpa_cli`, and `nas`. Testing showed
   that the usable supplicant backend was `nl80211`; the expected Broadcom/wext
   alternatives were not available.
4. The WPA passphrase was converted locally into the required 64-hex PSK and
   independently checked against PBKDF2-SHA1. The actual credential is omitted
   from this document.
5. A `wpa_supplicant` configuration for wl0 was created. This platform has a
   quirk where merely starting the supplicant can leave the network disabled;
   explicit `wpa_cli enable_network`, `select_network`, and `reassociate`
   commands were needed.

## 6. First complete manual repeater success

The working manual sequence was established while logged in as root:

1. Stop or neutralize conflicting wireless-management processes as needed.
2. Put wl0 in station mode and run `wpa_supplicant` with the `nl80211` backend.
3. Remove wl0 from `bdg2` for the actual association/routing setup.
4. Explicitly enable, select, and reassociate the configured network.
5. Wait for `wpa_state=COMPLETED`.
6. Run `udhcpc` on wl0. It obtained an upstream `192.168.1.x` lease and a
   `192.168.1.1` gateway in the successful run.
7. Enable IPv4 forwarding and add NAT (`MASQUERADE`) plus forwarding rules
   between `bdg2` and wl0.
8. Deal with DNS/IPv6 interference. Vendor IPv6 services were handing clients
   an unusable DNS path, so the test configuration used an explicit IPv4 DNS
   handling rule and stopped the conflicting IPv6 daemons.

**Confirmed end-to-end result:** a Room B client behind the JCOW411 could
reach the internet. The traceroute showed the expected path through
`192.168.29.1` (the JCOW411), then the upstream `192.168.1.1`, then the
provider network.

An important test correction occurred here: the laptop initially had both its
own Wi-Fi and Ethernet connected, which could create false positive results.
Later tests disabled the laptop's Wi-Fi so that success was attributable to
the JCOW411 Ethernet/LAN path.

## 7. Making the configuration persistent

1. A dedicated `/pfrm2.0/etc/repeater.sh` script was created and invoked from
   `userInit` after a boot delay.
2. The first persistence attempts did not maintain connectivity after reboot,
   even though Telnet persistence still worked.
3. Logs proved that the boot hook did launch the repeater script. The problem
   is therefore in radio/supplicant association at boot, not script discovery
   or filesystem persistence.
4. `dot11d` and `easyMeshd` were identified as processes that can reclaim wl0
   for AP operation. Scripts were updated to terminate them (often twice, with
   a delay) before starting station setup.
5. A reported `wl -i wl0 radio` value of `0x0000` initially looked like the
   main failure. This was later shown to be an unreliable stand-alone signal:
   native `wl` scans could still work in states reported that way. It should
   not be treated as sufficient proof that the radio is unusable.

## 8. Boot-time scan/association investigation

The unresolved work focuses on a difference between manual and boot-time
`wpa_supplicant` behavior.

### Evidence from a successful manual supplicant scan

One successful log included all of the following:

- wl0 was attached to bridge `bdg2` (`master=15`);
- the supplicant noticed that bridge interface;
- its `nl80211` scan request returned success (`ret=0`);
- scan results were received; and
- another log line showed that network selection had to be explicitly
  re-enabled because all networks were disabled.

The successful manual sequence ultimately removed wl0 from the bridge before
the completed association and routing setup.

### Evidence from failing boot runs

- Native `wl` scanning could see the upstream network after boot, so the
  hardware radio and reception are not the general blocker.
- The `nl80211` scan issued by `wpa_supplicant` failed at boot with
  `ret=-95` (`EOPNOTSUPP`) in at least one run.
- A later script attempted to keep or explicitly add wl0 to `bdg2` before
  starting the supplicant, then remove it before association.
- The most recent log still showed empty `wpa_cli scan_results`, followed by
  `wpa_state=DISCONNECTED` after the retry loop. It did not reach DHCP or NAT.

### Resolution: direct association with `ap_scan=2`

The bridge-membership explanation was disproved: wl0 was already a `bdg2`
member before a failing `nl80211` scan, and explicitly adding it again made no
difference. A direct native `wl` scan did find the upstream AP at about
-59 dBm, while the supplicant's scan continued to fail with `-95`.

The working workaround is a `wpa_supplicant` configuration with:

- `ap_scan=2`;
- the known upstream BSSID pinned in the network block; and
- the existing WPA2-PSK configuration.

This avoids the broken supplicant-driven `nl80211` scan. A temporary test
reached `wpa_state=COMPLETED`, completed the four-way WPA handshake, obtained
the expected DHCP lease, and reached the internet.

## 9. Final boot-race diagnosis and solution

1. The first persistent `ap_scan=2` script initially failed before it started
   Wi-Fi because this BusyBox image does not provide the `head` applet. The
   script used `head -n 1` while retrieving the PSK line from its backup; that
   produced an empty PSK variable. Removing that unsupported command fixed the
   script's compatibility bug.
2. A live run of the repaired script then associated, received the DHCP lease,
   installed the default route, and routed the laptop successfully.
3. After a cold reboot, association and DHCP could still succeed while the
   actual Wi-Fi data path was unusable. The router itself could not ping its
   gateway (`192.168.1.1`), and the gateway ARP entry stayed incomplete
   (`Flags 0x0`). This proved the laptop, NAT, and LAN forwarding were not the
   cause.
4. A clean wl0/supplicant/DHCP reinitialization performed later in the same
   boot restored the gateway ARP entry (`Flags 0x2`) and restored router and
   laptop internet access. The exact vendor service responsible for the early
   boot race was not identified, but the behavior was reproduced and handled.
5. The final `repeater.sh` now waits for vendor startup, then performs up to
   four complete connection attempts. Each attempt resets wl0's client stack,
   uses `ap_scan=2` with the pinned BSSID, obtains DHCP, and verifies the
   upstream gateway before installing forwarding/NAT/DNS rules. A failed
   gateway check causes a delayed retry rather than a false success.
6. **Confirmed cold-boot result:** the first automatic attempt associated,
   obtained `192.168.1.11`, reached the upstream gateway, completed the script,
   and restored laptop internet over Ethernet. Laptop traceroute again began:

   ```text
   192.168.29.1  ->  192.168.1.1  ->  upstream provider
   ```

## 10. Local recovery copies

The active script and its two prior versions were copied from the router to:

```text
artifacts/router-backups/
```

The files are `repeater.sh`, `repeater.sh.oneshot.bak`, and
`repeater.sh.apscan1.bak`. The repository ignores `artifacts/`, which is
required because these scripts contain the upstream Wi-Fi credential.

## 11. Decoupled Next-Gen Architecture & Web UI (Repeater-NG)

To transition from brittle hardcoded shell scripts to a robust, user-configurable system, the repeater functionality was re-architected into a modular engine with a lightweight JSON configuration store, a Lua CGI backend, and a modern web dashboard.

1. **Configuration Store Decoupling (`repeater_config.json`)**:
   - Upstream Wi-Fi credentials, gateway IP, local AP settings, and watchdog parameters were separated into `/pfrm2.0/etc/repeater_config.json`.
   - A shell environment exporter (`/pfrm2.0/bin/config_env.lua`) was developed to safely parse the JSON config and provide environment variables for the engine without shell injection vulnerabilities.
   - **Confirmed result:** The decoupled engine (`repeater_engine.sh`) reads dynamic JSON config, discovers target BSSIDs via targeted scans, associates with the upstream AP, obtains DHCP (`192.168.1.11`), establishes NAT/iptables rules, and provides seamless internet access.

2. **Lua 5.1 Compatibility & Pure Lua JSON Parser (`tiny_json.lua`)**:
   - The stock TeamF1 vendor library (`/pfrm2.0/lib/lua/teamf1lualib/json.lua`) relied on Lua 5.2 `load()` behavior with string arguments, causing fatal runtime exceptions (`bad argument #1 to 'load' (function expected, got string)`) on the router's Lua 5.1 runtime.
   - A standalone, dependency-free JSON encoder/decoder (`tiny_json.lua`) was written and deployed to `/pfrm2.0/bin/` and `/pfrm2.0/share/lua/5.1/`.

3. **Broadcom Radio Allocation & AP Isolation**:
   - **Hardware Constraint:** The JCOW411 contains two physical radios: `wl0` (2.4 GHz) and `wl1` (5 GHz). Testing proved that running `hostapd` or configuring local virtual BSS interfaces (`wl0.2`) on the 2.4 GHz radio destroys `wl0` station mode, breaking the upstream client link and causing self-association loopback.
   - **Architectural Solution:** `wl0` is strictly reserved for the upstream station link. Local Wi-Fi AP broadcasting is exclusively assigned to `wl1` (5 GHz AC/N). Stale virtual AP interfaces (`wl0.1`, `wl0.2`, `wl1.1`, `wl1.2`) and stray 2.4 GHz `hostapd` instances are explicitly suppressed on boot and configuration changes.

4. **Web Server & CGI Integration**:
   - The router runs `lighttpd` with root docroot `/pfrm2.0/var/www` and CGI enabled in `/cgi-bin/`.
   - Stock `lighttpd.conf` blocked `.html` files via `url.access-deny = ( "~", ".inc", ".html" )`. A non-destructive sed patch script removed `.html` from `url.access-deny`, enabling static web apps in `/pfrm2.0/var/www/custom/`.
   - Because standard BusyBox on this build omitted the `printf` applet, CGI header wrappers were migrated to standard `echo` calls.
   - Four REST-like CGI endpoints were deployed to `/pfrm2.0/var/www/cgi-bin/`:
     - `api_status.cgi` / `api_status.lua`: Returns real-time upstream status (SSID, BSSID, RSSI, IP, gateway route reachability), 5 GHz AP configuration, saved profiles, and active connected clients.
     - `api_scan.cgi` / `api_scan.lua`: Triggers `wl -i wl0 scan`, dynamically filters the router's own hardware MACs, and returns detected 2.4 GHz networks sorted by signal strength.
     - `api_connect.cgi` / `api_connect.lua`: Validates inputs, persists credentials into `repeater_config.json`, and asynchronously spawns `repeater_engine.sh`.
     - `api_ap_config.cgi` / `api_ap_config.lua`: Reconfigures `wl1` 5 GHz SSID, WPA2 passphrase, and broadcast visibility without disturbing `wl0`.

5. **Single-Page Web Dashboard (`/custom/index.html`)**:
   - A modern, mobile-responsive SPA was constructed using Tailwind CSS.
   - Includes full-screen authentication gate (`admin` / `admin123`), dark/light theme toggle, and tabbed navigation:
     - **Overview & Connected Devices**: Dual hardware status cards (2.4 GHz Upstream Client and 5 GHz Dedicated AP) and real-time client table.
     - **Upstream Repeater Tab**: Two-column layout with spectrum survey scanner on the left and direct Wi-Fi credential input on the right.
     - **Local Wi-Fi AP Tab**: Two-column layout with 5 GHz SSID/password configuration on the left and instant QR code generator for mobile phones on the right.
   - **Web Crypto & Pure JS PBKDF2 Fallback**: Browsers restrict `window.crypto.subtle` on non-HTTPS origins (e.g. `http://192.168.29.1`). To generate the 64-character hex WPA PSK directly in the user's browser, a pure JS PBKDF2-SHA1 implementation was integrated, ensuring compatibility on both HTTP and HTTPS.

6. **Active Device Classification & Filtering**:
   - Initial device parsing suffered from reading historical DHCP leases from `/var/dhcpd.leases`, causing powered-off devices and upstream network ARP records (`192.168.1.1`) to appear as active clients.
   - Refined `api_status.lua` to only query active kernel ARP entries (`flags == "0x2"`) on bridge `bdg2` within the `192.168.29.x` subnet, while cross-referencing `wl -i wl1 assoclist` for accurate `5GHz Wi-Fi` vs `Ethernet / LAN` badge assignment.

## Current status

| Capability | Status |
|---|---|
| JCOW411 firmware | R2.3 confirmed |
| Root shell & Telnet | confirmed across reboots |
| wl0 station capability | confirmed (2.4 GHz dedicated client) |
| wl1 access point capability | confirmed (5 GHz dedicated AP) |
| Decoupled JSON configuration | confirmed (`/pfrm2.0/etc/repeater_config.json`) |
| Next-Gen repeater engine | confirmed (`repeater_engine.sh` with `tiny_json.lua`) |
| Lighttpd Web UI | confirmed (`/custom/index.html`) |
| Lua CGI endpoints | confirmed (`api_status`, `api_scan`, `api_connect`, `api_ap_config`) |
| Client-side PBKDF2-SHA1 | confirmed (in-browser PSK computation) |
| Connected device monitoring | confirmed (5 GHz Wi-Fi vs Ethernet classification) |
| Automatic recovery after reboot | confirmed with bounded retry loop |

## Current operational notes

- The 2.4 GHz physical radio (`wl0`) must remain dedicated strictly to station mode; do not enable local 2.4 GHz access points or secondary SSIDs on `wl0`.
- The local access point is hosted solely on the 5 GHz radio (`wl1`).
- The web dashboard is accessible at `http://192.168.29.1/custom/index.html` using login credentials `admin` / `admin123`.
- Any template configuration files committed to git (`repeater_config.json`) must contain sanitized dummy placeholders rather than real PSKs or SSIDs.
- The `artifacts/router-backups` files are recovery material and must remain untracked.
