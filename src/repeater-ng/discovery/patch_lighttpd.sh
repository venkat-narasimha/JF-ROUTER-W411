#!/bin/sh
# /pfrm2.0/bin/patch_lighttpd.sh
# Patches /pfrm2.0/etc/lighttpd.conf to remove ".html" from url.access-deny
# This enables serving the custom repeater dashboard under /pfrm2.0/var/www/custom/index.html

CONF="/pfrm2.0/etc/lighttpd.conf"
BAK="/pfrm2.0/etc/lighttpd.conf.bak"

if [ ! -f "$CONF" ]; then
    echo "ERROR: $CONF not found"
    exit 1
fi

# Backup original if not already backed up
if [ ! -f "$BAK" ]; then
    cp "$CONF" "$BAK"
    echo "Created backup at $BAK"
fi

# Replace 'url.access-deny = ( "~", ".inc" , ".html", ".lua")'
# with 'url.access-deny = ( "~", ".inc", ".lua")'
sed -i 's/"\.html"[ ]*,//g' "$CONF"
sed -i 's/,[ ]*"\.html"//g' "$CONF"

echo "Lighttpd access-deny patched."

# Restart lighttpd safely
echo "Restarting lighttpd..."
killall lighttpd 2>/dev/null
sleep 1
/pfrm2.0/bin/lighttpd -f /pfrm2.0/etc/lighttpd.conf -m /pfrm2.0/lib

if ps | grep lighttpd | grep -v grep >/dev/null 2>&1; then
    echo "lighttpd restarted successfully!"
else
    echo "WARNING: lighttpd failed to restart! Restoring backup..."
    cp "$BAK" "$CONF"
    /pfrm2.0/bin/lighttpd -f /pfrm2.0/etc/lighttpd.conf -m /pfrm2.0/lib
fi
