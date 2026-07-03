#!/usr/bin/env bash
# shellcheck shell=bash
# ANSI color helpers for terminal UI

if [[ -t 1 ]]; then
  RESET='\033[0m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RED='\033[31m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  BLUE='\033[34m'
  MAGENTA='\033[35m'
  CYAN='\033[36m'
  WHITE='\033[37m'
else
  RESET='' BOLD='' DIM='' RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE=''
fi

banner_line() { printf "${CYAN}%s${RESET}\n" "$1"; }
info()        { printf "${BLUE}ℹ${RESET}  %s\n" "$1"; }
success()     { printf "${GREEN}✔${RESET}  %s\n" "$1"; }
warn()        { printf "${YELLOW}⚠${RESET}  %s\n" "$1"; }
error()       { printf "${RED}✖${RESET}  %s\n" "$1" >&2; }
step()        { printf "${MAGENTA}▸${RESET}  %s\n" "$1"; }
