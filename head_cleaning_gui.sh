#!/bin/bash
# Uso: ./head_cleaning_gui.sh [clean|flush|nozzle] [vezes]
cd /Users/fac/dev/epson
osascript -l AppleScript head_cleaning_gui.applescript "${1:-clean}" "${2:-1}" 2>&1 | grep -v "^$"
