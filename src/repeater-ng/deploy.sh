#!/bin/sh
# deploy_repeater_ng.sh
# Complete deployment script for Next-Gen Repeater & UI onto Jio JCOW411

set -e

echo "=== Deploying JCOW411 Next-Gen Repeater Components ==="

# 1. Create directory structure
mkdir -p /pfrm2.0/bin
mkdir -p /pfrm2.0/etc
mkdir -p /pfrm2.0/var/www/cgi-bin
mkdir -p /pfrm2.0/var/www/custom

# 2. Patch lighttpd to permit .html
CONF="/pfrm2.0/etc/lighttpd.conf"
if grep -q '"\.html"' "$CONF" 2>/dev/null; then
    echo "[1/6] Patching lighttpd.conf to permit .html dashboard..."
    [ ! -f "$CONF.orig" ] && cp "$CONF" "$CONF.orig"
    sed -i 's/"\.html"[ ]*,//g' "$CONF"
    sed -i 's/,[ ]*"\.html"//g' "$CONF"
    killall lighttpd 2>/dev/null || true
    sleep 1
    /pfrm2.0/bin/lighttpd -f /pfrm2.0/etc/lighttpd.conf -m /pfrm2.0/lib
fi

# 3. Ensure permissions on scripts
chmod +x /pfrm2.0/bin/repeater_engine.sh 2>/dev/null || true
chmod +x /pfrm2.0/bin/watchdog.sh 2>/dev/null || true
chmod +x /pfrm2.0/var/www/cgi-bin/*.cgi 2>/dev/null || true

# 4. Update /pfrm2.0/etc/userInit if needed
USERINIT="/pfrm2.0/etc/userInit"
if ! grep -q 'repeater_engine.sh' "$USERINIT" 2>/dev/null; then
    echo "[4/6] Updating userInit hook for persistence..."
    # Replace old repeater.sh with new repeater_engine.sh & watchdog
    sed -i 's|/bin/sh /pfrm2.0/etc/repeater.sh|/bin/sh /pfrm2.0/bin/repeater_engine.sh|g' "$USERINIT"
    
    if ! grep -q 'watchdog.sh' "$USERINIT" 2>/dev/null; then
        echo "( while true; do sleep 60; /bin/sh /pfrm2.0/bin/watchdog.sh; done ) &" >> "$USERINIT"
    fi
fi

echo "=== Deployment Complete ==="
echo "Dashboard URL: http://192.168.29.1/custom/index.html"
echo "Or API test: http://192.168.29.1/cgi-bin/api_status.cgi"
