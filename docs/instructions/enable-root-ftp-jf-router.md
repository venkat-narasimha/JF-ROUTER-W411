# Enable Root FTP Access

## Purpose
Run an FTP server on the router with root access and `/` as the FTP root for full filesystem access.

## Compatibility / Verification Status
- Legacy repository claim; tested on JCOW404/JCOW411 per original docs.
- Not reverified in this fork — treat as experimental.
- Requires root Telnet access first (see [Get Root Access](get-root-access-jf-ont.md)).

## Risk
- Exposes entire router filesystem over unencrypted FTP.
- Root credentials transmitted in cleartext.
- Only use on isolated, trusted LAN; stop service after use.

## Prerequisites
- Root Telnet access.
- `vsftpd` binary present on router (typically available).

## Procedure
1. Kill any existing FTP server:
   ```bash
   pkill vsftpd
   ```

2. Create `/flash/vsftpd.conf`:
   ```conf
   anonymous_enable=NO
   local_enable=YES
   write_enable=YES
   dirmessage_enable=YES
   xferlog_enable=YES
   connect_from_port_20=YES
   listen_port=21
   idle_session_timeout=300
   max_clients=200
   max_per_ip=200
   chroot_local_user=YES
   ftp_username=root
   secure_chroot_dir=/
   local_root=/
   listen_ipv6=YES
   userlist_enable=no
   userlist_deny=NO
   ```

3. Start FTP server:
   ```bash
   vsftpd /flash/vsftpd.conf &
   ```

4. Open firewall port 21:
   ```bash
   iptables -I fwInBypass -p tcp --dport 21 -m ifgroup --ifgroup-in 0x1/0x1 -j ACCEPT
   ```

5. Connect with FileZilla or similar: `root` / your root password.

## Validation
- FTP client connects and lists `/` directory.
- File transfer works in both directions.

## Rollback / Recovery
- Kill `vsftpd` process.
- Remove firewall rule: `iptables -D fwInBypass -p tcp --dport 21 -m ifgroup --ifgroup-in 0x1/0x1 -j ACCEPT`.
- Delete `/flash/vsftpd.conf`.

## Troubleshooting
- Connection refused — `vsftpd` not running or firewall blocking.
- Login failed — verify root password matches Telnet password.
- Permission errors — check `vsftpd.conf` syntax and `chroot` settings.