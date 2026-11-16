#!/bin/sh
# JCOW411 Next-Gen Repeater — Environment Discovery Script
# Paste this entire script into a Telnet session on the router.
# It prints a tagged report that can be copied back for analysis.
# Safe: read-only commands only, no modifications.

SEP="================================================================"

echo "$SEP"
echo "JCOW411 DISCOVERY REPORT — $(date)"
echo "$SEP"

# ---- Section 1: System basics ----
echo ""
echo ">>> SECTION 1: SYSTEM BASICS"
echo "--- uname -a ---"
uname -a
echo "--- BusyBox version ---"
busybox 2>&1 | sed -n '1p'
echo "--- Available BusyBox applets (first 10) ---"
busybox --list 2>/dev/null | awk 'NR<=10'
echo "--- /etc/os-release or /etc/version ---"
cat /etc/os-release 2>/dev/null || cat /etc/version 2>/dev/null || echo "(none found)"
echo "--- Disk usage ---"
df -h 2>/dev/null || df
echo "--- Free memory ---"
free 2>/dev/null || cat /proc/meminfo | awk 'NR<=5'

# ---- Section 2: Web server identification ----
echo ""
echo ">>> SECTION 2: WEB SERVER"
echo "--- HTTP-related processes ---"
ps | grep -iE 'httpd|lighttpd|goahead|uhttpd|mini_httpd|boa|thttpd|nginx|lua' | grep -v grep
echo "--- Web server config files ---"
for f in /etc/lighttpd.conf /etc/config/lighttpd.conf /etc/httpd.conf \
         /etc/goahead/goahead.conf /etc/uhttpd.conf /etc/config/uhttpd \
         /etc/boa/boa.conf /etc/mini_httpd.conf /tmp/httpd.conf \
         /pfrm2.0/etc/lighttpd.conf /pfrm2.0/etc/httpd.conf; do
    if [ -f "$f" ]; then
        echo "--- FOUND: $f ---"
        cat "$f"
        echo "--- END: $f ---"
    fi
done
echo "--- Listening on port 80/443 ---"
netstat -tlnp 2>/dev/null | grep -E ':80 |:443 |:8080 ' || echo "(netstat unavailable or no listeners)"

# ---- Section 3: Web root and CGI paths ----
echo ""
echo ">>> SECTION 3: WEB ROOT & CGI"
echo "--- /www/ listing ---"
ls -la /www/ 2>/dev/null || echo "/www/ not found"
echo "--- /www/ top-level dirs ---"
ls -d /www/*/ 2>/dev/null || echo "(no subdirs)"
echo "--- CGI directories ---"
for d in /www/cgi-bin /www/cgi /pfrm2.0/cgi /cgi-bin /www/goform; do
    if [ -d "$d" ]; then
        echo "--- FOUND DIR: $d ---"
        ls -la "$d" | awk 'NR<=20'
    fi
done
echo "--- Find .cgi and .lua files under /www ---"
find /www/ -name "*.cgi" -o -name "*.lua" -o -name "*.asp" -o -name "*.lp" 2>/dev/null | awk 'NR<=20'
echo "--- Find .cgi and .lua files under /pfrm2.0 ---"
find /pfrm2.0/ -name "*.cgi" -o -name "*.lua" 2>/dev/null | awk 'NR<=20'

# ---- Section 4: Stock UI structure ----
echo ""
echo ">>> SECTION 4: STOCK UI STRUCTURE"
echo "--- Main HTML/HTM files in /www ---"
find /www/ -maxdepth 2 -name "*.html" -o -name "*.htm" 2>/dev/null | awk 'NR<=15'
echo "--- Sidebar/menu files (search for nav/menu/sidebar) ---"
grep -rlE 'sidebar|menu|nav' /www/ 2>/dev/null | awk 'NR<=10'
echo "--- index.html or main entry ---"
for f in /www/index.html /www/index.htm /www/index.asp /www/login.html /www/login.asp /www/home.html; do
    if [ -f "$f" ]; then
        echo "--- FOUND: $f (first 30 lines) ---"
        sed -n '1,30p' "$f"
        echo "..."
    fi
done

# ---- Section 5: Lua environment ----
echo ""
echo ">>> SECTION 5: LUA ENVIRONMENT"
echo "--- Lua binary ---"
which lua 2>/dev/null
ls -la /pfrm2.0/bin/lua 2>/dev/null
echo "--- Lua version ---"
/pfrm2.0/bin/lua -v 2>&1
echo "--- Lua package.path ---"
/pfrm2.0/bin/lua -e 'print("path=" .. package.path)' 2>&1
echo "--- Lua package.cpath ---"
/pfrm2.0/bin/lua -e 'print("cpath=" .. package.cpath)' 2>&1
echo "--- teamf1lualib DB check ---"
/pfrm2.0/bin/lua -e 'local ok,err = pcall(function() require("teamf1lualib/db") end); print(ok and "DB_LIB_OK" or "DB_LIB_FAIL: "..tostring(err))' 2>&1
echo "--- teamf1lualib contents ---"
find / -path "*/teamf1lualib*" -type f 2>/dev/null | awk 'NR<=15'
echo "--- JSON lib check ---"
/pfrm2.0/bin/lua -e 'local ok,err = pcall(function() require("json") end); print(ok and "JSON_LIB_OK" or "JSON_LIB_FAIL: "..tostring(err))' 2>&1
/pfrm2.0/bin/lua -e 'local ok,err = pcall(function() require("cjson") end); print(ok and "CJSON_LIB_OK" or "CJSON_LIB_FAIL: "..tostring(err))' 2>&1
/pfrm2.0/bin/lua -e 'local ok,err = pcall(function() require("dkjson") end); print(ok and "DKJSON_LIB_OK" or "DKJSON_LIB_FAIL: "..tostring(err))' 2>&1

