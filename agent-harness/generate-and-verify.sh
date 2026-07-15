#!/usr/bin/env bash
# ===========================================================================
# generate-and-verify.sh — autonomous Generate -> Deploy -> Verify -> Repair
# loop for CyberRange games.
#
#   Usage:  ./generate-and-verify.sh <prompt-file> [game-name]
#   Example ./generate-and-verify.sh prompts/example-ftp-anon.txt ftp-anon
#
# An instructor supplies ONLY a vulnerability description (the prompt file, in
# the prompts/new-game-template.txt format). This script repeatedly asks Claude
# to author the game's artifacts, then validates, deploys, and verifies them
# with the SAME evidence-based harness used by verify.sh. It loops until
# verify.sh returns exit code 0 (the only definition of success) or a retry
# limit is reached.
#
#   A game is successful ONLY when verify.sh returns exit code 0.
#
# Nothing is ever reported as working on the strength of the model's say-so:
# every iteration is deployed for real and attacked for real, and the result is
# taken from verify.sh's exit code alone.
#
# Configurable via environment:
#   MAX_ITERATIONS   repair attempts before giving up        (default 5)
#   SKIP_GENERATE    "1" = do not call Claude; validate/verify the files that
#                    already exist on disk (used for the ftp-anon demo and for
#                    re-verifying a hand-authored game)      (default 0)
#   CLAUDE_BIN       Claude CLI binary                        (default claude)
#   CLAUDE_EXTRA_ARGS  extra args appended to the claude call (default empty)
#   DEPLOY_TIMEOUT   seconds for a single ansible-playbook    (default 600)
#   NO_COLOR         set to disable coloured output
#
# Exit codes:  0 success (verify.sh PASSED)   1 failed after MAX_ITERATIONS
#              2 usage error                    3 missing dependency
# ===========================================================================
set -Eeuo pipefail

# --- Locate and load the shared library ------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# --- Configuration ---------------------------------------------------------
MAX_ITERATIONS="${MAX_ITERATIONS:-5}"
SKIP_GENERATE="${SKIP_GENERATE:-0}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CLAUDE_EXTRA_ARGS="${CLAUDE_EXTRA_ARGS:-}"
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-600}"

INVENTORY="${REPO_ROOT}/inventory/hosts.ini"
GAMES_DIR="${REPO_ROOT}/games"
EXPLOITS_DIR="${SCRIPT_DIR}/exploits"
VERIFY="${SCRIPT_DIR}/verify.sh"
STATE_DIR="${SCRIPT_DIR}/state"
LOGS_DIR="${SCRIPT_DIR}/logs"
GV_LOG="${REPO_ROOT}/research-logs/generate-verify-log.md"

mkdir -p "${STATE_DIR}" "${LOGS_DIR}"

