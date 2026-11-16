-- /pfrm2.0/bin/api_status.lua
package.path = "/pfrm2.0/bin/?.lua;/pfrm2.0/share/lua/5.1/?.lua;/pfrm2.0/share/lua/5.1/?/init.lua;" .. package.path
local ok, json = pcall(require, "tiny_json")
if not ok then json = require("teamf1lualib/json") end

local function run_cmd(cmd)
    local h = io.popen(cmd)
    if not h then return "" end
    local res = h:read("*all")
    h:close()
    return res or ""
end

-- 1. Read wpa_supplicant status on wl0
local wpa_out = run_cmd("wpa_cli -i wl0 status 2>/dev/null")
local wpa_state = wpa_out:match("wpa_state=([%w_]+)") or "UNKNOWN"
local wpa_ssid = wpa_out:match('ssid=([^\r\n]+)') or ""
local wpa_bssid = wpa_out:match('bssid=([%x:]+)') or ""
local wpa_ip = wpa_out:match('ip_address=([%d%.]+)') or ""

-- 2. wl0 hardware stats
local wl0_out = run_cmd("wl -i wl0 status 2>/dev/null")
local wl0_rssi = tonumber(wl0_out:match("RSSI:%s*([-%d]+)%s*dBm")) or 0
local wl0_noise = tonumber(wl0_out:match("noise:%s*([-%d]+)%s*dBm")) or 0
local wl0_chan = wl0_out:match("Channel:%s*([%d/]+)") or ""

-- Extract readable SSID from hardware if wpa_cli status is raw/bssid
local hw_ssid = wl0_out:match('SSID:%s*"(.*)"')
if hw_ssid and hw_ssid ~= "" then
    wpa_ssid = hw_ssid
end

-- Fallback IP lookup from ifconfig if wpa_cli omitted it
if wpa_ip == "" then
    local ifc = run_cmd("ifconfig wl0 2>/dev/null")
    wpa_ip = ifc:match("inet addr:([%d%.]+)") or ""
end

-- 3. Local AP status (wl1 for 5GHz)
local wl1_ssid = run_cmd("wl -i wl1 ssid 2>/dev/null"):match('Current SSID:%s*"(.*)"') or ""
local wl1_closed = run_cmd("wl -i wl1 closed 2>/dev/null"):match("(%d+)") == "1"
local wl1_chan = run_cmd("wl -i wl1 status 2>/dev/null"):match("Channel:%s*([%d/]+)") or ""

-- 4. Connected clients on 5GHz AP and DHCP leases
local function get_clients(ifaces)
    local list = {}
    local seen = {}
    for _, iface in ipairs(ifaces) do
        local assoc_out = run_cmd("wl -i " .. iface .. " assoclist 2>/dev/null")
        for mac in assoc_out:gmatch("([%x:]+)") do
            if #mac == 17 then
                local upper_mac = mac:upper()
                if upper_mac ~= wpa_bssid:upper() and not seen[upper_mac] then
                    seen[upper_mac] = true
                    table.insert(list, upper_mac)
                end
            end
        end
    end
    return list
end

local clients_5g = get_clients({"wl1", "wl1.1", "wl1.2"})

-- Parse /proc/net/arp: ONLY include active entries (flags 0x2) on LAN bridge (bdg2) in 192.168.29.x
local arp_table = {}
local arp_out = run_cmd("cat /proc/net/arp 2>/dev/null")
for ip, hw_type, flags, hw, dev in arp_out:gmatch("(%d+%.%d+%.%d+%.%d+)%s+(0x%x+)%s+(0x%x+)%s+([%x:]+)%s+[^%s]+%s+([^%s]+)") do
    if flags == "0x2" and #hw == 17 and hw ~= "00:00:00:00:00:00" and dev == "bdg2" and ip:match("^192%.168%.29%.") and ip ~= "192.168.29.1" then
        arp_table[hw:upper()] = { ip = ip, dev = dev }
    end
end

-- Parse /var/dhcpd.leases SOLELY for Hostname resolution and IP caching (NEVER to invent active clients)
local hostnames = {}
local lease_ips = {}
local dhcp_out = run_cmd("cat /var/dhcpd.leases /var/state/dhcp/dhcpd.leases 2>/dev/null")
for line in dhcp_out:gmatch("[^\r\n]+") do
    local ts, mac, ip, name = line:match("(%d+)%s+([%x:]+)%s+([%d%.]+)%s+([^%s]+)")
    if mac and #mac == 17 and mac ~= "00:00:00:00:00:00" then
        local upper_mac = mac:upper()
        if name and name ~= "*" and name ~= "" then
            hostnames[upper_mac] = name
        end
        if ip and ip ~= "" and ip:match("^192%.168%.29%.") then
            lease_ips[upper_mac] = ip
        end
    end
end

-- Build active client records
local active_clients_list = {}
local seen_clients = {}

-- 1. Add active 5GHz Wi-Fi associated clients first
for _, mac in ipairs(clients_5g) do
    seen_clients[mac] = true
    local client_ip = (arp_table[mac] and arp_table[mac].ip) or lease_ips[mac] or "Pending DHCP"
    local name = hostnames[mac] or ""
    table.insert(active_clients_list, {
        mac = mac,
        band = "5GHz Wi-Fi",
        ip = client_ip,
        hostname = (name ~= "" and name ~= "*") and name or "Unknown Device"
    })
end

-- 2. Add verified active Ethernet/wired clients on bdg2 (from kernel ARP table)
for mac, arp_info in pairs(arp_table) do
    if not seen_clients[mac] and mac ~= wpa_bssid:upper() then
        local name = hostnames[mac] or ""
        table.insert(active_clients_list, {
            mac = mac,
            band = "Ethernet / LAN",
            ip = arp_info.ip,
            hostname = (name ~= "" and name ~= "*") and name or "Unknown Device"
        })
    end
end

-- 5. Gateway ping test
local gw_reachable = os.execute("ping -c 1 -W 2 -I wl0 192.168.1.1 >/dev/null 2>&1") == 0

-- 6. Read saved networks list
local config_path = "/pfrm2.0/etc/repeater_config.json"
local saved_nets = {}
local cf = io.open(config_path, "r")
if cf then
    local cfg = json.decode(cf:read("*all"))
    cf:close()
    if cfg and cfg.saved_networks then
        saved_nets = cfg.saved_networks
    end
end

local status = {
    upstream = {
        state = wpa_state,
        ssid = wpa_ssid,
        bssid = wpa_bssid,
        ip = wpa_ip,
        rssi = wl0_rssi,
        noise = wl0_noise,
        channel = wl0_chan,
        gateway_online = gw_reachable
    },
    local_ap_5g = {
        iface = "wl1",
        ssid = wl1_ssid,
        hidden = wl1_closed,
        channel = wl1_chan,
        connected_client_count = #clients_5g,
        clients = clients_5g
    },
    active_clients = active_clients_list,
    saved_networks = saved_nets
}

io.write(json.encode({ status = "success", data = status }))
