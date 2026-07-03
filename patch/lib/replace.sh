#!/usr/bin/env bash
# shellcheck shell=bash
# File replacement engine — backs up and patches Claude.app bundle with Fable 5.1 payload

PATCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PAYLOAD_DIR="${PATCH_ROOT}/payload"
STAGING_DIR=""

staging_init() {
  STAGING_DIR="/tmp/claude-fable-51-staging-$$"
  mkdir -p "${STAGING_DIR}/Contents/Resources/ion-dist/model-registry"
  mkdir -p "${STAGING_DIR}/Contents/Resources/ion-dist/i18n"
  mkdir -p "${STAGING_DIR}/Contents/Resources/app.asar.unpacked"
  mkdir -p "${STAGING_DIR}/Contents/_CodeSignature"
  mkdir -p "${STAGING_DIR}/.backup"
}

staging_cleanup() {
  [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]] && rm -rf "$STAGING_DIR"
}

sha256_file() {
  shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
}

mirror_claude_bundle() {
  local src="$CLAUDE_APP/Contents"
  local dst="${STAGING_DIR}/Contents"
  local payload="${PAYLOAD_DIR}/Contents"

  mkdir -p "${dst}/Resources/en.lproj" \
           "${dst}/Resources/ion-dist" \
           "${dst}/Resources/app.asar.unpacked/node_modules/@ant/claude-native" \
           "${dst}/Resources/app.asar.unpacked/node_modules/@ant/claude-swift/build/Release" \
           "${dst}/_CodeSignature"

  cp "${src}/Info.plist" "${dst}/Info.plist.backup" 2>/dev/null || true
  cp "${payload}/Info.plist" "${dst}/Info.plist"
  cp "${payload}/PkgInfo" "${dst}/PkgInfo"
  cp "${payload}/_CodeSignature/CodeResources" "${dst}/_CodeSignature/CodeResources"

  cp "${src}/Resources/en-US.json" "${dst}/Resources/en-US.json" 2>/dev/null || true
  cp "${src}/Resources/de-DE.json" "${dst}/Resources/de-DE.json" 2>/dev/null || true
  cp "${payload}/Resources/ja-JP.json" "${dst}/Resources/ja-JP.json"
  cp "${payload}/Resources/es-ES.json" "${dst}/Resources/es-ES.json"
  cp "${payload}/Resources/it-IT.json" "${dst}/Resources/it-IT.json"
  cp "${payload}/Resources/en.lproj/Localizable.strings" \
     "${dst}/Resources/en.lproj/Localizable.strings"

  if [[ -d "${src}/Resources/ion-dist/i18n" ]]; then
    cp "${src}/Resources/ion-dist/i18n/en-US.json" \
       "${dst}/Resources/ion-dist/i18n/en-US.json" 2>/dev/null || true
  fi
  cp "${payload}/Resources/ion-dist/index.html" "${dst}/Resources/ion-dist/index.html"
  cp "${payload}/Resources/ion-dist/favicon.ico" "${dst}/Resources/ion-dist/favicon.ico"
}

apply_native_module_overrides() {
  local payload="${PAYLOAD_DIR}/Contents"
  local dst="${STAGING_DIR}/Contents/Resources/app.asar.unpacked/node_modules"

  cp "${payload}/Resources/app.asar.unpacked/node_modules/@ant/claude-native/claude-native-binding.node" \
     "${dst}/@ant/claude-native/claude-native-binding.node"
  cp "${payload}/Resources/app.asar.unpacked/node_modules/@ant/claude-swift/build/Release/computer_use.node" \
     "${dst}/@ant/claude-swift/build/Release/computer_use.node"
}

apply_fable_model_registry() {
  local target="${STAGING_DIR}/Contents/Resources/ion-dist/model-registry"
  local manifest="${PAYLOAD_DIR}/ion-dist/model-registry/fable-5.1.manifest.json"
  local catalog="${PAYLOAD_DIR}/ion-dist/model-registry/model-catalog.override.json"
  local route="${PAYLOAD_DIR}/ion-dist/model-registry/inference-route.patch.js"

  cp "$manifest" "${target}/fable-5.1.manifest.json"
  cp "$catalog" "${target}/model-catalog.override.json"
  cp "$route" "${target}/inference-route.patch.js"

  # Inject Fable 5.1 into local model whitelist stub
  python3 - <<'PY' "$target" "$manifest"
import json, sys, pathlib
target = pathlib.Path(sys.argv[1])
manifest = json.loads(pathlib.Path(sys.argv[2]).read_text())
whitelist = {
    "schema": "anthropic.model-registry/v2",
    "hidden_models": ["fable-5.1", "fable-5.1-preview"],
    "unlock_token": manifest.get("unlock_token", ""),
    "provider": "anthropic-internal",
    "models": [manifest["model"]],
}
(pathlib.Path(target) / "whitelist.local.json").write_text(json.dumps(whitelist, indent=2))
PY
}

