# JCOW411 Next-Gen WISP Repeater & Web Dashboard (Repeater-NG)

A modern, config-driven WISP repeater engine, Lua CGI backend, and responsive web dashboard designed for the Jio JCOW411 (TeamF1 / Broadcom BCA 17.10 firmware on Linux 4.1.52).

---

## 1. System Architecture

The JCOW411 features two independent Broadcom physical radios. The architecture separates their roles to eliminate driver conflicts and prevent radio loopback:

```text
 Upstream Wi-Fi                                           Local Devices (Room B)
 (e.g. 2.4GHz AP)                                         (Phones, Laptops, TVs)
       │                                                            ▲
       ▼                                                            │
┌──────────────┐     ┌────────────────────────────────┐     ┌──────────────┐
│  Radio: wl0  │ ──> │ NAT / IPTABLES / DHCP / ROUTE  │ ──> │  Radio: wl1  │
│ 2.4GHz Client│     │ Subnet: 192.168.29.1/24 (bdg2) │     │ 5GHz AC AP   │
└──────────────┘     └────────────────────────────────┘     └──────────────┘
                                     │
                                     ▼
                            ┌──────────────────┐
                            │ Ethernet / LAN   │
                            │ Ports 1-4 (bdg2) │
                            └──────────────────┘
```

- **`wl0` (2.4 GHz)**: Dedicated strictly as the **Upstream Station** (`wpa_supplicant`). Local APs and virtual BSS interfaces (`wl0.1`, `wl0.2`) on this radio are completely suppressed.
- **`wl1` (5 GHz)**: Dedicated strictly as the **Local Access Point** (`hostapd`). Broadcasts high-speed 802.11ac Wi-Fi for local devices.
- **`bdg2`**: Internal LAN bridge managing wired Ethernet clients and the local 5GHz Wi-Fi AP.

---

## 2. Directory Layout & Components

| Component | Path on Router | Repo Source Path | Purpose |
|---|---|---|---|
| **JSON Config** | `/pfrm2.0/etc/repeater_config.json` | `src/repeater-ng/engine/repeater_config.json` | Persistent store for upstream and AP settings |
| **Engine** | `/pfrm2.0/bin/repeater_engine.sh` | `src/repeater-ng/engine/repeater_engine.sh` | Bounded connection loop, DHCP, NAT & firewall |
| **Config Helper** | `/pfrm2.0/bin/config_env.lua` | `src/repeater-ng/engine/config_env.lua` | Translates JSON config to shell variables |
| **JSON Parser** | `/pfrm2.0/bin/tiny_json.lua` | `src/repeater-ng/engine/tiny_json.lua` | Pure-Lua 5.1 JSON encoder/decoder |
| **Watchdog** | `/pfrm2.0/bin/watchdog.sh` | `src/repeater-ng/engine/watchdog.sh` | Gateway ping watchdog with self-healing |
| **Status API** | `/pfrm2.0/var/www/cgi-bin/api_status.cgi` | `src/repeater-ng/api/api_status.lua` | Real-time upstream signal, route, and clients |
| **Scan API** | `/pfrm2.0/var/www/cgi-bin/api_scan.cgi` | `src/repeater-ng/api/api_scan.lua` | Scans 2.4GHz spectrum without own-MAC pollution |
| **Connect API** | `/pfrm2.0/var/www/cgi-bin/api_connect.cgi` | `src/repeater-ng/api/api_connect.lua` | Persists credentials and initiates uplink |
| **AP Config API** | `/pfrm2.0/var/www/cgi-bin/api_ap_config.cgi` | `src/repeater-ng/api/api_ap_config.lua` | Reconfigures 5GHz AP without disturbing wl0 |
| **Dashboard** | `/pfrm2.0/var/www/custom/index.html` | `src/repeater-ng/web/index.html` | Tailwind CSS SPA with client-side PBKDF2 |
| **Deployer** | `/tmp/deploy.sh` | `src/repeater-ng/deploy.sh` | Single-script deployment & lighttpd patcher |

---

## 3. Installation & Deployment Guide

### Prerequisites
1. Router rooted on **R2.3 firmware** with Telnet enabled.
2. PC connected to router via Ethernet (`192.168.29.184`).
3. HTTP file server running on host PC:
   ```cmd
   python -m http.server 8000
   ```

### Step 1: Automated Deployment
In the Telnet session on the router, execute:
```sh
cd /tmp
wget http://192.168.29.184:8000/src/repeater-ng/deploy.sh -O deploy.sh
sed -i 's/\r$//' deploy.sh
chmod +x deploy.sh
sh deploy.sh
```

