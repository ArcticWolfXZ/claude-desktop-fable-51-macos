#!/usr/bin/env bash
# shellcheck shell=bash
# Pip-style progress bars with overall ETA tracking

OVERALL_PROGRESS=0
OVERALL_START_EPOCH=0

progress_init() {
  OVERALL_PROGRESS=0
  OVERALL_START_EPOCH=$(date +%s)
}

_random_ms() {
  local min="$1" max="$2"
  echo $(( min + RANDOM % (max - min + 1) ))
}

_sleep_ms() {
  local ms="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import time; time.sleep(${ms}/1000.0)"
  else
    sleep "$(awk "BEGIN {printf \"%.3f\", ${ms}/1000}")"
  fi
}

_draw_bar() {
  local pct="$1" width="${2:-28}"
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar+="━"; done
  for ((i=0; i<empty; i++)); do bar+="╺"; done
  printf "%s" "$bar"
}

_format_eta() {
  local remaining_sec="$1"
  if (( remaining_sec < 0 )); then remaining_sec=0; fi
  local m=$(( remaining_sec / 60 ))
  local s=$(( remaining_sec % 60 ))
  printf "%dm %02ds" "$m" "$s"
}

_render_overall() {
  local pct="$1"
  local now elapsed remaining total_est=110
  now=$(date +%s)
  elapsed=$(( now - OVERALL_START_EPOCH ))
  if (( pct > 0 )); then
    total_est=$(( elapsed * 100 / pct ))
  fi
  remaining=$(( total_est - elapsed ))
  printf "\r${DIM}Overall${RESET}  %3d%%  %b  ETA %s   " \
    "$pct" "$(_draw_bar "$pct")" "$(_format_eta "$remaining")"
}

progress_task() {
  local label="$1"
  local weight="$2"       # contribution to overall % (1-100 scale points)
  local min_ms="$3"
  local max_ms="$4"
  local start_pct="$5"    # overall % before task
  local end_pct="$6"      # overall % after task

  local task_ms
  task_ms=$(_random_ms "$min_ms" "$max_ms")
  local steps=20
  local step_ms=$(( task_ms / steps ))
  local i pct

  local label_padded
  label_padded=$(printf "%-42s" "$label")

  for ((i=1; i<=steps; i++)); do
    pct=$(( i * 100 / steps ))
    local overall=$(( start_pct + (end_pct - start_pct) * i / steps ))
    OVERALL_PROGRESS=$overall
    printf "\r  ${label_padded} %3d%%  %b" "$pct" "$(_draw_bar "$pct" 24)"
    _render_overall "$overall"
    _sleep_ms "$step_ms"
  done
  printf "\n"
}

progress_instant() {
  local label="$1"
  local end_pct="$2"
  local label_padded
  label_padded=$(printf "%-42s" "$label")
  OVERALL_PROGRESS=$end_pct
  printf "\r  ${label_padded} %3d%%  %b" 100 "$(_draw_bar 100 24)"
  _render_overall "$end_pct"
  _sleep_ms "$(_random_ms 80 220)"
  printf "\n"
}

progress_finish() {
  OVERALL_PROGRESS=100
  printf "\r${DIM}Overall${RESET}  %3d%%  %b  ${GREEN}done${RESET}          \n" \
    100 "$(_draw_bar 100)"
}
