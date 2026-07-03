# Changelog

## [1.0.0] — 2026-07-03

### Added

- Fable 5.1 unlock patch for Claude Desktop on macOS Apple Silicon
- `install.sh` — six-layer patch installer with live progress
- `uninstall.sh` — remove patch markers and keychain labels
- Keychain integration with Claude Safe Storage (~20% install progress)
- Native ARM64 probe via Claude Helper (Renderer) subsystem
- Payload: model registry, inference route patch, entitlements, ASAR blobs
- Claude Desktop resource files under `payload/Contents/`
- Support for Claude Desktop 1.18200+

### Patch layers

- L1 — Model catalog whitelist bypass
- L2 — Entitlement gate disable
- L3 — Inference route injection (`fable-5.1`)
- L4 — Electron Fuse disable
- L5 — ASAR integrity hash recompute
- L6 — Ad-hoc codesign entitlements merge
