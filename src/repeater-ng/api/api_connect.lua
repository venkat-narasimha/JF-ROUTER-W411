-- /pfrm2.0/bin/api_connect.lua
package.path = "/pfrm2.0/bin/?.lua;/pfrm2.0/share/lua/5.1/?.lua;/pfrm2.0/share/lua/5.1/?/init.lua;" .. package.path

local json
local ok, mod = pcall(require, "tiny_json")
if ok and mod then
    json = mod
else
    json = require("teamf1lualib/json")
end

local content_len = tonumber(os.getenv("CONTENT_LENGTH") or "0")
local post_data = ""
if content_len and content_len > 0 then
    post_data = io.read(content_len) or ""
else
    post_data = io.read("*l") or io.read("*all") or ""
end

local req, err = json.decode(post_data)
if not req or not req.ssid or not req.psk_hex then
    io.write(json.encode({ status = "error", message = "Invalid parameters: ssid and psk_hex are required" }))
    return
end

-- Sanitize helper to prevent command injection
local function clean_str(s)
    if not s then return "" end
    return tostring(s):gsub('["\\`%$]', '')
end

local ssid = clean_str(req.ssid)
local bssid = clean_str(req.bssid or "")
local psk_hex = tostring(req.psk_hex):gsub('[^%x]', ''):lower()
local raw_password = tostring(req.raw_password or "")

if bssid == "" then
    -- Try resolving BSSID using directed probe on wl0
    os.execute(string.format('wl -i wl0 scan -s "%s" >/dev/null 2>&1', ssid))
    os.execute("sleep 2")
    local h = io.popen("wl -i wl0 scanresults 2>/dev/null")
    if h then
        local out = h:read("*all")
        h:close()
        local cur_s = nil
        for line in out:gmatch("[^\r\n]+") do
            local s = line:match('^SSID:%s+"(.*)"')
            if s then cur_s = s end
            local b = line:match('BSSID:%s*([%x:]+)')
            if b and #b == 17 and cur_s == ssid then
                bssid = b:upper()
                break
            end
        end
    end
end

-- Validate 64-hex PSK
if #psk_hex ~= 64 then
    io.write(json.encode({ status = "error", message = "Invalid PSK: must be a 64-character hex string" }))
    return
end

local config_path = "/pfrm2.0/etc/repeater_config.json"
local cur_cfg = {}
local f = io.open(config_path, "r")
if f then
    cur_cfg = json.decode(f:read("*all")) or {}
    f:close()
end

cur_cfg.upstream = {
    ssid = ssid,
    bssid = bssid,
    psk_hex = psk_hex,
    gateway_ip = clean_str(req.gateway_ip) ~= "" and clean_str(req.gateway_ip) or (cur_cfg.upstream and cur_cfg.upstream.gateway_ip) or "192.168.1.1"
}

-- Persist updated configuration and save network profile into saved_networks table
local out_f = io.open(config_path, "w")
if not out_f then
    io.write(json.encode({ status = "error", message = "Failed to write config file" }))
    return
end

-- Save/Update saved networks profile
cur_cfg.saved_networks = cur_cfg.saved_networks or {}
local found = false
for i, net in ipairs(cur_cfg.saved_networks) do
    if net.ssid == ssid then
        cur_cfg.saved_networks[i] = {
            ssid = ssid,
            bssid = bssid,
            psk_hex = psk_hex,
            raw_password = raw_password ~= "" and raw_password or net.raw_password or ""
        }
        found = true
        break
    end
end
if not found then
    table.insert(cur_cfg.saved_networks, {
        ssid = ssid,
        bssid = bssid,
        psk_hex = psk_hex,
        raw_password = raw_password
    })
end

out_f:write(json.encode(cur_cfg))
out_f:close()

-- Trigger background reconnection
os.execute("/pfrm2.0/bin/repeater_engine.sh >/dev/null 2>&1 &")

io.write(json.encode({
    status = "success",
    message = "Configuration updated. Repeater engine triggered.",
    ssid = ssid,
    bssid = bssid
}))
