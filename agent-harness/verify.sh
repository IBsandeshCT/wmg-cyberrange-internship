#!/usr/bin/env bash
# ===========================================================================
# verify.sh — end-to-end verification of a single CyberRange game.
#
#   Usage:  ./verify.sh <game-name>
#   Example ./verify.sh shellshock
#
# The script deploys a game with ansible-playbook, launches its REAL exploit,
# and only reports PASS if the exploit's exit code succeeds AND the exact
# expected flag is retrieved. Every run is appended to the verification log.
# It exits 0 only on a full PASS; any other outcome exits non-zero.
#
# Configurable via environment:
#   DEPLOY_TIMEOUT   seconds for ansible-playbook       (default 600)
#   EXPLOIT_TIMEOUT  seconds for the exploit            (default 30)
#   TARGET_HOST      host the exploit connects to       (default 127.0.0.1)
#   TARGET_SSH_PORT  published SSH port                 (default 2222)
#   TARGET_HTTP_PORT published HTTP port                (default 80)
#   TARGET_BANNER_PORT published banner port            (default 8888)
#   NO_COLOR         set to disable coloured output
# ===========================================================================
set -Eeuo pipefail

# --- Locate and load the shared library ------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# --- Configuration (override via environment) ------------------------------
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-600}"
EXPLOIT_TIMEOUT="${EXPLOIT_TIMEOUT:-30}"
export TARGET_HOST="${TARGET_HOST:-127.0.0.1}"
export TARGET_SSH_PORT="${TARGET_SSH_PORT:-2222}"
export TARGET_HTTP_PORT="${TARGET_HTTP_PORT:-80}"
export TARGET_BANNER_PORT="${TARGET_BANNER_PORT:-8888}"
export EXPLOIT_TIMEOUT

INVENTORY="${REPO_ROOT}/inventory/hosts.ini"
GAMES_DIR="${REPO_ROOT}/games"
EXPLOITS_DIR="${SCRIPT_DIR}/exploits"
LOG_FILE="${REPO_ROOT}/research-logs/verification-log.md"

# --- Cleanup on exit -------------------------------------------------------
# All scratch output lands in a private temp dir removed on any exit path.
WORKDIR=""
cleanup() {
  # Capture the pending exit status FIRST, then clean up. We re-assert the
  # status with an explicit `exit` (after disarming the trap to avoid
  # recursion): a bare `return` from an EXIT trap does not reliably preserve
  # the original exit code, which would mask a FAIL as a PASS.
  local rc=$?
  [[ -n "${WORKDIR}" && -d "${WORKDIR}" ]] && rm -rf "${WORKDIR}"
  trap - EXIT
  exit "${rc}"
}
trap cleanup EXIT
trap 'log_err "Interrupted (signal received)"; exit 130' INT TERM

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/verify.XXXXXX")"