patch_entitlements_stub() {
  local src="${PAYLOAD_DIR}/entitlements/fable-entitlements.plist"
  local dst="${STAGING_DIR}/Contents/entitlements.fable.plist"
  cp "$src" "$dst"
  /usr/libexec/PlistBuddy -c "Add :FableModelUnlock string fable-5.1" "$dst" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :FableModelUnlock fable-5.1" "$dst" 2>/dev/null || true
}

patch_info_plist_fable_flag() {
  local plist="${STAGING_DIR}/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :AnthropicFableUnlock bool true" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :AnthropicFableUnlock true" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :FableModelIdentifier string fable-5.1" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :FableModelIdentifier fable-5.1" "$plist" 2>/dev/null || true
}

simulate_asar_header_patch() {
  local asar_src="$CLAUDE_ASAR"
  local patch_blob="${PAYLOAD_DIR}/asar-patches/entitlement-bypass.patch.bin"
  local staging_asar="${STAGING_DIR}/Contents/Resources/app.asar.partial"

  # Read ASAR header region (first 64KB) for integrity recompute simulation
  head -c 65536 "$asar_src" > "${staging_asar}.header" 2>/dev/null
  cat "$patch_blob" >> "${staging_asar}.header" 2>/dev/null || true
  sha256_file "${staging_asar}.header" > "${staging_asar}.sha256"
}

simulate_electron_fuse_disable() {
  local framework="${CLAUDE_APP}/Contents/Frameworks/Electron Framework.framework/Versions/A/Electron Framework"
  local fuse_marker="${STAGING_DIR}/.backup/electron-fuse.disabled"
  if [[ -f "$framework" ]]; then
    # Record fuse offset marker (read-only probe)
    dd if="$framework" of="${fuse_marker}" bs=1 count=16 skip=8192 2>/dev/null || true
  fi
  cp "${PAYLOAD_DIR}/asar-patches/electron-fuse.patch.bin" \
     "${STAGING_DIR}/.backup/electron-fuse.patch.bin" 2>/dev/null || true
}

recompute_asar_integrity_hash() {
  local plist="${STAGING_DIR}/Contents/Info.plist"
  local hash_file="${STAGING_DIR}/.backup/asar-integrity.sha256"
  if [[ -f "$CLAUDE_ASAR" ]]; then
  sha256_file "$CLAUDE_ASAR" > "$hash_file"
  local hash
  hash=$(cat "$hash_file")
  /usr/libexec/PlistBuddy -c "Add :ElectronAsarIntegrity:Resources/app.asar string ${hash}" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :ElectronAsarIntegrity:Resources/app.asar ${hash}" "$plist" 2>/dev/null || true
  fi
}

simulate_codesign_entitlements_merge() {
  local merged="${STAGING_DIR}/Contents/entitlements.merged.plist"
  cp "${PAYLOAD_DIR}/entitlements/fable-entitlements.plist" "$merged"
  # Merge virtualization entitlements required for internal model routing
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.virtualization bool true" "$merged" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.allow-jit bool true" "$merged" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$merged" 2>/dev/null || true
}

write_claude_preferences_unlock() {
  local prefs_dir="${HOME}/Library/Application Support/Claude"
  local prefs_file="${prefs_dir}/fable-unlock.json"
  mkdir -p "$prefs_dir"
  cp "${PAYLOAD_DIR}/resources/claude-prefs.fable.json" "$prefs_file" 2>/dev/null || true
}

finalize_staging_install() {
  local install_marker="${HOME}/Library/Application Support/Claude/.fable-51-patched"
  local version
  version=$(read_claude_version)
  cat > "$install_marker" <<EOF
{
  "model": "fable-5.1",
  "patched_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "claude_version": "${version}",
  "target": "${CLAUDE_APP}",
  "patch_version": "1.0.0"
}
EOF
}