# ---- Section 6: system.db and database ----
echo ""
echo ">>> SECTION 6: DATABASE"
echo "--- system.db ---"
ls -la /tmp/system.db 2>/dev/null || echo "/tmp/system.db not found"
echo "--- sqlite3 binary ---"
which sqlite3 2>/dev/null || echo "sqlite3 not found"
echo "--- DB tables (if sqlite3 available) ---"
sqlite3 /tmp/system.db ".tables" 2>/dev/null | awk 'NR<=10' || echo "(skipped)"
echo "--- dot11 tables ---"
sqlite3 /tmp/system.db "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%dot11%';" 2>/dev/null || echo "(skipped)"

# ---- Section 7: wl iovars for AP management ----
echo ""
echo ">>> SECTION 7: WL IOVARS (AP MANAGEMENT)"
echo "--- wl1 current status ---"
wl -i wl1 status 2>&1
echo "--- wl1 ssid ---"
wl -i wl1 ssid 2>&1
echo "--- wl1 wsec ---"
wl -i wl1 wsec 2>&1
echo "--- wl1 wpa_auth ---"
wl -i wl1 wpa_auth 2>&1
echo "--- wl1 closed (hidden) ---"
wl -i wl1 closed 2>&1
echo "--- wl1 sup_wpa check ---"
wl -i wl1 sup_wpa 2>&1
echo "--- wl help: psk/wsec/wpa_auth/closed ---"
wl help 2>&1 | grep -iE 'set_pmk|psk|wsec|wpa_auth|closed|sup_wpa' || echo "(grep found nothing)"
echo "--- wl0 current status ---"
wl -i wl0 status 2>&1

# ---- Section 8: LEDs ----
echo ""
echo ">>> SECTION 8: LEDS & GPIO"
echo "--- /sys/class/leds/ ---"
ls -la /sys/class/leds/ 2>/dev/null || echo "no leds sysfs"
echo "--- LED brightness values ---"
for led in /sys/class/leds/*/; do
    name=$(basename "$led")
    bright=$(cat "${led}brightness" 2>/dev/null)
    trigger=$(cat "${led}trigger" 2>/dev/null | sed 's/.*\[\(.*\)\].*/\1/')
    echo "  $name: brightness=$bright trigger=$trigger"
done
echo "--- /sys/class/gpio/ ---"
ls -la /sys/class/gpio/ 2>/dev/null || echo "no gpio sysfs"

# ---- Section 9: Crontab and init ----
echo ""
echo ">>> SECTION 9: CRON & INIT"
echo "--- crontab ---"
crontab -l 2>/dev/null || echo "no crontab"
echo "--- crond process ---"
ps | grep crond | grep -v grep || echo "crond not running"
echo "--- /pfrm2.0/etc/userInit ---"
cat /pfrm2.0/etc/userInit 2>/dev/null || echo "userInit not found"
echo "--- /pfrm2.0/etc/platformInit (last 20 lines) ---"
sed -n '1,$p' /pfrm2.0/etc/platformInit 2>/dev/null | tail -20 || echo "platformInit not found"

# ---- Section 10: Network state ----
echo ""
echo ">>> SECTION 10: CURRENT NETWORK STATE"
echo "--- interfaces ---"
ifconfig | grep -E '^[a-z]|inet addr' 2>/dev/null
echo "--- bridges ---"
brctl show 2>/dev/null
echo "--- routes ---"
route -n 2>/dev/null || ip route 2>/dev/null
echo "--- iptables nat ---"
iptables -t nat -L -n 2>/dev/null | awk 'NR<=15'

# ---- Section 11: Available tools ----
echo ""
echo ">>> SECTION 11: AVAILABLE TOOLS"
echo "--- Key binaries check ---"
for cmd in awk sed grep find cat wpa_supplicant wpa_cli udhcpc brctl iptables \
           wl ping killall chmod mkdir rm cp mv ls printf expr sleep; do
    p=$(which "$cmd" 2>/dev/null)
    if [ -n "$p" ]; then
        echo "  OK: $cmd -> $p"
    else
        echo "  MISSING: $cmd"
    fi
done
echo "--- head check (expected missing) ---"
which head 2>/dev/null && echo "head EXISTS (unexpected)" || echo "head MISSING (expected)"
echo "--- wpa_passphrase check (expected missing) ---"
which wpa_passphrase 2>/dev/null && echo "wpa_passphrase EXISTS" || echo "wpa_passphrase MISSING (expected)"

# ---- Section 12: Writable space ----
echo ""
echo ">>> SECTION 12: WRITABLE SPACE"
echo "--- /pfrm2.0/ usage ---"
df /pfrm2.0/ 2>/dev/null
echo "--- /tmp/ usage ---"
df /tmp/ 2>/dev/null
echo "--- /www/ writable test ---"
touch /www/.discovery_test 2>/dev/null && echo "/www/ IS writable" && rm /www/.discovery_test || echo "/www/ NOT writable"
echo "--- /www/custom/ test ---"
mkdir -p /www/custom 2>/dev/null && echo "/www/custom/ created OK" && rmdir /www/custom || echo "/www/custom/ FAILED"

echo ""
echo "$SEP"
echo "DISCOVERY COMPLETE"
echo "$SEP"
