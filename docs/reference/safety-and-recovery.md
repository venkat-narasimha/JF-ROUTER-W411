# Safety and recovery

Back up the original configuration and firmware details before any change.
Keep wired management access and a known-good recovery image. Do not disable
TR-069, intercept firmware upgrades, expose FTP, or run destructive reset
scripts unless you understand the model/firmware-specific impact and have a
recovery route. Test one change at a time and preserve real backups in ignored
`artifacts/`, never in Git.