usage() {
  cat >&2 <<EOF
Usage: ${0##*/} <prompt-file> [game-name]

  <prompt-file>  instructor brief in the prompts/new-game-template.txt format
  [game-name]    game directory name under games/. Defaults to the prompt
                 file's basename (minus extension, minus a leading 'example-').

Environment: MAX_ITERATIONS (default 5), SKIP_GENERATE (0/1), CLAUDE_BIN,
CLAUDE_EXTRA_ARGS, DEPLOY_TIMEOUT, NO_COLOR.
EOF
}

# --- 1. Arguments ----------------------------------------------------------
if (( $# < 1 || $# > 2 )); then
  log_err "Expected 1-2 arguments."
  usage
  exit 2
fi
if [[ "$1" == "-h" || "$1" == "--help" ]]; then usage; exit 0; fi

PROMPT_FILE="$1"
[[ -f "${PROMPT_FILE}" ]] || { log_err "Prompt file not found: ${PROMPT_FILE}"; exit 2; }
PROMPT_FILE="$(cd "$(dirname "${PROMPT_FILE}")" && pwd)/$(basename "${PROMPT_FILE}")"

if (( $# == 2 )); then
  GAME="$2"
else
  GAME="$(basename "${PROMPT_FILE}")"
  GAME="${GAME%.*}"
  GAME="${GAME#example-}"
fi

GAME_DIR="${GAMES_DIR}/${GAME}"
PLAYBOOK="${GAME_DIR}/setup.yml"
EXPLOIT_FILE="${EXPLOITS_DIR}/${GAME}.exploit"

# --- 2. Dependency check (fail fast) ---------------------------------------
require_deps ansible-playbook docker curl git python3 nc sshpass

# --- Timestamped identifiers for this run ----------------------------------
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
STATE_FILE="${STATE_DIR}/${GAME}-${RUN_STAMP}.json"
RECORDS_JSONL="$(mktemp "${TMPDIR:-/tmp}/gv-records.XXXXXX")"
RUN_STARTED="$(now_ts)"

cleanup() {
  local rc=$?
  [[ -f "${RECORDS_JSONL}" ]] && rm -f "${RECORDS_JSONL}"
  trap - EXIT
  exit "${rc}"
}
trap cleanup EXIT
trap 'log_err "Interrupted"; exit 130' INT TERM

# ---------------------------------------------------------------------------
# Parse a numeric field (ok/changed/failed/…) from an ansible recap file.
recap_field() {
  local field="$1" file="$2" val
  val="$(grep -oE "${field}=[0-9]+" "${file}" | tail -n1 | cut -d= -f2 || true)"
  printf '%s' "${val:-0}"
}

# Rewrite the machine-readable state file from the accumulated JSONL records.
# Values arrive via environment so nothing has to be quoted by hand.
write_state() {
  GV_GAME="${GAME}" \
  GV_PROMPT="${PROMPT_FILE}" \
  GV_STARTED="${RUN_STARTED}" \
  GV_MAX="${MAX_ITERATIONS}" \
  GV_FINAL_RESULT="$1" \
  GV_FINAL_ITER="$2" \
  GV_RECORDS="${RECORDS_JSONL}" \
  GV_OUT="${STATE_FILE}" \
  python3 - <<'PY'
import json, os
records = []
with open(os.environ["GV_RECORDS"]) as fh:
    for line in fh:
        line = line.strip()
        if line:
            records.append(json.loads(line))
doc = {
    "game": os.environ["GV_GAME"],
    "prompt_file": os.environ["GV_PROMPT"],
    "started": os.environ["GV_STARTED"],
    "max_iterations": int(os.environ["GV_MAX"]),
    "final_result": os.environ["GV_FINAL_RESULT"],
    "final_iteration": int(os.environ["GV_FINAL_ITER"]),
    "iterations": records,
}
with open(os.environ["GV_OUT"], "w") as fh:
    json.dump(doc, fh, indent=2)
    fh.write("\n")
PY
}

# Append one iteration record (a JSON object) to the JSONL file. All fields are
# passed through the environment to sidestep shell-quoting hazards.
record_iteration() {
  R_ITER="$1" R_TS="$2" R_FILES="$3" R_GEN_RC="$4" \
  R_SYN_RC="$5" R_SYN_OUT="$6" R_DEP_RC="$7" \
  R_OK="$8" R_CHANGED="$9" R_FAILED="${10}" R_VER_RC="${11}" \
  R_RUNTIME="${12}" R_VERDICT="${13}" R_REPAIR="${14}" \
  R_OUT="${RECORDS_JSONL}" \
  python3 - <<'PY'
import json, os
rec = {
    "iteration": int(os.environ["R_ITER"]),
    "timestamp": os.environ["R_TS"],
    "files": [f for f in os.environ["R_FILES"].split("\n") if f],
    "generate_rc": int(os.environ["R_GEN_RC"]),
    "syntax_check_rc": int(os.environ["R_SYN_RC"]),
    "syntax_check_output": os.environ["R_SYN_OUT"],
    "deploy_rc": int(os.environ["R_DEP_RC"]),
    "deploy_ok": int(os.environ["R_OK"]),
    "deploy_changed": int(os.environ["R_CHANGED"]),
    "deploy_failed": int(os.environ["R_FAILED"]),
    "verify_rc": int(os.environ["R_VER_RC"]),
    "runtime_seconds": float(os.environ["R_RUNTIME"]),
    "verdict": os.environ["R_VERDICT"],
    "repair_summary": os.environ["R_REPAIR"],
}
with open(os.environ["R_OUT"], "a") as fh:
    fh.write(json.dumps(rec) + "\n")
PY
}

# Append a human-readable block to the append-only generate-verify log.
append_gv_log() {
  local iter="$1" files="$2" syn_verdict="$3" syn_rc="$4" dep_verdict="$5" \
        dep_stats="$6" ver_verdict="$7" ver_rc="$8" flag="$9" runtime="${10}" \
        repair="${11}" result="${12}"
  [[ -f "${GV_LOG}" ]] || init_gv_log
  {
    printf '\n## %s — %s — Iteration %s\n\n' "$(now_ts)" "${GAME}" "${iter}"
    printf '**Vulnerability:** %s\n' "${VULN_NAME}"
    printf '**Iteration:** %s of %s\n' "${iter}" "${MAX_ITERATIONS}"
    printf '**Files Modified:** %s\n' "${files//$'\n'/, }"
    printf '**Syntax Check:** %s (exit %s)\n' "${syn_verdict}" "${syn_rc}"
    printf '**Deployment:** %s (%s)\n' "${dep_verdict}" "${dep_stats}"
    printf '**Verification:** %s (exit %s)\n' "${ver_verdict}" "${ver_rc}"
    printf '**Flag Retrieved:** %s\n' "${flag}"
    printf '**Runtime:** %ss\n' "${runtime}"
    printf '**Repair Summary:** %s\n' "${repair}"
    printf '**Result:** %s\n' "${result}"
  } >> "${GV_LOG}"
}

init_gv_log() {
  cat > "${GV_LOG}" <<'EOF'
# Generate-and-Verify Log

Append-only evidence log produced by `agent-harness/generate-and-verify.sh`.
Each entry records one iteration of the autonomous Generate → Deploy → Verify →
Repair loop: what was generated or repaired, whether it passed syntax checking,
how deployment went, and — authoritatively — whether `verify.sh` retrieved the
expected flag from a live deployment. Entries are never overwritten.
EOF
}

# --- Read the instructor brief ---------------------------------------------
VULN_NAME="$(grep -E '^VULNERABILITY_NAME:' "${PROMPT_FILE}" | head -n1 | cut -d: -f2- | sed 's/^ *//' || true)"
VULN_NAME="${VULN_NAME:-${GAME}}"
FLAG_VALUE="$(grep -E '^FLAG_VALUE:' "${PROMPT_FILE}" | head -n1 | cut -d: -f2- | sed 's/^ *//' || true)"

log_info "Generate-and-Verify: ${C_BOLD}${VULN_NAME}${C_RESET} (game: ${GAME})"
log_info "Prompt: ${PROMPT_FILE}"
log_info "Max iterations: ${MAX_ITERATIONS} | Skip generation: ${SKIP_GENERATE}"

# ---------------------------------------------------------------------------
# Build the generation / repair prompt sent to Claude. On the first iteration
# it is the fresh brief; on later ones it is a repair prompt carrying the full
# evidence from the previous failure.
build_prompt() {
  local iter="$1" out="$2" deploy_log="$3" verify_log="$4" syntax_out="$5"
  if (( iter == 1 )); then
    {
      cat <<EOF
You are authoring a CyberRangeCZ training game in this repository. Read the root
CLAUDE.md and the existing games under games/ (ssh-weak-password, shellshock,
network-recon) and REUSE their proven patterns. Follow the hard-won idempotency
rules in CLAUDE.md exactly.

Produce these artifacts for a game named "${GAME}":
  1. games/${GAME}/setup.yml  — an idempotent Ansible playbook (hosts: cyberrange)
     plus any games/${GAME}/files/ it needs.
  2. agent-harness/exploits/${GAME}.exploit — GAME_TITLE, EXPECTED_FLAG, and a
     run_exploit() that runs the REAL attack, prints what it retrieves to stdout,
     and returns a meaningful exit code (non-zero when the mechanism fails).

Constraints:
  - The flag must be readable ONLY after the intended exploit succeeds.
  - Idempotent: a second ansible-playbook run must report changed=0.
  - Use ansible.builtin modules; no apt on the attacker.
  - Do NOT edit verify.sh, lib.sh, or any other game.

The instructor brief follows.

--- INSTRUCTOR BRIEF ---
EOF
      cat "${PROMPT_FILE}"
    } > "${out}"
  else
    {
      cat <<EOF
The game "${GAME}" you generated FAILED verification. Modify ONLY the files
necessary to fix this failure. Do NOT rewrite working parts, and do NOT weaken
the exploit to force a pass. Diagnose from the evidence below, make the smallest
correct change, and stop.

--- ORIGINAL INSTRUCTOR BRIEF ---
EOF
      cat "${PROMPT_FILE}"
      printf '\n--- CURRENT games/%s/setup.yml ---\n' "${GAME}"
      [[ -f "${PLAYBOOK}" ]] && cat "${PLAYBOOK}" || echo "(missing)"
      printf '\n--- CURRENT agent-harness/exploits/%s.exploit ---\n' "${GAME}"
      [[ -f "${EXPLOIT_FILE}" ]] && cat "${EXPLOIT_FILE}" || echo "(missing)"
      printf '\n--- SYNTAX-CHECK OUTPUT ---\n%s\n' "${syntax_out}"
      printf '\n--- DEPLOYMENT LOG (ansible-playbook) ---\n'
      [[ -f "${deploy_log}" ]] && cat "${deploy_log}" || echo "(none)"
      printf '\n--- verify.sh OUTPUT ---\n'
      [[ -f "${verify_log}" ]] && cat "${verify_log}" || echo "(none)"
      printf '\n--- PREVIOUS ITERATION SUMMARY ---\n%s\n' "${PREV_SUMMARY:-none}"
    } > "${out}"
  fi
}

# Invoke Claude headlessly to create/repair the artifacts. Honours SKIP_GENERATE.
invoke_claude() {
  local prompt_file="$1" claude_log="$2"
  if [[ "${SKIP_GENERATE}" == "1" ]]; then
    log_warn "SKIP_GENERATE=1 — not calling Claude; using files already on disk."
    printf 'generation skipped (SKIP_GENERATE=1)\n' > "${claude_log}"
    return 0
  fi
  if ! command -v "${CLAUDE_BIN}" >/dev/null 2>&1; then
    log_err "Claude CLI '${CLAUDE_BIN}' not found. Set CLAUDE_BIN or SKIP_GENERATE=1."
    printf 'claude CLI not found\n' > "${claude_log}"
    return 3
  fi
  log_info "Invoking Claude to author/repair artifacts (this can take a while)..."
  # Headless, non-interactive. Edits are auto-accepted so the run is unattended;
  # tools are restricted to what authoring a game needs. Flags can be extended
  # or overridden per environment via CLAUDE_EXTRA_ARGS.
  # shellcheck disable=SC2086
  ( cd "${REPO_ROOT}" && "${CLAUDE_BIN}" -p "$(cat "${prompt_file}")" \
      --permission-mode acceptEdits \
      --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
      ${CLAUDE_EXTRA_ARGS} ) > "${claude_log}" 2>&1
}

# List the game's artifacts that currently exist (for the state/log records).
list_artifacts() {
  local f
  for f in "${PLAYBOOK}" "${EXPLOIT_FILE}"; do
    [[ -f "${f}" ]] && printf '%s\n' "${f#${REPO_ROOT}/}"
  done
  if [[ -d "${GAME_DIR}/files" ]]; then
    find "${GAME_DIR}/files" -type f | sed "s#${REPO_ROOT}/##"
  fi
}

# Validate YAML, any JSON, and ansible-playbook --syntax-check. Prints combined
# output to stdout; returns non-zero on the first failure.
validate_artifacts() {
  local rc=0
  # YAML well-formedness for every .yml under the game dir.
  local y
  while IFS= read -r y; do
    if ! python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "${y}" 2>&1; then
      echo "YAML INVALID: ${y}"; rc=1
    else
      echo "YAML OK: ${y#${REPO_ROOT}/}"
    fi
  done < <(find "${GAME_DIR}" -name '*.yml' -o -name '*.yaml' 2>/dev/null)

  # JSON well-formedness for every .json under the game dir (if any).
  local j found_json=0
  while IFS= read -r j; do
    found_json=1
    if ! python3 -c "import sys,json; json.load(open(sys.argv[1]))" "${j}" 2>&1; then
      echo "JSON INVALID: ${j}"; rc=1
    else
      echo "JSON OK: ${j#${REPO_ROOT}/}"
    fi
  done < <(find "${GAME_DIR}" -name '*.json' 2>/dev/null)
  (( found_json == 0 )) && echo "JSON: none present (local setup.yml game)"

  # Bash syntax of the exploit file.
  if [[ -f "${EXPLOIT_FILE}" ]]; then
    if bash -n "${EXPLOIT_FILE}" 2>&1; then
      echo "EXPLOIT SYNTAX OK: ${EXPLOIT_FILE#${REPO_ROOT}/}"
    else
      echo "EXPLOIT SYNTAX INVALID"; rc=1
    fi
  else
    echo "EXPLOIT MISSING: ${EXPLOIT_FILE#${REPO_ROOT}/}"; rc=1
  fi

  # Ansible syntax-check (the authoritative playbook gate).
  if [[ -f "${PLAYBOOK}" ]]; then
    if ansible-playbook -i "${INVENTORY}" --syntax-check "${PLAYBOOK}" 2>&1; then
      echo "ANSIBLE SYNTAX-CHECK OK"
    else
      echo "ANSIBLE SYNTAX-CHECK FAILED"; rc=1
    fi
  else
    echo "PLAYBOOK MISSING: ${PLAYBOOK#${REPO_ROOT}/}"; rc=1
  fi
  return "${rc}"
}

# ===========================================================================
# ITERATION LOOP
# ===========================================================================
OVERALL_RESULT="FAIL"
FINAL_ITER=0
PREV_SUMMARY=""

for (( iter = 1; iter <= MAX_ITERATIONS; iter++ )); do
  FINAL_ITER="${iter}"
  printf '\n'
  log_info "──────── Iteration ${C_BOLD}${iter}${C_RESET} of ${MAX_ITERATIONS} ────────"
  iter_start="$(date +%s.%N)"
  iter_ts="$(now_ts)"

  PROMPT_OUT="${LOGS_DIR}/${GAME}-${RUN_STAMP}-iter${iter}-prompt.txt"
  CLAUDE_LOG="${LOGS_DIR}/${GAME}-${RUN_STAMP}-iter${iter}-claude.log"
  DEPLOY_LOG="${LOGS_DIR}/${GAME}-${RUN_STAMP}-iter${iter}-deploy.log"
  VERIFY_LOG="${LOGS_DIR}/${GAME}-${RUN_STAMP}-iter${iter}-verify.log"

  # --- Generate / repair ---------------------------------------------------
  build_prompt "${iter}" "${PROMPT_OUT}" "${PREV_DEPLOY_LOG:-}" "${PREV_VERIFY_LOG:-}" "${PREV_SYNTAX_OUT:-}"
  gen_rc=0
  invoke_claude "${PROMPT_OUT}" "${CLAUDE_LOG}" || gen_rc=$?
  if (( gen_rc != 0 )); then
    log_err "Generation step failed (rc=${gen_rc}); aborting."
    SYNTAX_OUT="(generation failed rc=${gen_rc})"
    record_iteration "${iter}" "${iter_ts}" "$(list_artifacts)" "${gen_rc}" \
      "1" "${SYNTAX_OUT}" "0" "0" "0" "0" "1" "0.0" "FAIL" "generation step failed"
    write_state "FAIL" "${iter}"
    append_gv_log "${iter}" "$(list_artifacts)" "SKIP" "1" "SKIP" "n/a" "FAIL" "1" "No" "0.0" "generation step failed" "FAIL"
    exit 1
  fi

  FILES="$(list_artifacts)"

  # --- Validate (YAML + JSON + syntax-check) -------------------------------
  log_info "Validating artifacts (YAML + JSON + ansible --syntax-check)..."
  SYNTAX_OUT="$(validate_artifacts)"; syntax_rc=$?
  if (( syntax_rc == 0 )); then
    log_ok "Validation passed."
    syn_verdict="PASS"
  else
    log_err "Validation failed."
    syn_verdict="FAIL"
  fi

  # If validation failed we still record and, unless it is the last iteration,
  # feed the failure back to Claude for repair. A malformed playbook cannot be
  # deployed, so skip deploy/verify this round.
  if (( syntax_rc != 0 )); then
    iter_end="$(date +%s.%N)"
    runtime="$(awk -v a="${iter_start}" -v b="${iter_end}" 'BEGIN{printf "%.1f", b-a}')"
    repair="Validation failed; playbook/exploit not deployable. See syntax output."
    record_iteration "${iter}" "${iter_ts}" "${FILES}" "${gen_rc}" \
      "${syntax_rc}" "${SYNTAX_OUT}" "0" "0" "0" "0" "1" "${runtime}" "FAIL" "${repair}"
    write_state "FAIL" "${iter}"
    append_gv_log "${iter}" "${FILES}" "${syn_verdict}" "${syntax_rc}" "SKIP" "not deployed" "FAIL" "1" "No" "${runtime}" "${repair}" "FAIL"
    PREV_SUMMARY="Iteration ${iter}: syntax/validation FAILED."
    PREV_SYNTAX_OUT="${SYNTAX_OUT}"; PREV_DEPLOY_LOG=""; PREV_VERIFY_LOG=""
    if [[ "${SKIP_GENERATE}" == "1" ]]; then
      log_err "SKIP_GENERATE=1 and validation failed — cannot self-repair. Stopping."
      break
    fi
    continue
  fi

  # --- Deploy with ansible-playbook (stats capture) ------------------------
  log_info "Deploying via ansible-playbook (timeout ${DEPLOY_TIMEOUT}s)..."
  deploy_rc=0
  if timeout "${DEPLOY_TIMEOUT}" ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" \
       > "${DEPLOY_LOG}" 2>&1; then
    deploy_rc=0
  else
    deploy_rc=$?
  fi
  OK_N="$(recap_field ok "${DEPLOY_LOG}")"
  CHANGED_N="$(recap_field changed "${DEPLOY_LOG}")"
  FAILED_N="$(recap_field failed "${DEPLOY_LOG}")"
  UNREACH_N="$(recap_field unreachable "${DEPLOY_LOG}")"
  DEPLOY_STATS="ok=${OK_N} changed=${CHANGED_N} failed=${FAILED_N} unreachable=${UNREACH_N}"
  if (( deploy_rc != 0 || FAILED_N > 0 || UNREACH_N > 0 )); then
    dep_verdict="FAIL"; log_err "Deployment FAILED (rc=${deploy_rc}, ${DEPLOY_STATS})."
  else
    dep_verdict="OK"; log_ok "Deployment OK (${DEPLOY_STATS})."
  fi

  # --- Verify (the authoritative gate) -------------------------------------
  ver_rc=0
  flag="No"
  if [[ "${dep_verdict}" == "OK" ]]; then
    log_info "Running verify.sh ${GAME} (authoritative PASS/FAIL)..."
    NO_COLOR=1 "${VERIFY}" "${GAME}" > "${VERIFY_LOG}" 2>&1 || ver_rc=$?
    if grep -Fq -- "${FLAG_VALUE:-WMG{}" "${VERIFY_LOG}" && grep -q "retrieved: Yes" "${VERIFY_LOG}"; then
      flag="Yes"
    fi
  else
    log_warn "Skipping verify.sh because deployment did not succeed."
    ver_rc=1
    printf '(verify skipped: deployment failed)\n' > "${VERIFY_LOG}"
  fi

  iter_end="$(date +%s.%N)"
  runtime="$(awk -v a="${iter_start}" -v b="${iter_end}" 'BEGIN{printf "%.1f", b-a}')"

  # --- Verdict for this iteration ------------------------------------------
  if (( ver_rc == 0 )); then
    verdict="PASS"; ver_verdict="PASS"; result="PASS"
    repair="None — verification passed."
  else
    verdict="FAIL"; ver_verdict="FAIL"; result="FAIL"
    if [[ "${dep_verdict}" != "OK" ]]; then
      repair="Deployment failed; a playbook task errored. See deploy log."
    elif [[ "${flag}" != "Yes" ]]; then
      repair="Exploit ran but flag not retrieved, or exploit mechanism failed. See verify log."
    else
      repair="verify.sh returned non-zero. See verify log."
    fi
  fi

  record_iteration "${iter}" "${iter_ts}" "${FILES}" "${gen_rc}" \
    "${syntax_rc}" "${SYNTAX_OUT}" "${deploy_rc}" \
    "${OK_N}" "${CHANGED_N}" "${FAILED_N}" "${ver_rc}" \
    "${runtime}" "${verdict}" "${repair}"
  append_gv_log "${iter}" "${FILES}" "${syn_verdict}" "${syntax_rc}" \
    "${dep_verdict}" "${DEPLOY_STATS}" "${ver_verdict}" "${ver_rc}" \
    "${flag}" "${runtime}" "${repair}" "${result}"

  # --- PASS? ----------------------------------------------------------------
  if (( ver_rc == 0 )); then
    OVERALL_RESULT="PASS"
    write_state "PASS" "${iter}"
    printf '\n'
    log_ok "${C_BOLD}SUCCESS${C_RESET}: verify.sh PASSED for '${GAME}' on iteration ${iter}."
    log_info "State:  ${STATE_FILE#${REPO_ROOT}/}"
    log_info "Log:    ${GV_LOG#${REPO_ROOT}/}"

    # Commit the game + its evidence (best-effort; never abort on git failure).
    if git -C "${REPO_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
      git -C "${REPO_ROOT}" add -A \
        "games/${GAME}" \
        "agent-harness/exploits/${GAME}.exploit" \
        "${STATE_FILE}" "${GV_LOG}" 2>/dev/null || true
      if git -C "${REPO_ROOT}" commit -m "Add verified game '${GAME}' via generate-and-verify loop (iter ${iter})" >/dev/null 2>&1; then
        log_ok "Committed '${GAME}' ($(git -C "${REPO_ROOT}" rev-parse --short HEAD))."
      else
        log_warn "Nothing to commit or commit failed (continuing)."
      fi
    fi
    write_state "PASS" "${iter}"
    exit 0
  fi

  # --- FAIL: prepare evidence for the next repair iteration ----------------
  write_state "FAIL" "${iter}"
  PREV_SUMMARY="Iteration ${iter}: ${result}. Deploy=${dep_verdict} (${DEPLOY_STATS}), verify rc=${ver_rc}, flag=${flag}."
  PREV_DEPLOY_LOG="${DEPLOY_LOG}"
  PREV_VERIFY_LOG="${VERIFY_LOG}"
  PREV_SYNTAX_OUT="${SYNTAX_OUT}"
  log_warn "Iteration ${iter} FAILED. ${repair}"
  if [[ "${SKIP_GENERATE}" == "1" ]]; then
    log_err "SKIP_GENERATE=1 — no self-repair possible. Stopping after one pass."
    break
  fi
done

# --- Max iterations reached (or SKIP_GENERATE single-pass fail) -------------
write_state "${OVERALL_RESULT}" "${FINAL_ITER}"
printf '\n'
log_err "${C_BOLD}FAILURE${C_RESET}: '${GAME}' did not pass verification within ${FINAL_ITER} iteration(s)."
log_err "Review ${GV_LOG#${REPO_ROOT}/} and ${STATE_FILE#${REPO_ROOT}/}, then re-run."
exit 1
