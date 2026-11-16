#!/bin/sh
# /pfrm2.0/var/www/cgi-bin/api_ap_config.cgi
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""
/pfrm2.0/bin/lua /pfrm2.0/bin/api_ap_config.lua 2>&1