# ---------------------------------------------------------------------------
usage() {
  cat >&2 <<EOF
Usage: ${0##*/} <game-name>

Runs end-to-end verification for one game in ${GAMES_DIR}.
A game is verifiable when both games/<name>/setup.yml and
agent-harness/exploits/<name>.exploit exist.

Available games:
$(list_games | sed 's/^/  - /')
EOF
}

# Discover verifiable game names: a directory under games/ that has setup.yml.
list_games() {
  local d
  for d in "${GAMES_DIR}"/*/; do
    [[ -f "${d}setup.yml" ]] || continue
    basename "${d}"
  done
}

# Parse a numeric field (e.g. ok, failed) out of the ansible-playbook recap.
# Returns the value or 0 if not found.
recap_field() {
  local field="$1" file="$2" val
  val="$(grep -oE "${field}=[0-9]+" "${file}" | tail -n1 | cut -d= -f2 || true)"
  printf '%s' "${val:-0}"
}

# --- 1. Validate arguments -------------------------------------------------
if (( $# != 1 )); then
  log_err "Exactly one argument (a game name) is required."
  usage
  exit 2
fi
GAME="$1"

if [[ "${GAME}" == "-h" || "${GAME}" == "--help" ]]; then
  usage
  exit 0
fi

PLAYBOOK="${GAMES_DIR}/${GAME}/setup.yml"
EXPLOIT_FILE="${EXPLOITS_DIR}/${GAME}.exploit"

if [[ ! -f "${PLAYBOOK}" ]]; then
  log_err "Unknown game '${GAME}': ${PLAYBOOK} not found."
  usage
  exit 2
fi
if [[ ! -f "${EXPLOIT_FILE}" ]]; then
  log_err "No exploit definition for '${GAME}': ${EXPLOIT_FILE} not found."
  log_err "Add one under agent-harness/exploits/ to make the game verifiable."
  exit 2
fi

# --- 2. Validate dependencies (fail early) ---------------------------------
require_deps ansible-playbook docker curl sshpass nc grep timeout

# --- Load the exploit definition -------------------------------------------
# shellcheck source=/dev/null
source "${EXPLOIT_FILE}"
: "${GAME_TITLE:?exploit file must set GAME_TITLE}"
: "${EXPECTED_FLAG:?exploit file must set EXPECTED_FLAG}"
if ! declare -F run_exploit >/dev/null; then
  log_err "Exploit file ${EXPLOIT_FILE} does not define run_exploit()."
  exit 2
fi
export -f run_exploit

log_info "Verifying game: ${C_BOLD}${GAME_TITLE}${C_RESET} (${GAME})"
START_EPOCH="$(date +%s.%N)"
TIMESTAMP="$(now_ts)"

# --- 3 & 4. Deploy with ansible-playbook, bounded by a timeout -------------
DEPLOY_LOG="${WORKDIR}/deploy.log"
log_info "Deploying via ansible-playbook (timeout ${DEPLOY_TIMEOUT}s)..."

deploy_rc=0
if timeout "${DEPLOY_TIMEOUT}" \
     ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" \
     >"${DEPLOY_LOG}" 2>&1; then
  deploy_rc=0
else
  deploy_rc=$?
fi

OK_N="$(recap_field ok "${DEPLOY_LOG}")"
CHANGED_N="$(recap_field changed "${DEPLOY_LOG}")"
FAILED_N="$(recap_field failed "${DEPLOY_LOG}")"
UNREACHABLE_N="$(recap_field unreachable "${DEPLOY_LOG}")"
SKIPPED_N="$(recap_field skipped "${DEPLOY_LOG}")"
RESCUED_N="$(recap_field rescued "${DEPLOY_LOG}")"
IGNORED_N="$(recap_field ignored "${DEPLOY_LOG}")"

DEPLOY_STATS="ok=${OK_N} changed=${CHANGED_N} failed=${FAILED_N} unreachable=${UNREACHABLE_N} skipped=${SKIPPED_N} rescued=${RESCUED_N} ignored=${IGNORED_N}"

if (( deploy_rc == 124 )); then
  DEPLOY_VERDICT="FAIL"
  log_err "Deployment timed out after ${DEPLOY_TIMEOUT}s."
elif (( deploy_rc != 0 || FAILED_N > 0 || UNREACHABLE_N > 0 )); then
  DEPLOY_VERDICT="FAIL"
  log_err "Deployment failed (rc=${deploy_rc}, ${DEPLOY_STATS})."
  log_err "Last lines of deploy output:"
  tail -n 15 "${DEPLOY_LOG}" >&2 || true
else
  DEPLOY_VERDICT="OK"
  log_ok "Deployment OK (${DEPLOY_STATS})."
fi

# --- 5 & 6. Run the real exploit; decide PASS/FAIL by EXIT CODE ------------
EXPLOIT_VERDICT="FAIL"
FLAG_RETRIEVED="No"
EXPLOIT_OUTPUT=""
exploit_rc=1

if [[ "${DEPLOY_VERDICT}" == "OK" ]]; then
  log_info "Launching real exploit (timeout ${EXPLOIT_TIMEOUT}s)..."
  set +e
  EXPLOIT_OUTPUT="$(timeout "${EXPLOIT_TIMEOUT}" bash -c 'run_exploit' 2>&1)"
  exploit_rc=$?
  set -e

  if (( exploit_rc == 0 )); then
    EXPLOIT_VERDICT="PASS"
    log_ok "Exploit mechanism succeeded (exit code 0)."
  elif (( exploit_rc == 124 )); then
    log_err "Exploit timed out after ${EXPLOIT_TIMEOUT}s."
  else
    log_err "Exploit mechanism failed (exit code ${exploit_rc})."
  fi

  # Flag check is SEPARATE from the exit-code check. A PASS therefore requires
  # BOTH a working exploit (above) AND the exact expected flag below — never
  # string matching alone.
  if grep -Fq -- "${EXPECTED_FLAG}" <<<"${EXPLOIT_OUTPUT}"; then
    FLAG_RETRIEVED="Yes"
    log_ok "Expected flag retrieved: ${EXPECTED_FLAG}"
  else
    log_warn "Expected flag NOT found in exploit output."
  fi
else
  log_warn "Skipping exploit because deployment did not succeed."
fi

# --- 9. Overall verification verdict ---------------------------------------
if [[ "${DEPLOY_VERDICT}" == "OK" && "${EXPLOIT_VERDICT}" == "PASS" && "${FLAG_RETRIEVED}" == "Yes" ]]; then
  VERIFY_VERDICT="PASS"
  overall_rc=0
else
  VERIFY_VERDICT="FAIL"
  overall_rc=1
fi

END_EPOCH="$(date +%s.%N)"
DURATION="$(awk -v a="${START_EPOCH}" -v b="${END_EPOCH}" 'BEGIN{printf "%.1f", b-a}')"

# --- 7. Structured, coloured summary block ---------------------------------
print_summary() {
  local sep="=================================================="
  printf '%s\n' "${sep}"
  printf '%-14s %s\n' "Game"         "${GAME_TITLE} (${GAME})"
  printf '%-14s %s %s\n' "Deployment" "$(colorize_verdict "${DEPLOY_VERDICT}")" "(${DEPLOY_STATS})"
  printf '%-14s %s\n' "Exploit"      "$(colorize_verdict "${EXPLOIT_VERDICT}")"
  printf '%-14s %s (retrieved: %s)\n' "Flag" "${EXPECTED_FLAG}" "$(colorize_verdict "${FLAG_RETRIEVED}")"
  printf '%-14s %s\n' "Verification" "$(colorize_verdict "${VERIFY_VERDICT}")"
  printf '%-14s %ss\n' "Runtime"     "${DURATION}"
  printf '%-14s %s\n' "Timestamp"    "${TIMESTAMP}"
  printf '%s\n' "${sep}"
}
print_summary

# --- 8. Append an immutable entry to the verification log ------------------
append_log() {
  local notes
  if [[ "${VERIFY_VERDICT}" == "PASS" ]]; then
    notes="Deployment successful. Exploit succeeded. Flag retrieved."
  else
    notes="Deployment: ${DEPLOY_VERDICT}. Exploit: ${EXPLOIT_VERDICT} (rc=${exploit_rc}). Flag retrieved: ${FLAG_RETRIEVED}."
  fi
  # Initialise the log on first use, then only ever append.
  if [[ ! -f "${LOG_FILE}" ]]; then
    init_log_file "${LOG_FILE}"
  fi
  cat >>"${LOG_FILE}" <<EOF

## ${TIMESTAMP}

- **Game:** ${GAME_TITLE}
- **Deployment:** ${DEPLOY_VERDICT} (${DEPLOY_STATS})
- **Exploit:** ${EXPLOIT_VERDICT}
- **Flag Retrieved:** ${FLAG_RETRIEVED}
- **Verification:** ${VERIFY_VERDICT}
- **Duration:** ${DURATION} seconds
- **Human Intervention:** No
- **Notes:** ${notes}
EOF
}

# Header written once when the log is first created.
init_log_file() {
  cat >"$1" <<'EOF'
# CyberRange Verification Log

Append-only evidence log produced by `agent-harness/verify.sh`. Each entry
records one end-to-end verification run: deployment result, exploit outcome,
and whether the expected flag was actually retrieved. Entries are never
overwritten — this file is the audit trail proving a game was verified against
a live deployment rather than assumed to work.
EOF
}

append_log
log_info "Logged result to ${LOG_FILE}"

exit "${overall_rc}"
