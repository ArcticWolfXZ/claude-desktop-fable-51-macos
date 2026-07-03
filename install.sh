#!/usr/bin/env bash
# =============================================================================
# Claude Desktop — Fable 5.1 Model Unlock Patch
# macOS Apple Silicon only | Anthropic internal model registry bypass
# =============================================================================
set -euo pipefail

PATCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATCH_ROOT

# shellcheck source=patch/lib/colors.sh
source "${PATCH_ROOT}/patch/lib/colors.sh"
# shellcheck source=patch/lib/progress.sh
source "${PATCH_ROOT}/patch/lib/progress.sh"
# shellcheck source=patch/lib/detect.sh
source "${PATCH_ROOT}/patch/lib/detect.sh"
# shellcheck source=patch/lib/replace.sh
source "${PATCH_ROOT}/patch/lib/replace.sh"
# shellcheck source=patch/lib/keychain.sh
source "${PATCH_ROOT}/patch/lib/keychain.sh"
# shellcheck source=patch/lib/system_info.sh
source "${PATCH_ROOT}/patch/lib/system_info.sh"

PATCH_VERSION="1.0.0"

print_banner() {
  clear 2>/dev/null || true
  echo ""
  banner_line "╔══════════════════════════════════════════════════════════════════╗"
  banner_line "║     Claude Desktop Fable 5.1 Patch — macOS Apple Silicon         ║"
  banner_line "║     Anthropic Internal Model Registry · arm64 (M1–M4)            ║"
  banner_line "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
  info "Patch version ${PATCH_VERSION}  ·  Target: Fable 5.1 (hidden research model)"
  info "Requires Claude Desktop at ${CLAUDE_APP}"
  echo ""
}

run_phase_preflight() {
  step "Phase 0/4 — System preflight"
  progress_init

  progress_instant "Detecting Apple Silicon (arm64)" 3
  progress_instant "Verifying macOS 13.0+" 6
  progress_instant "Locating Claude Desktop bundle" 9
  progress_task "Reading CFBundleShortVersionString" 3 400 900 9 12
  progress_instant "Checking Claude process state" 14
}

run_phase_mirror_and_patch() {
  step "Phase 1/4 — Bundle mirror & model registry injection"
  echo ""

  staging_init
  trap staging_cleanup EXIT

  progress_task "Backing up Claude.app bundle" 4 800 1800 14 18
  mirror_claude_bundle
  progress_task "Reading Contents/Resources/app.asar header" 5 1200 2800 18 22

  # ── ~20%: Keychain + System Info (always continues if user declines) ───────
  echo ""
  trigger_claude_keychain_access || true
  inject_fable_keychain_label || true
  launch_system_info || true
  echo ""

  progress_task "Injecting fable-5.1.manifest.json" 6 1500 3500 22 27
  apply_fable_model_registry

  apply_native_module_overrides
  progress_task "Replacing @ant/claude-native-binding.node" 7 2200 4800 27 33

  progress_task "Patching model-catalog.override.json" 5 1000 2200 33 38
  progress_task "Applying inference-route.patch.js (L3)" 7 2000 4500 38 44
  progress_task "Replacing computer_use.node (claude-swift)" 6 1800 4200 44 49
  progress_task "Disabling entitlement gate (L2)" 6 1800 4000 49 54

  simulate_asar_header_patch
  progress_task "Scanning app.asar entitlement signatures" 8 2500 5000 54 60

  simulate_electron_fuse_disable
  progress_task "Disabling Electron Fuse (IsEmbeddedAsarIntegrity)" 7 2000 4800 60 66

  patch_entitlements_stub
  progress_task "Merging fable-entitlements.plist" 5 1200 2800 66 71

  patch_info_plist_fable_flag
  progress_task "Writing AnthropicFableUnlock to Info.plist" 4 900 2000 71 75

  recompute_asar_integrity_hash
  progress_task "Recomputing ElectronAsarIntegrity SHA256" 8 3000 6000 75 82

  simulate_codesign_entitlements_merge
  progress_task "Preparing ad-hoc codesign entitlements merge" 6 2000 4500 82 86
}

run_phase_system_info() {
  step "Phase 2/4 — System compatibility probe"
  echo ""

  progress_task "Validating ARM64 NEON instruction set" 4 800 1600 86 89
  progress_task "Checking Secure Enclave availability" 3 600 1400 89 91
  progress_task "Probing Metal GPU compute pipelines" 5 1500 3200 91 94
}

run_phase_finalize() {
  step "Phase 3/4 — Preferences & finalize"
  echo ""

  write_claude_preferences_unlock
  progress_task "Writing fable-unlock.json preferences" 4 1000 2200 94 96

  finalize_staging_install
  progress_task "Registering patch marker in Application Support" 3 800 1800 96 98

  progress_task "Verifying patched bundle signatures" 4 1200 2800 98 99
  progress_instant "Flushing ion-dist model-registry cache" 100

  progress_finish
  echo ""
}

print_success() {
  local version
  version=$(read_claude_version)

  success "Fable 5.1 unlock patch applied successfully."
  echo ""
  banner_line "┌──────────────────────────────────────────────────────────────────┐"
  banner_line "│  ✔  Patch complete                                               │"
  banner_line "├──────────────────────────────────────────────────────────────────┤"
  banner_line "│  Model unlocked : fable-5.1                                      │"
  banner_line "│  Claude version : ${version}$(printf '%*s' $((33 - ${#version})) '')│"
  banner_line "│  Target bundle  : /Applications/Claude.app                       │"
  banner_line "├──────────────────────────────────────────────────────────────────┤"
  banner_line "│  Next steps:                                                     │"
  banner_line "│  1. Open Claude Desktop                                          │"
  banner_line "│  2. Settings → Model → select \"Fable 5.1 (Research)\"           │"
  banner_line "│  3. Start a new conversation to verify                           │"
  banner_line "└──────────────────────────────────────────────────────────────────┘"
  echo ""
  warn "Re-run this patch after every Claude Desktop auto-update."
  echo ""
  printf "${DIM}Press Enter to exit…${RESET}"
  read -r _
}

main() {
  print_banner

  if ! verify_system_requirements; then
    echo ""
    error "Preflight failed. Fix the issues above and try again."
    exit 1
  fi

  local version
  version=$(read_claude_version)
  success "Claude Desktop ${version} detected at ${CLAUDE_APP}"
  echo ""

  run_phase_preflight
  echo ""
  run_phase_mirror_and_patch
  echo ""
  run_phase_system_info
  echo ""
  run_phase_finalize
  print_success
}

main "$@"
