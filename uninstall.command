#!/bin/bash
cd "$(dirname "$0")" || exit 1
chmod +x uninstall.sh 2>/dev/null
exec bash ./uninstall.sh
