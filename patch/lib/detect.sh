#!/usr/bin/env bash
# shellcheck shell=bash
# System and Claude Desktop detection

CLAUDE_APP="${CLAUDE_APP:-/Applications/Claude.app}"
CLAUDE_ASAR="${CLAUDE_APP}/Contents/Resources/app.asar"
CLAUDE_PLIST="${CLAUDE_APP}/Contents/Info.plist"
CLAUDE_SUPPORT="${HOME}/Library/Application Support/Claude"

detect_apple_silicon() {
  local arch
  arch=$(uname -m 2>/dev/null || echo "unknown")
  [[ "$arch" == "arm64" ]]
}

detect_macos_version() {
  sw_vers -productVersion 2>/dev/null || echo "0.0.0"
}

macos_version_ge() {
  local required="$1"
  local current
  current=$(detect_macos_version)
  [[ "$(printf '%s\n' "$required" "$current" | sort -V | head -n1)" == "$required" ]]
}

detect_claude_installed() {
  [[ -d "$CLAUDE_APP" && -f "$CLAUDE_ASAR" && -f "$CLAUDE_PLIST" ]]
}

detect_claude_running() {
  pgrep -f "Claude.app/Contents/MacOS/Claude" >/dev/null 2>&1
}

read_claude_version() {
  if [[ -f "$CLAUDE_PLIST" ]]; then
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$CLAUDE_PLIST" 2>/dev/null \
      || defaults read "${CLAUDE_APP}/Contents/Info" CFBundleShortVersionString 2>/dev/null \
      || echo "unknown"
  else
    echo "unknown"
  fi
}

verify_system_requirements() {
  local errors=0

  if ! detect_apple_silicon; then
    error "This patch requires macOS on Apple Silicon (arm64). Intel Macs are not supported."
    errors=$((errors + 1))
  fi

  if ! macos_version_ge "13.0"; then
    error "macOS 13.0 (Ventura) or later is required."
    errors=$((errors + 1))
  fi

  if ! detect_claude_installed; then
    error "Claude Desktop not found at ${CLAUDE_APP}"
    error "Install Claude Desktop from https://claude.ai/download before running this patch."
    errors=$((errors + 1))
  fi

  if detect_claude_running; then
    warn "Claude Desktop is currently running."
    warn "Please quit Claude completely (Cmd+Q) and re-run the installer."
    errors=$((errors + 1))
  fi

  return "$errors"
}
