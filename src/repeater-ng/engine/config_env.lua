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

if cfg.upstream then
    print(string.format('CONFIG_UPSTREAM_SSID="%s"', sanitize(cfg.upstream.ssid)))
    print(string.format('CONFIG_UPSTREAM_BSSID="%s"', sanitize(cfg.upstream.bssid)))
    print(string.format('CONFIG_UPSTREAM_PSK="%s"', sanitize(cfg.upstream.psk_hex)))
    print(string.format('CONFIG_UPSTREAM_GATEWAY="%s"', sanitize(cfg.upstream.gateway_ip or "192.168.1.1")))
end

if cfg.local_ap_5g then
    print(string.format('CONFIG_LOCAL_5G_IFACE="%s"', sanitize(cfg.local_ap_5g.iface or "wl1")))
    print(string.format('CONFIG_LOCAL_5G_SSID="%s"', sanitize(cfg.local_ap_5g.ssid)))
    print(string.format('CONFIG_LOCAL_5G_PASS="%s"', sanitize(cfg.local_ap_5g.passphrase)))
    print(string.format('CONFIG_LOCAL_5G_HIDDEN="%s"', cfg.local_ap_5g.hidden and "1" or "0"))
end

if cfg.watchdog then
    print(string.format('CONFIG_WATCHDOG_ENABLED="%s"', cfg.watchdog.enabled and "1" or "0"))
    print(string.format('CONFIG_WATCHDOG_INTERVAL="%s"', sanitize(cfg.watchdog.interval_sec or 60)))
    print(string.format('CONFIG_WATCHDOG_MAX_FAILS="%s"', sanitize(cfg.watchdog.max_fails or 3)))
end
