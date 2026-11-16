-- /pfrm2.0/bin/api_scan.lua
package.path = "/pfrm2.0/bin/?.lua;/pfrm2.0/share/lua/5.1/?.lua;/pfrm2.0/share/lua/5.1/?/init.lua;" .. package.path
local ok, json = pcall(require, "tiny_json")
if not ok then json = require("teamf1lualib/json") end

-- Trigger hardware scan on wl0
os.execute("wl -i wl0 scan >/dev/null 2>&1")
os.execute("sleep 3")

-- Read scanresults
local handle = io.popen("wl -i wl0 scanresults 2>/dev/null")
local output = ""
if handle then
    output = handle:read("*all")
    handle:close()
end

local networks = {}
local seen_bssids = {}

-- Sample wl scanresults format:
-- SSID: "MyNetwork"
-- Mode: ... RSSI: -65 dBm ...
-- BSSID: 00:11:22:33:44:55 Capability: ...
-- RSN (WPA2): ... AKM Suites(1): WPA2-PSK ...

-- Filter out local router's own hardware MAC addresses to avoid self-association loops
local own_macs = {
    ["F4:CA:E7:A7:39:50"] = true,
    ["F4:CA:E7:A7:39:51"] = true,
    ["F4:CA:E7:A7:39:52"] = true,
    ["9A:CA:E7:A7:39:53"] = true,
    ["9A:CA:E7:A7:39:54"] = true,
    ["9A:CA:E7:A7:39:55"] = true,
    ["92:CA:E7:A7:39:53"] = true
}

-- Dynamically discover ONLY the router's own physical hardware MACs (NOT associated upstream BSSIDs)
local own_mac_out = io.popen("wl -i wl0 cur_etheraddr 2>/dev/null; wl -i wl1 cur_etheraddr 2>/dev/null; cat /sys/class/net/wl0/address /sys/class/net/wl1/address /sys/class/net/bdg2/address 2>/dev/null")
if own_mac_out then
    for m in own_mac_out:read("*all"):gmatch("([%x:]+)") do
        if #m == 17 then own_macs[m:upper()] = true end
    end
    own_mac_out:close()
end

local cur = nil

for line in output:gmatch("[^\r\n]+") do
    local ssid = line:match('^SSID:%s+"(.*)"')
    if ssid then
        if cur and cur.bssid and not seen_bssids[cur.bssid] and not own_macs[cur.bssid] then
            seen_bssids[cur.bssid] = true
            table.insert(networks, cur)
        end
        cur = {
            ssid = ssid,
            bssid = "",
            rssi = 0,
            channel = "",
            security = "OPEN"
        }
    end

    if cur then
        local rssi = line:match('RSSI:%s*([-%d]+)%s*dBm')
        if rssi then
            cur.rssi = tonumber(rssi)
        end

        local channel = line:match('Channel:%s*([%d]+)')
        if channel then
            cur.channel = channel
        end

        local bssid = line:match('BSSID:%s*([%x:]+)')
        if bssid and #bssid == 17 then
            cur.bssid = bssid:upper()
        end

        if line:find("WPA2%-PSK") or line:find("RSN") then
            cur.security = "WPA2-PSK"
        elseif line:find("WPA%-PSK") then
            if cur.security ~= "WPA2-PSK" then
                cur.security = "WPA-PSK"
            end
        elseif line:find("WEP") then
            cur.security = "WEP"
        end
    end
end

if cur and cur.bssid and not seen_bssids[cur.bssid] and not own_macs[cur.bssid] then
    table.insert(networks, cur)
end

-- Sort by signal strength (descending)
table.sort(networks, function(a, b)
    return (a.rssi or -100) > (b.rssi or -100)
end)

local resp = {
    status = "success",
    count = #networks,
    networks = networks
}

io.write(json.encode(resp))
