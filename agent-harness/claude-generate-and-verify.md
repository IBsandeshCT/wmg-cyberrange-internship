# Generate-and-Verify Workflow (for Claude)

**Audience:** Claude (or any LLM agent) authoring a CyberRange game in this repo.
**Contract:** You may not claim a game works until `agent-harness/verify.sh`
returns **PASS** for it. Self-reported success is worthless; the verification
harness is the only source of truth.

This document is the loop you follow. Treat it as binding.

---

## The rule

> A game is complete **only** when `./agent-harness/verify.sh <game>` exits `0`
> — i.e. it deployed for real, the real exploit ran, and the exact expected flag
> was retrieved. Until then the game is *unverified*, and you must say so.

Never write "the exploit succeeds", "this returns the flag", or "the game is
done" based on reading the code. Those are hypotheses. Only a green
`verify.sh` run converts a hypothesis into a fact.

---

## Loop overview

```
        ┌───────────────────────────────────────────────┐
        │ 1. READ the vulnerability brief                │
        │ 2. GENERATE artifacts (Ansible, flag, exploit) │
        │ 3. DEPLOY + VERIFY  (./verify.sh <game>)        │
        └───────────────────────────────────────────────┘
                         │
                 ┌───────┴────────┐
              PASS?              FAIL?
                 │                 │
                 ▼                 ▼
        ┌────────────────┐  ┌──────────────────────────────────┐
        │ DONE. Report    │  │ 4. DIAGNOSE from the log + output │
        │ the evidence.   │  │ 5. FIX the playbook / exploit      │
        └────────────────┘  │ 6. REDEPLOY + REVERIFY             │
                            │    (max 10 iterations, then stop)  │
                            └──────────────────────────────────┘
```

---

## Step 1 — Read the vulnerability description

Extract, explicitly, before writing anything:

- **Vulnerability class** and, if applicable, the **CVE**.
- **Services** the target must expose and on which **ports**.
- The **exploit path**: what an attacker runs, and where the flag lives.
- The **flag**: format is always `WMG{...}`, lower-snake, and must be readable
  **only after** the intended exploit succeeds — not before.

If any of these is ambiguous, resolve it against an existing game in `games/`
before generating. Reuse over invention (see the root `CLAUDE.md`).

## Step 2 — Generate the artifacts

Produce all of the following. Start from the closest existing game and adapt it;
do not write patterns from scratch that a working game already demonstrates.

- **Ansible** — `games/<name>/setup.yml` plus any `files/`. It must be
  **idempotent**: a second run reports `changed=0`. Honour the hard-won rules in
  the root `CLAUDE.md` (fixed password salts, `creates:` guards, async
  foreground daemons, never restart PID-1 sshd, `visudo` validation, LF
  shebangs).
- **Docker** — confirm the target container built from `docker/Dockerfile.target`
  is running and publishes the ports this game needs
  (`-p 2222:22 -p 80:80 -p 8888:8888`).
- **Flag** — plant `WMG{...}` at the exploit-gated path with permissions that
  keep it unreadable until the exploit lands.
- **Exploit** — write `agent-harness/exploits/<name>.exploit` defining
  `GAME_TITLE`, `EXPECTED_FLAG`, and `run_exploit()`. `run_exploit` must run the
  **real** attack, print what it retrieves to stdout, and return a **meaningful
  exit code** (non-zero when the attack mechanism fails). Never mask a failure
  with `|| true`.
- **Documentation** — `briefing.md`, `hints.md`, `solution.md` for the game
  (student-facing scenario, progressive hints, full instructor walkthrough with
  exact commands and expected output).

## Step 3 — Deploy and verify

```bash
./agent-harness/verify.sh <name>
```

Read the outcome from the **exit code and the summary box**, not from your
expectations. If it exits `0` with `Verification PASS`, go to "Reporting a
PASS". Otherwise, enter the repair loop.

## Step 4 — Diagnose (on FAIL)

Do **not** guess-and-retry. Gather evidence first:

1. Read the tail of the failing run's output (the harness prints the last lines
   of the Ansible log on a deploy failure, and the exploit's exit code on an
   exploit failure).
2. Read `research-logs/verification-log.md` — the latest entry states which
   stage failed (Deployment / Exploit / Flag) and the exploit exit code.
3. Map the symptom to a cause using the **Common failure modes** table in
   `agent-harness/README.md`. Typical splits:
   - **Deployment FAIL** → a playbook task errored, or the target is
     unreachable. Fix the task or the container/ports.
   - **Exploit FAIL (non-zero exit)** → the service isn't actually exploitable:
     wrong port, service not started, module not enabled, creds wrong.
   - **Exploit PASS but flag not retrieved** → the attack worked but the flag is
     in the wrong place or its content doesn't match `EXPECTED_FLAG`.
4. Also check idempotency: if the *second* deploy shows `changed>0`, a task is
   non-idempotent even if the exploit passed — fix it before declaring success.

## Step 5 — Fix

Make the **smallest change** that addresses the diagnosed cause. Change one
thing at a time so the next run's result is attributable. Prefer fixing the
game (playbook/flag) over weakening the exploit — the exploit is meant to be the
honest attack, not something bent until it passes.

## Step 6 — Redeploy and reverify

Re-run `./agent-harness/verify.sh <name>` and read the result again.

### Iteration limit

- **Maximum 10 repair iterations.** Count them.
- If you reach 10 and it still fails, **stop** and request human review. Do not
  keep looping, and do not lower the bar (e.g. weakening the exploit or matching
  a partial flag) to force a green. Summarise: what you tried, the last failing
  log entry, and your best hypothesis for the blocker.

---

## Reporting a PASS

When `verify.sh` exits `0`, report the **evidence**, not adjectives:

- The final summary box (Deployment stats, Exploit PASS, Flag retrieved,
  Verification PASS, runtime, timestamp).
- The corresponding `research-logs/verification-log.md` entry.
- Confirmation that a **second** deploy was idempotent (`changed=0`), if you ran
  one.

## Reporting a FAIL (or hitting the iteration cap)

State plainly that verification did **not** pass. Include the last summary box,
the latest log entry, which stage failed, and what you changed across
iterations. Never round a FAIL up to a PASS.

---

## Honesty guardrails

- If you did not actually run `verify.sh`, say so. Do not describe a run that did
  not happen, and do not invent log entries, deployment recaps, or flags.
- The exploit's **exit code** decides whether the mechanism worked; the **flag
  match** decides whether the right secret was retrieved. Both are required.
  Never substitute "I can see the flag in the code" for a real run.
- A green build you cannot reproduce is not a green build. If in doubt, run it
  again.
