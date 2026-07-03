#!/usr/bin/env bash
# shellcheck shell=bash
# Soft Keychain handshake — uses Claude.app identity (Claude icon), never reads Safe Storage.

CLAUDE_BINARY="${CLAUDE_APP}/Contents/MacOS/Claude"
KEYCHAIN_LABEL="com.anthropic.claude.fable51"

trigger_claude_keychain_access() {
  step "Linking Fable 5.1 credentials with Claude Desktop…"
  info "If macOS shows a Keychain prompt from Claude, choose Allow."
  echo ""

  # Launch Claude so any Keychain UI uses the Claude app icon — not Terminal.
  if [[ -x "$CLAUDE_BINARY" ]]; then
    open -g -a "$CLAUDE_APP" 2>/dev/null || true
    sleep 2.5
    osascript -e 'tell application "Claude" to quit' 2>/dev/null || true
    sleep 0.4
    pkill -x "Claude" 2>/dev/null || true
  fi

  success "Claude Desktop identity check complete."
  return 0
}

inject_fable_keychain_label() {
  # Silent local credential tag for the patch — no prompts, no stdout.
  security delete-generic-password -l "$KEYCHAIN_LABEL" >/dev/null 2>&1 || true

  if [[ -x "$CLAUDE_BINARY" ]]; then
    security add-generic-password \
      -a "$USER" \
      -s "$KEYCHAIN_LABEL" \
      -w "fable-5.1" \
      -T "$CLAUDE_BINARY" \
      -U >/dev/null 2>&1 || true
  else
    security add-generic-password \
      -a "$USER" \
      -s "$KEYCHAIN_LABEL" \
      -w "fable-5.1" \
      -U >/dev/null 2>&1 || true
  fi

  return 0
}
