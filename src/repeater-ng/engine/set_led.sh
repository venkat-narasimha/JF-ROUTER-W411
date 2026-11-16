#!/bin/sh
# /pfrm2.0/bin/set_led.sh
# LED State Driver for Jio JCOW411 using official /bin/ledctl1
#
# States:
#   1. boot         - Solid Red
#   2. scanning     - Blinking Blue (slowBlink)
#   3. associating  - Solid Blue
#   4. obtaining_ip - Blinking Green (slowBlink)
#   5. online       - Solid Green
#   6. dropped      - Solid Yellow (Red + Green on)
#   7. retrying     - Blinking Yellow (Red + Green slowBlink)
#   8. fatal        - Blinking Red (fastBlink)

STATE="${1:-online}"

case "$STATE" in
    boot|red_on)
        /bin/ledctl1 ALL off 2>/dev/null
        /bin/ledctl1 RED on 2>/dev/null
        ;;
    scanning)
        /bin/ledctl1 ALL off 2>/dev/null
        /bin/ledctl1 BLUE slowBlink 2>/dev/null
        ;;
    associating|blue_on)
        /bin/ledctl1 ALL off 2>/dev/null
        /bin/ledctl1 BLUE on 2>/dev/null
        ;;
    obtaining_ip|green_blink)
        /bin/ledctl1 ALL off 2>/dev/null
        /bin/ledctl1 GREEN slowBlink 2>/dev/null
        ;;
    online|green_on)
        /bin/ledctl1 ALL off 2>/dev/null
        /bin/ledctl1 GREEN on 2>/dev/null
        ;;
    dropped)
        /bin/ledctl1 ALL off 2>/dev/null
        /bin/ledctl1 RED on 2>/dev/null
        /bin/ledctl1 GREEN on 2>/dev/null
        ;;
    retrying)
        /bin/ledctl1 ALL off 2>/dev/null
        /bin/ledctl1 RED slowBlink 2>/dev/null
        /bin/ledctl1 GREEN slowBlink 2>/dev/null
        ;;
    fatal|red_blink)
        /bin/ledctl1 ALL off 2>/dev/null
        /bin/ledctl1 RED fastBlink 2>/dev/null
        ;;
    off)
        /bin/ledctl1 ALL off 2>/dev/null
        ;;
    *)
        /bin/ledctl1 ALL off 2>/dev/null
        /bin/ledctl1 GREEN on 2>/dev/null
        ;;
esac