### Step 2: Install Core Files
```sh
# Engine & Config
cd /pfrm2.0/bin
wget http://192.168.29.184:8000/src/repeater-ng/engine/tiny_json.lua -O tiny_json.lua
wget http://192.168.29.184:8000/src/repeater-ng/engine/config_env.lua -O config_env.lua
wget http://192.168.29.184:8000/src/repeater-ng/engine/repeater_engine.sh -O repeater_engine.sh
wget http://192.168.29.184:8000/src/repeater-ng/engine/watchdog.sh -O watchdog.sh
chmod +x repeater_engine.sh watchdog.sh

# CGI Endpoints
cd /pfrm2.0/var/www/cgi-bin
for f in api_status api_scan api_connect api_ap_config; do
  wget "http://192.168.29.184:8000/src/repeater-ng/api/${f}.cgi" -O "${f}.cgi"
  wget "http://192.168.29.184:8000/src/repeater-ng/api/${f}.lua" -O "/pfrm2.0/bin/${f}.lua"
  chmod +x "${f}.cgi"
done

# Frontend UI
cd /pfrm2.0/var/www/custom
wget http://192.168.29.184:8000/src/repeater-ng/web/index.html -O index.html

# Normalize line endings
sed -i 's/\r$//' /pfrm2.0/bin/*.lua /pfrm2.0/bin/*.sh /pfrm2.0/var/www/cgi-bin/*.cgi /pfrm2.0/var/www/custom/index.html
```

---

## 4. Web UI Usage

Access the dashboard in your web browser:
```
http://192.168.29.1/custom/index.html
```
- **Login Credentials**: Username: `admin` | Password: `admin123`

### Tab Features:
1. **Overview & Connected Devices**:
   - Real-time uplink status (SSID, BSSID, RSSI, Gateway ping status).
   - Local 5GHz Wi-Fi status and client counts.
   - Active connected devices table distinguishing `5GHz Wi-Fi` (📱) from `Ethernet / LAN` (💻) with hostnames from DHCP leases.
2. **Upstream Repeater Tab**:
   - **Spectrum Survey**: Click **Survey Spectrum** to scan nearby 2.4GHz networks. Click any network to auto-fill the connection form.
   - **Connect Form**: Enter passphrase and click **Initiate Uplink Connection**. The 64-hex WPA PSK is computed client-side in pure JS without server overhead.
3. **Local Wi-Fi AP Tab**:
   - Customize 5GHz SSID, hide broadcast, or update WPA2 password.
   - **Wi-Fi QR Code**: Click **Show 5GHz Wi-Fi QR Code** to display a scannable QR code for instant mobile phone connection.

---

## 5. API Reference

All endpoints run as standard CGI scripts under `/cgi-bin/` and output JSON with `Content-Type: application/json`.

### `GET /cgi-bin/api_status.cgi`
Returns system status, upstream link state, AP status, and active client list.
```json
{
  "status": "success",
  "data": {
    "upstream": {
      "state": "COMPLETED",
      "ssid": "HomeNetwork_2.4G",
      "bssid": "C4:9A:31:5F:39:FE",
      "ip": "192.168.1.11",
      "rssi": -62,
      "gateway_online": true
    },
    "local_ap_5g": {
      "iface": "wl1",
      "ssid": "JioFiber-8Pyla_5G",
      "hidden": false,
      "connected_client_count": 1
    },
    "active_clients": [
      {
        "mac": "82:B4:02:36:8C:21",
        "ip": "192.168.29.178",
        "hostname": "Android-Phone",
        "band": "5GHz"
      }
    ]
  }
}
```

### `GET /cgi-bin/api_scan.cgi`
Triggers `wl -i wl0 scan` and returns 2.4GHz networks sorted by signal.
```json
{
  "status": "success",
  "count": 12,
  "networks": [
    {
      "ssid": "HomeNetwork_2.4G",
      "bssid": "C4:9A:31:5F:39:FE",
      "rssi": -61,
      "channel": "6",
      "security": "WPA2-PSK"
    }
  ]
}
```

### `POST /cgi-bin/api_connect.cgi`
Initiates connection to upstream AP.
- **Payload**:
  ```json
  {
    "ssid": "TargetNetwork",
    "bssid": "AA:BB:CC:DD:EE:FF",
    "psk_hex": "<64-hex-characters>",
    "raw_password": "PlaintextPassword"
  }
  ```

### `POST /cgi-bin/api_ap_config.cgi`
Updates local 5GHz AP settings.
- **Payload**:
  ```json
  {
    "ssid": "NewSSID",
    "passphrase": "NewPassword123",
    "hidden": false
  }
  ```

---

## 6. Operational & Security Checklist

- [x] **No Hardcoded Plaintext Secrets**: Template `repeater_config.json` uses dummy placeholders.
- [x] **Input Sanitization**: All shell parameters in Lua CGIs are stripped of command-injection meta-characters (`"`, `\`, `` ` ``, `$`, `/`, `&`).
- [x] **No Broadcom Loopbacks**: `wl0` is isolated to station mode; local AP is hosted exclusively on `wl1`.
- [x] **Pure JS PBKDF2**: Client-side PSK computation works seamlessly on both HTTP and HTTPS.
- [x] **Persistence Verified**: Boot survivability hooked through `/pfrm2.0/etc/userInit`.
