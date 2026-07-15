# Agent Harness — Autonomous Self-Verification for CyberRange Games

A verification framework that lets an AI coding agent (or a human) **prove** that
a generated cyber-range exercise actually works, by deploying it and running the
real exploit against a live target. A game is only "done" when a real attack
retrieves the expected flag — never when the model merely *claims* it does.

---

## Purpose

AI agents are good at producing plausible-looking infrastructure code and
confident prose about it. They are far less reliable at *being correct*. An
agent will happily report "the Shellshock exploit succeeds and returns
`WMG{...}`" for a playbook that never installed the vulnerable bash, never
started Apache, or planted the flag in the wrong place. Nothing in the
generation step catches this.

This harness closes that gap. It makes **hallucinated success impossible** by
requiring physical evidence:

> A **PASS** is valid only if a real exploit, run against a real deployment,
> retrieves the exact expected flag — confirmed by the exploit's own exit code
> **and** a byte-for-byte flag match.

The result is a machine-checkable definition of "done" that an agent can loop
against unattended.

---

## Verification philosophy

Three principles drive the design:

1. **Deploy for real.** Every run executes `ansible-playbook` against the live
   target container. The Ansible recap (`ok/changed/failed/unreachable/...`) is
   parsed and a non-zero `failed`/`unreachable` count, or a non-zero playbook
   exit code, fails the run before an exploit is ever attempted.

2. **Exploit for real, and judge by exit code — not string matching alone.**
   The exploit is the *actual* attack a trainee would run (hydra-weak SSH login,
   a Shellshock `User-Agent` header, a banner-grab on a TCP port). Whether the
   exploit *mechanism* worked is decided by its **exit code** (`ssh` returns 255
   on auth failure, `curl --fail` returns non-zero on HTTP errors, `nc` returns
   non-zero when a connection is refused). Only *after* that does the harness
   check the retrieved bytes against the expected flag. A PASS needs **both**:
   a working exploit and the correct flag. Grepping for the flag string alone —
   which an agent could satisfy by echoing the answer anywhere — is never
   sufficient on its own.

3. **Record immutable evidence.** Every run appends a timestamped entry to
   `research-logs/verification-log.md`. History is never overwritten, so the log
   is an audit trail: you can see that a game was verified, when, how long it
   took, and whether a human intervened.

### Why AI-generated infrastructure *must* be verified

- **Confident wrongness.** LLMs express the same certainty for correct and
  incorrect output. Self-reported success is not evidence.
- **Silent environmental drift.** systemd-less containers, threaded Apache MPMs,
  CRLF shebangs, missing chroot dirs — a playbook that "looks right" fails in
  ways only a live run surfaces (see `research-logs/research-log.md`).
- **Idempotency regressions.** A game that deploys once but is not idempotent
  will break on redeploy. Re-running verification catches `changed>0` on the
  second pass.
- **Answer integrity.** Training platforms score trainees on flags. If the
  planted flag does not match what the exploit yields, the exercise is broken
  for everyone. Only an end-to-end run proves the two agree.

---

## Architecture

```
                        ┌──────────────────────────────────────────┐
   ./verify.sh <game>   │  verify.sh                                 │
        │               │   1. validate args (unknown game → exit 2) │
        │               │   2. locate games/<game>/setup.yml         │
        ▼               │   3. load exploits/<game>.exploit          │
  ┌───────────┐         │   4. require_deps (fail early)             │
  │  lib.sh   │◀────────│   5. ansible-playbook  (timeout-bounded)   │
  │ colours   │ source  │        └─ parse ok/changed/failed/…        │
  │ logging   │         │   6. run_exploit       (timeout-bounded)   │
  │ deps      │         │        └─ judge by EXIT CODE               │
  │ paths     │         │   7. flag match (grep -F exact)            │
  └───────────┘         │   8. print coloured summary box            │
        ▲               │   9. append entry to verification-log.md   │
        │ source        │  10. exit 0 iff deploy+exploit+flag all OK  │
  ┌──────────────┐      └──────────────────────────────────────────┘
  │ verify-all.sh│  discovers games/*/setup.yml, runs verify.sh per
  │              │  game, prints a suite summary, exits 0 iff all pass
  └──────────────┘
                                     │ ansible over SSH (2222)
                                     │ exploits over 2222 / 80 / 8888
                                     ▼
                        ┌──────────────────────────┐
                        │  docker: cyberrange-target │
                        │  Ubuntu 22.04 + sshd       │
                        │  ports published to WSL    │
                        │  localhost                 │
                        └──────────────────────────┘
```

`lib.sh` holds everything shared (colour handling, logging, dependency checks,
repo-root resolution) so `verify.sh` and `verify-all.sh` contain no duplicated
plumbing. Each game's attack lives in its own `exploits/<game>.exploit` file, so
the core scripts never hardcode game names or flags.

---

## Directory layout

```
agent-harness/
├── verify.sh                    # verify ONE game end-to-end
├── verify-all.sh                # discover & verify EVERY game, then summarise
├── lib.sh                       # shared functions (sourced, no side effects)
├── claude-generate-and-verify.md# the generate → verify → repair loop for agents
├── README.md                    # this file
└── exploits/                    # one self-contained exploit per game
    ├── ssh-weak-password.exploit
    ├── shellshock.exploit
    └── network-recon.exploit

research-logs/
└── verification-log.md          # append-only evidence log (auto-initialised)
```

An exploit file declares exactly three things:

