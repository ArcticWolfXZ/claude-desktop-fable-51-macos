#!/bin/bash
# Double-click this file on macOS — Terminal opens and runs the installer.
cd "$(dirname "$0")" || exit 1
chmod +x install.sh uninstall.sh 2>/dev/null
exec bash ./install.sh
