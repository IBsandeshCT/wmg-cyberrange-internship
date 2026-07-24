# Agent Harness — Autonomous Self-Verification for CyberRange Games

A verification framework that lets an AI coding agent (or a human) **prove** that
a generated cyber-range exercise actually works, by deploying it and running the
real exploit against a live target. A game is only "done" when a real attack
retrieves the expected flag — never when the model merely *claims* it does.

**Current result: 13/13 PASS (100%)**

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
        ▲
        │ sources verify.sh
  ┌──────────────────────┐
  │ generate-and-verify  │  autonomous loop: Claude generates →
  │        .sh           │  verify.sh runs → if FAIL, Claude repairs
  └──────────────────────┘  until exit 0 or MAX_ITERATIONS reached

                                     │ ansible over SSH (2222)
                                     │ exploits over 2222 / 80 / 8888 / 21
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
├── generate-and-verify.sh       # autonomous generate → verify → repair loop
├── lib.sh                       # shared functions (sourced, no side effects)
├── claude-generate-and-verify.md# generate→verify→repair loop instructions for agents
├── README.md                    # this file
├── prompts/                     # prompt templates for new-game generation
│   └── new-game-template.txt
├── logs/                        # per-run generate-and-verify output logs
├── state/                       # intermediate state files for repair loop
└── exploits/                    # one self-contained exploit per game
    ├── ssh-weak-password.exploit
    ├── shellshock.exploit
    ├── network-recon.exploit
    ├── ftp-anon.exploit
    ├── suid-privesc.exploit
    ├── sqli-login.exploit
    ├── dir-traversal.exploit
    ├── xss-stored.exploit
    ├── ssh-weak-v2.exploit
    ├── sqli-v2.exploit
    ├── privesc-v2.exploit
    ├── ssh-weak-v3.exploit
    └── sqli-v3.exploit

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
  -p 2222:22 -p 80:80 -p 8888:8888 -p 21:21 \
  --cap-add=NET_ADMIN cyberrange-target-base:latest
