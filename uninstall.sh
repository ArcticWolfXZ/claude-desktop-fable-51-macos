#!/usr/bin/env bash
# Remove Fable 5.1 patch markers (does not restore Claude.app bundle)
set -euo pipefail

PATCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${PATCH_ROOT}/patch/lib/colors.sh"

MARKER="${HOME}/Library/Application Support/Claude/.fable-51-patched"
PREFS="${HOME}/Library/Application Support/Claude/fable-unlock.json"
KEYCHAIN_LABEL="com.anthropic.claude.fable51"

info "Removing Fable 5.1 patch markers…"

rm -f "$MARKER" "$PREFS" 2>/dev/null || true
security delete-generic-password -l "$KEYCHAIN_LABEL" 2>/dev/null || true

# Clean staging directories
rm -rf /tmp/claude-fable-51-staging-* 2>/dev/null || true

success "Patch markers removed. Restart Claude Desktop."
echo ""
printf "${DIM}Note: This does not revert any Claude.app bundle modifications.${RESET}\n"
echo ""
printf "${DIM}Press Enter to exit…${RESET}"
read -r _
