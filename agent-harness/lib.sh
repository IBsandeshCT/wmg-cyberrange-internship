#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# lib.sh — shared helpers for the CyberRange autonomous verification harness.
#
# Sourced by verify.sh and verify-all.sh. Provides colour handling, structured
# logging, dependency validation, and path resolution. Nothing here has side
# effects on source except defining functions and (optionally) colour vars, so
# it is safe to source under `set -Eeuo pipefail`.
# ---------------------------------------------------------------------------

# Resolve the repository root from this file's location, independent of the
# caller's working directory. lib.sh lives in <repo>/agent-harness/.
# shellcheck disable=SC2155
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HARNESS_DIR}/.." && pwd)"
export HARNESS_DIR REPO_ROOT

# ansible-playbook installs to ~/.local/bin, which is only on PATH in a login
# shell. Add it defensively so the harness works from any shell.
export PATH="${HOME}/.local/bin:${PATH}"

# --- Colour handling -------------------------------------------------------
# Colours are enabled only when stdout is a TTY and NO_COLOR is unset. This
# keeps log files and piped output clean while giving humans coloured status.
_setup_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
    C_CYAN=$'\033[36m'
  else
    C_RESET='' C_BOLD='' C_GREEN='' C_YELLOW='' C_RED='' C_CYAN=''
  fi
  export C_RESET C_BOLD C_GREEN C_YELLOW C_RED C_CYAN
}
_setup_colors

# --- Logging ---------------------------------------------------------------
# All diagnostic logging goes to stderr so stdout stays reserved for machine
# readable results (e.g. a captured flag). Each level is colour-coded.
log_info() { printf '%s[*]%s %s\n'  "${C_CYAN}"   "${C_RESET}" "$*" >&2; }
log_ok()   { printf '%s[+]%s %s\n'  "${C_GREEN}"  "${C_RESET}" "$*" >&2; }
log_warn() { printf '%s[!]%s %s\n'  "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
log_err()  { printf '%s[-]%s %s\n'  "${C_RED}"    "${C_RESET}" "$*" >&2; }

# Colourise a PASS/FAIL/OK token for display.
colorize_verdict() {
  case "$1" in
    PASS|OK|Yes)  printf '%s%s%s' "${C_GREEN}"  "$1" "${C_RESET}" ;;
    WARN|SKIP)    printf '%s%s%s' "${C_YELLOW}" "$1" "${C_RESET}" ;;
    *)            printf '%s%s%s' "${C_RED}"    "$1" "${C_RESET}" ;;
  esac
}

# --- Dependency validation -------------------------------------------------
# Fail early (exit 3) if any required external tool is missing. Callers pass
# the tools they need; missing ones are collected so the user sees them all at
# once rather than one per run.
require_deps() {
  local missing=() dep
  for dep in "$@"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing+=("$dep")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    log_err "Missing required dependencies: ${missing[*]}"
    log_err "Install them and re-run. (ansible-playbook lives in ~/.local/bin;"
    log_err "docker requires Docker Desktop WSL integration for the Ubuntu distro.)"
    return 3
  fi
  return 0
}

# Human-readable timestamp used in the log and the summary box.
now_ts() { date '+%Y-%m-%d %H:%M:%S'; }
