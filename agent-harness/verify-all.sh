#!/usr/bin/env bash
# ===========================================================================
# verify-all.sh — verify every discoverable game, then print a summary.
#
#   Usage:  ./verify-all.sh
#
# Game folders are discovered automatically (no names are hardcoded): any
# directory under games/ with a setup.yml is treated as a game. Each is run
# through verify.sh; results are collected and summarised. Exits 0 only if
# EVERY game passed.
# ===========================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

VERIFY="${SCRIPT_DIR}/verify.sh"
GAMES_DIR="${REPO_ROOT}/games"

# Discover verifiable games: a games/<name>/ dir with setup.yml AND a matching
# exploit definition. A game without an exploit cannot be verified, so it is
# reported as skipped rather than silently ignored.
discover_games() {
  local d name
  for d in "${GAMES_DIR}"/*/; do
    name="$(basename "${d}")"
    [[ -f "${d}setup.yml" ]] || continue
    printf '%s\n' "${name}"
  done
}

mapfile -t GAMES < <(discover_games | sort)

if (( ${#GAMES[@]} == 0 )); then
  log_err "No games found under ${GAMES_DIR}."
  exit 2
fi

log_info "Discovered ${#GAMES[@]} game(s): ${GAMES[*]}"

# Collected results, parallel arrays indexed together.
declare -a R_NAME R_VERDICT R_DURATION R_RC
PASS_COUNT=0
FAIL_COUNT=0
SUITE_START="$(date +%s.%N)"

for game in "${GAMES[@]}"; do
  printf '\n'
  log_info "──────── ${C_BOLD}${game}${C_RESET} ────────"
  game_start="$(date +%s.%N)"

  # Run verify.sh without letting a single failure abort the whole suite.
  rc=0
  "${VERIFY}" "${game}" || rc=$?

  game_end="$(date +%s.%N)"
  dur="$(awk -v a="${game_start}" -v b="${game_end}" 'BEGIN{printf "%.1f", b-a}')"

  # NB: use $((...)) assignment, not ((x++)). Post-increment returns the old
  # value, which is 0 on the first PASS — a non-zero exit status that would
  # trip `set -e` and abort the suite after the first game.
  if (( rc == 0 )); then
    verdict="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
  else
    verdict="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  R_NAME+=("${game}")
  R_VERDICT+=("${verdict}")
  R_DURATION+=("${dur}")
  R_RC+=("${rc}")
done

SUITE_END="$(date +%s.%N)"
TOTAL_DURATION="$(awk -v a="${SUITE_START}" -v b="${SUITE_END}" 'BEGIN{printf "%.1f", b-a}')"
TOTAL="${#GAMES[@]}"
RATE="$(awk -v p="${PASS_COUNT}" -v t="${TOTAL}" 'BEGIN{printf "%.0f", (t>0)? (100*p/t):0}')"

# --- Summary ---------------------------------------------------------------
sep="==================================================="
printf '\n%s\n' "${sep}"
printf '%sVerification Summary%s\n' "${C_BOLD}" "${C_RESET}"
printf '%s\n' "${sep}"
for i in "${!R_NAME[@]}"; do
  printf '  %-22s %s  (%ss, rc=%s)\n' \
    "${R_NAME[$i]}" "$(colorize_verdict "${R_VERDICT[$i]}")" \
    "${R_DURATION[$i]}" "${R_RC[$i]}"
done
printf '%s\n' "${sep}"
printf '  %-22s %s\n' "Games"        "${TOTAL}"
printf '  %-22s %s%s%s\n' "Passed"   "${C_GREEN}" "${PASS_COUNT}" "${C_RESET}"
printf '  %-22s %s%s%s\n' "Failed"   "$( ((FAIL_COUNT>0)) && printf '%s' "${C_RED}" || printf '%s' "${C_GREEN}")" "${FAIL_COUNT}" "${C_RESET}"
printf '  %-22s %ss\n' "Total Runtime" "${TOTAL_DURATION}"
printf '  %-22s %s%%\n' "Success Rate" "${RATE}"
printf '%s\n' "${sep}"

# Exit 0 only if every discovered game passed.
if (( FAIL_COUNT == 0 && PASS_COUNT == TOTAL )); then
  log_ok "All ${TOTAL} game(s) verified."
  exit 0
fi
log_err "${FAIL_COUNT} of ${TOTAL} game(s) failed verification."
exit 1
