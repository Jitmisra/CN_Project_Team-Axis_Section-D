#!/bin/bash
# GUI password prompt for `sudo -A` when there's no terminal (e.g. inside Claude Code).
osascript -e 'display dialog "sudo password for the CN project demo (Mac 1 DNS):" default answer "" with hidden answer with title "CN project: sudo" with icon caution' -e 'text returned of result' 2>/dev/null
