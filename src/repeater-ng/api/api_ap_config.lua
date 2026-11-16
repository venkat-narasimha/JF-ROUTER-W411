-- /pfrm2.0/bin/api_ap_config.lua
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
if not req then
    io.write(json.encode({ status = "error", message = "Invalid request payload" }))
    return
end

-- Local AP is strictly hosted on the dedicated 5GHz radio (wl1)
local conf_file = "/tmp/wl1_hapd.conf"
local iface = "wl1"

-- Sanitize helper (strips shell and sed meta-characters)
local function clean_str(s)
    if not s then return "" end
    return tostring(s):gsub('["\\`%$/&]', '')
end

local ssid = clean_str(req.ssid)
local passphrase = clean_str(req.passphrase)
local hidden = req.hidden == true or req.hidden == 1 or req.hidden == "1"

-- Update hostapd config file for wl1
if io.open(conf_file, "r") then
    if ssid ~= "" then
        os.execute(string.format("sed -i 's/^ssid=.*/ssid=%s/' %s", ssid, conf_file))
        os.execute(string.format('wl -i wl1 ssid "%s" >/dev/null 2>&1', ssid))
    end
    if passphrase ~= "" then
        os.execute(string.format("sed -i 's/^wpa_passphrase=.*/wpa_passphrase=%s/' %s", passphrase, conf_file))
    end
    if req.hidden ~= nil then
        os.execute(string.format("sed -i 's/^ignore_broadcast_ssid=.*/ignore_broadcast_ssid=%d/' %s", hidden and 1 or 0, conf_file))
        os.execute(string.format('wl -i wl1 closed %d >/dev/null 2>&1', hidden and 1 or 0))
    end
end

-- Safely restart hostapd strictly for wl1 (5GHz AP)
-- wl0 is client-only: ensure hostapd never attaches to wl0
os.execute("killall -9 hostapd 2>/dev/null")
os.execute("sleep 1")
os.execute("rm -f /var/run/hostapd/* 2>/dev/null")
os.execute("hostapd -B /tmp/wl1_hapd.conf >/dev/null 2>&1")
os.execute("ifconfig wl0.1 down >/dev/null 2>&1; wl -i wl0.1 bss down >/dev/null 2>&1")
os.execute("ifconfig wl0.2 down >/dev/null 2>&1; wl -i wl0.2 bss down >/dev/null 2>&1")
os.execute("ifconfig wl1.1 down >/dev/null 2>&1; wl -i wl1.1 bss down >/dev/null 2>&1")
os.execute("ifconfig wl1.2 down >/dev/null 2>&1; wl -i wl1.2 bss down >/dev/null 2>&1")

-- Update local config file
local config_path = "/pfrm2.0/etc/repeater_config.json"
local cur_cfg = {}
local f = io.open(config_path, "r")
if f then
    cur_cfg = json.decode(f:read("*all")) or {}
    f:close()
end

cur_cfg.local_ap = cur_cfg.local_ap or {}
cur_cfg.local_ap.iface = "wl1"
if ssid ~= "" then cur_cfg.local_ap.ssid = ssid end
if req.hidden ~= nil then cur_cfg.local_ap.hidden = hidden end
if passphrase ~= "" then cur_cfg.local_ap.passphrase = passphrase end

local out_f = io.open(config_path, "w")
if out_f then
    out_f:write(json.encode(cur_cfg))
    out_f:close()
end

io.write(json.encode({
    status = "success",
    message = "Local 5GHz Wi-Fi settings applied successfully",
    ssid = ssid,
    hidden = hidden
}))