```bash
GAME_TITLE="Shellshock (CVE-2014-6271)"          # shown in output & log
EXPECTED_FLAG="WMG{...}"                          # the exact flag to match
run_exploit() { ... }   # runs the REAL attack, prints output, returns a
                        # meaningful exit code (0 iff the mechanism worked)
```

---

## Usage

Prerequisites: the target container must be **running** with SSH/HTTP/banner
ports published to the host that the exploits connect to:

```bash
docker run -d --name cyberrange-target \
  -p 2222:22 -p 80:80 -p 8888:8888 \
  --cap-add=NET_ADMIN cyberrange-target-base:latest
```

Verify one game:

```bash
./agent-harness/verify.sh shellshock
```

Verify every game and get a suite summary:

```bash
./agent-harness/verify-all.sh
```

Exit codes:

| Code | Meaning                                                        |
|------|----------------------------------------------------------------|
| 0    | Full PASS: deployment OK **and** exploit succeeded **and** flag matched |
| 1    | Verification FAIL (deploy, exploit, or flag failed)            |
| 2    | Usage error / unknown game / missing exploit definition        |
| 3    | Missing required dependency                                    |
| 130  | Interrupted (SIGINT/SIGTERM)                                   |

Configuration (environment variables, all optional):

| Variable             | Default     | Purpose                             |
|----------------------|-------------|-------------------------------------|
| `DEPLOY_TIMEOUT`     | `600`       | Max seconds for `ansible-playbook`  |
| `EXPLOIT_TIMEOUT`    | `30`        | Max seconds for the exploit         |
| `TARGET_HOST`        | `127.0.0.1` | Host the exploit connects to        |
| `TARGET_SSH_PORT`    | `2222`      | Published SSH port                  |
| `TARGET_HTTP_PORT`   | `80`        | Published HTTP port                 |
| `TARGET_BANNER_PORT` | `8888`      | Published banner port               |
| `NO_COLOR`           | (unset)     | Set to disable coloured output      |

---

## Adding new games

1. Build and prove the game locally the usual way: `games/<name>/setup.yml`
   plus its `files/`, verified against the Docker target (see the root
   `CLAUDE.md`).
2. Drop an exploit definition at `agent-harness/exploits/<name>.exploit` (copy
   an existing one and adapt `GAME_TITLE`, `EXPECTED_FLAG`, and `run_exploit`).
3. `./agent-harness/verify.sh <name>`.

`verify-all.sh` discovers the new game automatically — no script edits needed.

## Adding new exploit tests

The exploit is deliberately decoupled from the game so you can add or refine
attacks without touching the harness. To change how a game is exploited, edit
its `.exploit` file. To test a game a *second* way (e.g. a different Shellshock
vector), add another exploit file and point a thin wrapper game name at it, or
extend `run_exploit` to try multiple vectors and return success if any works.

Keep two rules in mind:

- `run_exploit` must **return a meaningful exit code** — non-zero when the
  attack mechanism fails. Do not `|| true` away a real failure.
- Print the retrieved content to **stdout**; the harness greps stdout/stderr for
  the flag.

## Extending the harness

- **New parsed metrics:** `recap_field` in `verify.sh` extracts any
  `name=<int>` token from the Ansible recap; add more as needed.
- **Different targets:** point `TARGET_HOST`/ports at a remote range instead of
  local Docker; nothing in the harness assumes Docker beyond the dependency
  check.
- **CI integration:** `verify-all.sh` is CI-friendly — it exits non-zero on any
  failure and writes a plain-text summary. Wrap it in a pipeline step and fail
  the build on non-zero.
- **Structured output:** the summary block is easy to switch to JSON if a
  dashboard needs to consume results; keep the human box as well.

---

## Common failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Missing required dependencies: docker` | Docker Desktop WSL integration off, or Desktop not running | Start Docker Desktop; enable WSL integration for the Ubuntu distro |
| Deployment `unreachable=1` | Target container not running / SSH port not published | `docker run ... -p 2222:22 ...`; `ansible ... -m ping` |
| Deploy OK but exploit `exit code 255` (SSH) | Wrong creds, account not created, or SSH port not published | Check the `student` user task; confirm `-p 2222` |
| Deploy OK but exploit `exit code` non-zero (curl) | Apache not started, CGI module not enabled, wrong script path | Confirm `a2enmod cgi` created `cgid.load`; `apache2ctl start` |
| Exploit succeeds but flag **not** found | Flag planted in the wrong path, or content mismatch | Compare `EXPECTED_FLAG` with the `flag_content` in the playbook |
| Second deploy shows `changed>0` | Non-idempotent task (random salt, unconditional command) | Use a fixed salt / `creates:` guards / `changed_when: false` |
| Banner exploit hangs then times out | Service bound to the wrong interface, or started in-container but port not published | Publish `-p 8888:8888`; confirm the service listens on `0.0.0.0` |

---

## Future work

- **Per-sandbox variant flags (APG):** verify variant answers by reading the
  generated flag from the sandbox rather than a hardcoded `EXPECTED_FLAG`.
- **Fresh-target isolation:** optionally rebuild the container per game so games
  cannot interfere (currently they share one long-lived target, which is fine
  because each exploit is independent, but true isolation is stronger).
- **Negative assertions:** confirm the flag is *not* readable *before* the
  exploit (proving the exploit is what reveals it, not a misconfiguration).
- **JSON evidence + dashboard feed:** emit machine-readable results alongside
  the markdown log for the project dashboard.
- **CyberRangeCZ shape:** extend beyond local `setup.yml` to verify the
  role-based `provisioning/` + `topology.yml` deployment shape.