```

### Verify one game

```bash
./agent-harness/verify.sh shellshock
./agent-harness/verify.sh sqli-v3
```

### Verify every game

```bash
./agent-harness/verify-all.sh
```

Expected output:
```
PASS  ssh-weak-password   (ok=7   changed=0  5.0s)
PASS  shellshock          (ok=11  changed=1  13.2s)
PASS  network-recon       (ok=13  changed=0  14.1s)
...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Suite result: 13/13 PASS  (100%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Generate and verify a new game autonomously

```bash
# Supply a prompt describing the game you want
./agent-harness/generate-and-verify.sh agent-harness/prompts/my-game.txt my-game-name

# Skip generation, just verify files already on disk
SKIP_GENERATE=1 ./agent-harness/generate-and-verify.sh prompts/unused.txt my-game-name
```

`generate-and-verify.sh` calls Claude to produce `games/<name>/setup.yml`,
`games/<name>/training.json`, and `exploits/<name>.exploit`, then immediately
runs `verify.sh`. If verify fails, it feeds the failure output back to Claude
for repair, looping up to `MAX_ITERATIONS` times (default 5).

Environment variables for `generate-and-verify.sh`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `MAX_ITERATIONS` | `5` | Repair attempts before giving up |
| `SKIP_GENERATE` | `0` | `1` = skip Claude, verify existing files |
| `CLAUDE_BIN` | `claude` | Claude CLI binary path |
| `CLAUDE_EXTRA_ARGS` | (empty) | Extra args appended to every `claude` call |

Exit codes:

| Code | Meaning |
|------|---------|
| 0 | Full PASS: deployment OK **and** exploit succeeded **and** flag matched |
| 1 | Verification FAIL (deploy, exploit, or flag failed) |
| 2 | Usage error / unknown game / missing exploit definition |
| 3 | Missing required dependency |
| 130 | Interrupted (SIGINT/SIGTERM) |

Configuration for `verify.sh` / `verify-all.sh` (environment variables, all optional):

| Variable | Default | Purpose |
|----------|---------|---------|
| `DEPLOY_TIMEOUT` | `600` | Max seconds for `ansible-playbook` |
| `EXPLOIT_TIMEOUT` | `30` | Max seconds for the exploit |
| `TARGET_HOST` | `127.0.0.1` | Host the exploit connects to |
| `TARGET_SSH_PORT` | `2222` | Published SSH port |
| `TARGET_HTTP_PORT` | `80` | Published HTTP port |
| `TARGET_BANNER_PORT` | `8888` | Published banner port |
| `NO_COLOR` | (unset) | Set to disable coloured output |

---

## Adding a new game

1. Build and prove the game locally: `games/<name>/setup.yml` plus its `files/`,
   verified against the Docker target (see the root `CLAUDE.md`).
2. Drop an exploit definition at `agent-harness/exploits/<name>.exploit` (copy
   an existing one and adapt `GAME_TITLE`, `EXPECTED_FLAG`, and `run_exploit`).
3. `./agent-harness/verify.sh <name>`

`verify-all.sh` discovers the new game automatically — no script edits needed.

### Exploit file rules

- `run_exploit` must **return a meaningful exit code** — non-zero when the
  attack mechanism fails. Do not `|| true` away a real failure.
- Print the retrieved content to **stdout**; the harness greps stdout for the flag.
- The exploit must be a standalone bash script that works from the repo root.

---

## Current game results (13/13)

| Game | Exploit mechanism | Duration |
|------|-------------------|----------|
| `ssh-weak-password` | `sshpass -p password123 ssh student@target 'cat ~/flag.txt'` | ~5s |
| `shellshock` | `curl -H 'User-Agent: () { :; }; echo; /bin/cat /opt/flag.txt'` | ~13s |
| `network-recon` | `echo \| nc -w3 target 8888` | ~14s |
| `ftp-anon` | `curl ftp://target/pub/flag.txt` (anonymous) | ~5s |
| `suid-privesc` | `sshpass ssh student@target '/bin/bash -p -c cat /root/flag.txt'` | ~5s |
| `sqli-login` | `curl -d "username=' OR 1=1-- -&password=x"` | ~45s |
| `dir-traversal` | `curl http://target/download.php?file=../secrets/flag.txt` | ~14s |
| `xss-stored` | `curl POST guestbook → GET /bot.php → GET /collect.php` | ~15s |
| `ssh-weak-v2` | `sshpass -p Sailor2024 ssh deckhand@target 'cat ~/manifest.txt'` | ~5s |
| `sqli-v2` | `curl -G search.php --data-urlencode "q=' UNION SELECT note,'x'..."` | ~15s |
| `privesc-v2` | `sshpass ssh webadmin@target 'sudo /usr/bin/find /etc/hostname -exec cat /root/flag.txt \;'` | ~15s |
| `ssh-weak-v3` | `sshpass -p Campus2024 ssh itstaff@target 'cat ~/ticket-export.txt'` | ~5s |
| `sqli-v3` | Python3 binary search UNICODE+SUBSTR over `lookup.php?id=N` | ~15s |

---

## Common failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Missing required dependencies: docker` | Docker Desktop not running or WSL integration off | Start Docker Desktop; enable WSL integration |
| Deployment `unreachable=1` | Target container not running | `docker run ... -p 2222:22 ...`; `ansible ... -m ping` |
| Deploy OK but exploit `exit code 255` (SSH) | Wrong creds or account not created | Check the user creation task; confirm `-p 2222` |
| Deploy OK but exploit `exit code` non-zero (curl) | Apache not started or CGI not enabled | Confirm `a2enmod cgi` created `cgid.load`; check handler flush |
| Exploit succeeds but flag **not** found | Flag planted in wrong path | Compare `EXPECTED_FLAG` with `flag_content` in playbook |
| Second deploy shows `changed>0` unexpectedly | Non-idempotent task (random salt, unconditional command) | Use fixed salt / `creates:` guards / `changed_when: false` |
| Banner exploit hangs then times out | Service bound to wrong interface or port not published | Publish `-p 8888:8888`; confirm service listens on `0.0.0.0` |

---

## Extending the harness

- **New parsed metrics:** `recap_field` in `verify.sh` extracts any `name=<int>`
  token from the Ansible recap; add more as needed.
- **Different targets:** point `TARGET_HOST`/ports at a remote CyberRangeCZ range
  instead of local Docker; nothing in the harness assumes Docker beyond the
  dependency check.
- **CI integration:** `verify-all.sh` is CI-friendly — it exits non-zero on any
  failure and writes a plain-text summary. Wrap it in a pipeline step and fail
  the build on non-zero.
- **Structured output:** the summary block is easy to switch to JSON if a
  dashboard needs to consume results; keep the human box as well.
- **Per-sandbox variant flags (APG):** verify variant answers by reading the
  generated flag from the sandbox rather than a hardcoded `EXPECTED_FLAG`.
