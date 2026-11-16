-- /pfrm2.0/bin/config_env.lua
-- Reads /pfrm2.0/etc/repeater_config.json and outputs shell export commands.
-- Usage: eval $(/pfrm2.0/bin/lua /pfrm2.0/bin/config_env.lua)

package.path = "/pfrm2.0/bin/?.lua;/pfrm2.0/share/lua/5.1/?.lua;/pfrm2.0/share/lua/5.1/?/init.lua;" .. package.path

local ok, json = pcall(require, "tiny_json")
if not ok then
    json = require("teamf1lualib/json")
end

local config_path = arg[1] or "/pfrm2.0/etc/repeater_config.json"
local f = io.open(config_path, "r")
if not f then
    io.stderr:write("Error: Cannot open config file " .. config_path .. "\n")
    os.exit(1)
end

local content = f:read("*all")
f:close()

local cfg, err = json.decode(content)
if not cfg then
    io.stderr:write("Error: Failed to parse JSON: " .. tostring(err) .. "\n")
    os.exit(1)
end

local function sanitize(val)
    if val == nil then return "" end
    val = tostring(val)
    val = val:gsub('"', '\\"')
    val = val:gsub('`', '')
    val = val:gsub('%$', '')
    return val
end

local mode = arg[2] or "default"
local exclude_bssid = sanitize(arg[3] or ""):upper()

-- Parse live airwaves from wl scanresults
local scan_in_range = {}
local sh = io.popen("wl -i wl0 scanresults 2>/dev/null")
if sh then
    local cur_entry = nil
    for line in sh:read("*all"):gmatch("[^\r\n]+") do
        local s = line:match('^SSID:%s+"(.*)"')
        if s then
            if cur_entry and cur_entry.ssid and cur_entry.bssid then
                local existing = scan_in_range[cur_entry.ssid]
                if not existing or (cur_entry.rssi and existing.rssi and cur_entry.rssi > existing.rssi) then
                    scan_in_range[cur_entry.ssid] = cur_entry
                    scan_in_range[cur_entry.bssid] = cur_entry
                end
            end
            cur_entry = { ssid = s, bssid = nil, channel = "", rssi = -100 }
        elseif cur_entry then
            local b = line:match('BSSID:%s*([%x:]+)')
            if b and #b == 17 then
                cur_entry.bssid = b:upper()
            end
            local r = line:match('RSSI:%s*([-%d]+)%s*dBm')
            if r then
                cur_entry.rssi = tonumber(r)
            end
            local ch = line:match('Channel:%s*(%d+)')
            if ch then
                cur_entry.channel = ch
            end
        end
    end
    if cur_entry and cur_entry.ssid and cur_entry.bssid then
        local existing = scan_in_range[cur_entry.ssid]
        if not existing or (cur_entry.rssi and existing.rssi and cur_entry.rssi > existing.rssi) then
            scan_in_range[cur_entry.ssid] = cur_entry
            scan_in_range[cur_entry.bssid] = cur_entry
        end
    end
    sh:close()
end

-- Automatic Multi-Network Failover Selection
if mode == "auto_select" and cfg.saved_networks and #cfg.saved_networks > 0 then
    local chosen = nil
    for _, net in ipairs(cfg.saved_networks) do
        local upper_bssid = (net.bssid or ""):upper()
        local match = scan_in_range[net.ssid] or (upper_bssid ~= "" and scan_in_range[upper_bssid])
        if match and (exclude_bssid == "" or (match.bssid and match.bssid:upper() ~= exclude_bssid)) then
            chosen = {
                ssid = net.ssid,
                bssid = match.bssid or net.bssid or "",
                channel = match.channel or "",
                psk_hex = net.psk_hex,
                gateway_ip = net.gateway_ip
            }
            break
        end
    end

    if chosen then
        cfg.upstream = cfg.upstream or {}
        cfg.upstream.ssid = chosen.ssid
        cfg.upstream.bssid = chosen.bssid
        cfg.upstream.channel = chosen.channel
        cfg.upstream.psk_hex = chosen.psk_hex
        if chosen.gateway_ip then
            cfg.upstream.gateway_ip = chosen.gateway_ip
        end
    end
end

-- Dynamic BSSID & Channel Resolution if BSSID is omitted or empty
if cfg.upstream and cfg.upstream.ssid then
    local match = scan_in_range[cfg.upstream.ssid]
    if match then
        if not cfg.upstream.bssid or cfg.upstream.bssid == "" or cfg.upstream.bssid == "00:00:00:00:00:00" then
            cfg.upstream.bssid = match.bssid
        end
        if not cfg.upstream.channel or cfg.upstream.channel == "" then
            cfg.upstream.channel = match.channel
        end
    end
end

if cfg.upstream then
    print(string.format('CONFIG_UPSTREAM_SSID="%s"', sanitize(cfg.upstream.ssid)))
    print(string.format('CONFIG_UPSTREAM_BSSID="%s"', sanitize(cfg.upstream.bssid)))
    print(string.format('CONFIG_UPSTREAM_CHANNEL="%s"', sanitize(cfg.upstream.channel or "")))
    print(string.format('CONFIG_UPSTREAM_PSK="%s"', sanitize(cfg.upstream.psk_hex)))
    print(string.format('CONFIG_UPSTREAM_GATEWAY="%s"', sanitize(cfg.upstream.gateway_ip or "192.168.1.1")))
end

if cfg.local_ap_5g then
    print(string.format('CONFIG_LOCAL_5G_IFACE="%s"', sanitize(cfg.local_ap_5g.iface or "wl1")))
    print(string.format('CONFIG_LOCAL_5G_SSID="%s"', sanitize(cfg.local_ap_5g.ssid)))
    print(string.format('CONFIG_LOCAL_5G_PASS="%s"', sanitize(cfg.local_ap_5g.passphrase)))
    print(string.format('CONFIG_LOCAL_5G_HIDDEN="%s"', cfg.local_ap_5g.hidden and "1" or "0"))
end
