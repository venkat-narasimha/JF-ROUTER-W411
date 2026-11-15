# Run Custom Scripts on Router

## Purpose
Persist custom shell scripts across reboots by hooking into the router's init system.

## Compatibility / Verification Status
- Legacy repository claim; tested on JCOW404/JCOW411 per original docs.
- Not reverified in this fork — treat as experimental.
- Verified persistence hook on JCOW411 R2.3: `/pfrm2.0/etc/userInit` invoked from `platformInit`.

## Risk
- Modifies root filesystem; incorrect scripts can brick the router.
- Scripts run as root; test thoroughly before making persistent.
- UBIFS writable partition preserves changes across reboots.

## Prerequisites
- Root Telnet access.
- Script tested manually and working.

## Procedure

### Method 1: Direct `rcS` edit (legacy)
1. Edit `/etc/init.d/rcS`.
2. Append: `/path/to/script.sh &`.
3. Make script executable: `chmod +x /path/to/script.sh`.

### Method 2: `/scripts` directory loop (legacy)
```bash
mkdir /scripts
# Add scripts to /scripts/
for i in /scripts/*.sh; do
    if [ -x "$i" ]; then
        echo "Executing custom script: $i"
        "$i" &
    fi
done
```
Add this loop to `/etc/init.d/rcS`.

### Method 3: `userInit` hook (verified on JCOW411 R2.3)
1. Create script at `/pfrm2.0/etc/customInit`:
   ```bash
   #!/bin/sh
   sleep 60
   /usr/sbin/telnetd 2>/dev/null
   /pfrm2.0/bin/iptables -I fwInBypass -p tcp --dport 23 -m ifgroup --ifgroup-in 0x1/0x1 -j ACCEPT 2>/dev/null
   echo -e 'YOUR_PASSWORD\nYOUR_PASSWORD' | passwd root 2>/dev/null
   ```
2. Make executable: `chmod +x /pfrm2.0/etc/customInit`.
3. Enable: `touch /flash/telnetEnable`.

The `platformInit` → `userInit` chain runs this on boot.

## Validation
- Reboot router.
- Verify script ran: check logs, Telnet, or script-specific effects.

## Rollback / Recovery
- Remove or rename the script file.
- Remove the `rcS` edit or `customInit` file.
- Delete `/flash/telnetEnable` to disable the hook.

## Troubleshooting
- Script not running — check execute bit and path.
- Boot hangs — script may block; run in background with `&` and ensure it exits.
- Changes lost on reboot — verify UBIFS mount is writable (`mount | grep ubifs`).