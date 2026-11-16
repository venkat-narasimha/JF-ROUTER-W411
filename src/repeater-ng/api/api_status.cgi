#!/bin/sh
# /pfrm2.0/var/www/cgi-bin/api_status.cgi
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""
/pfrm2.0/bin/lua /pfrm2.0/bin/api_status.lua 2>/dev/null || echo '{"status":"error","message":"Status query failed"}'
