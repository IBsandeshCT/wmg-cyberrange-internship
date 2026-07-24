# WMG CyberRange Internship — Autonomous Game Builder

**WMG Summer Research Internship 2026 · University of Warwick**

---

## Research Question

> Can Claude autonomously build, deploy, and verify cybersecurity training games for the CyberRangeCZ platform — from a single-sentence learning objective to a passing end-to-end verification — with no human intervention?

This repository is the working output of that investigation. It contains 13 verified cybersecurity training games, an evidence-based verification harness, and an autonomous generation pipeline driven entirely by Claude.

---

## What Was Built

| Game | Vulnerability Class | Flag | Status |
|------|--------------------|----|--------|
| `ssh-weak-password` | SSH brute-force (hydra) | `WMG{ssh_w3ak_p4ssw0rds_are_never_ok}` | PASS |
| `shellshock` | CVE-2014-6271 Apache CGI RCE | `WMG{sh3llsh0ck_cve_2014_6271_env_vars_are_scary}` | PASS |
| `network-recon` | Port/service enumeration | `WMG{r3c0n_1s_m0r3_th4n_just_p0rt_sc4nning}` | PASS |
| `ftp-anon` | Anonymous FTP access | `WMG{anon_ftp_1s_a_s3curity_r1sk}` | PASS |
| `suid-privesc` | SUID binary privilege escalation | `WMG{su1d_b4sh_pr1v3sc_1s_trivial}` | PASS |
| `sqli-login` | SQL injection login bypass | `WMG{sq1_1nj3ct10n_byp4ss3d_auth}` | PASS |
| `dir-traversal` | Directory/path traversal | `WMG{d1r_trav3rs4l_n0_s4n1t1z3d_p4ths}` | PASS |
| `xss-stored` | Stored XSS cookie theft | `WMG{xss_st0l3n_admin_s3ss10n}` | PASS |
| `ssh-weak-v2` | Weak SSH password — maritime scenario | `WMG{w3ak_ssh_cr3ds_s1nk_sh1ps}` | PASS |
| `sqli-v2` | UNION-based SQL injection | `WMG{un10n_b4s3d_sql1_l34ks_th3_db}` | PASS |
| `privesc-v2` | sudo NOPASSWD misconfiguration | `WMG{sud0_f1nd_3xec_r00ts_y0u}` | PASS |
| `ssh-weak-v3` | Weak SSH password — academic sector | `WMG{c4mpus_pw_t00_pr3d1ct4bl3}` | PASS |
| `sqli-v3` | Boolean blind SQL injection | `WMG{bl1nd_sql1_tr00th_0r_n0_tr00th}` | PASS |

**verify-all.sh result: 13/13 PASS (100%)**

Every game has:
- A 9-level `training.json` with immersive scenario prose, MITRE ATT&CK technique tags, and 2–3 hints per level
- An Ansible `setup.yml` playbook (idempotent, tested against local Docker and CyberRangeCZ)
- A standalone `exploits/<name>.exploit` script that runs the real attack and retrieves the flag
- A CyberRangeCZ deployment repo (`topology.yml` + role-based `provisioning/`)

---

## Architecture

```
Instructor types one sentence:
  "Build a game teaching boolean blind SQL injection"
              │
              ▼
  CLAUDE.md + skills/
  (platform constraints, Ansible rules,
   training.json schema, scoring rules)
              │
              ▼
        Claude CLI
   (claude -p prompts/new-game-template.txt)
              │
     ┌────────┴────────┐
     │                 │
     ▼                 ▼
games/<name>/    agent-harness/
  setup.yml       exploits/<name>.exploit
  training.json
     │
     ▼
agent-harness/verify.sh <name>
  1. ansible-playbook (deploy to Docker target)
  2. run_exploit()    (real attack against live target)
  3. flag match       (byte-for-byte)
  4. exit 0 = PASS    (the only definition of done)
              │
              ▼
CyberRangeCZ deployment repo
  topology.yml + provisioning/
  (pushed to GitHub, imported via portal)
```

The pipeline is fully autonomous: `generate-and-verify.sh` loops Claude → deploy → verify → repair until `verify.sh` returns exit 0, or a retry limit is reached.

---

## Model Comparison

Models tested for autonomous game generation quality:

| Model | Role |
|-------|------|
| Claude Sonnet 4.6 | Primary — all 13 games generated and verified |
| Claude Fable 5 | Being evaluated for generation quality comparison |
| Claude Haiku 4.5 | Being evaluated for speed/cost trade-off |
| Claude Opus 4.8 | Being evaluated for hardest multi-stage games |

Model comparison is ongoing. Findings will be recorded in `research-logs/research-log.md`.

---

## Directory Structure

```
wmg-cyberrange-internship/
├── README.md                        ← this file
├── CLAUDE.md                        ← prime directives for the AI agent
├── DESIGN.md                        ← current task, plan, facts, gaps
├── CHANGELOG.md                     ← what changed, what failed, dead ends
│
├── games/                           ← one sub-directory per game
│   ├── ssh-weak-password/
│   │   ├── setup.yml                ← Ansible playbook (deploy the game)
│   │   ├── files/                   ← supporting files (wordlists, scripts)
│   │   ├── training.json            ← 9-level CyberRangeCZ training definition
│   │   └── README.md
│   └── … (13 games total)
│
├── agent-harness/                   ← verification + generation harness
│   ├── verify.sh                    ← verify ONE game end-to-end
│   ├── verify-all.sh                ← verify ALL games, print suite summary
│   ├── generate-and-verify.sh       ← autonomous generate→verify→repair loop
│   ├── lib.sh                       ← shared functions
│   ├── exploits/                    ← one .exploit file per game
│   ├── prompts/                     ← prompt templates for new-game generation
│   ├── logs/                        ← per-run generate-and-verify logs
│   └── README.md
│
├── docker/
│   ├── Dockerfile.target            ← Ubuntu 22.04 + openssh-server base image
│   └── Dockerfile.attacker          ← Kali toolbox (hydra, nmap, sqlmap, …)
│
├── inventory/
│   └── hosts.ini                    ← Ansible inventory for local Docker target
│
├── skills/                          ← Claude skill files (platform knowledge)
│   ├── cyberrange-platform.md
│   ├── ansible-conventions.md
│   ├── game-design.md
│   ├── training-levels.md
│   └── … (16 skill files)
│
├── research-logs/
│   ├── research-log.md              ← chronological build log (weeks 1–3)
│   ├── verification-log.md          ← append-only evidence log (auto-generated)
│   └── generate-verify-log.md       ← generate-and-verify loop log
│
└── dashboard/
    └── index.html                   ← local results dashboard
```

---

## Prerequisites

- Windows 11 with WSL2 (Ubuntu)
- Docker Desktop with WSL2 integration enabled
- Inside WSL: `ansible-core` (tested on 2.21.1), `sshpass`, `python3`, `git`
- Claude CLI (`claude`) installed and authenticated

Attack tools (`hydra`, `nmap`, `sqlmap`, `curl`, `nc`, etc.) are pre-installed in the `cyberrange-attacker` Docker image — no host installs needed.

---

## Local Setup

```bash
# 1. Build the target base image
docker build -t cyberrange-target-base -f docker/Dockerfile.target .

# 2. Run the target (SSH on 2222, HTTP on 80, FTP on 21, banner on 8888)
docker run -d --name cyberrange-target \
  -p 2222:22 -p 80:80 -p 21:21 -p 8888:8888 \
  --cap-add=NET_ADMIN cyberrange-target-base

# 3. Test connectivity
ansible -i inventory/hosts.ini cyberrange -m ping
```

Rebuild the target from scratch at any time:
```bash
docker rm -f cyberrange-target
docker run -d --name cyberrange-target \
  -p 2222:22 -p 80:80 -p 21:21 -p 8888:8888 \
  --cap-add=NET_ADMIN cyberrange-target-base
```

---

## Running a Game

```bash
# Deploy a specific game to the target
ansible-playbook -i inventory/hosts.ini games/sqli-v3/setup.yml

# Verify it works end-to-end
./agent-harness/verify.sh sqli-v3
```

---

## Verifying All Games

```bash
./agent-harness/verify-all.sh
```

Expected output (abridged):

```
PASS  ssh-weak-password   (ok=7   changed=0  5.0s)
PASS  shellshock          (ok=11  changed=1  13.2s)
...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Suite result: 13/13 PASS  (100%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Generating a New Game

```bash
# Edit the prompt template with your learning objective
cp agent-harness/prompts/new-game-template.txt agent-harness/prompts/my-game.txt
# … edit my-game.txt …

# Run the autonomous loop: Claude builds → harness verifies → Claude repairs
./agent-harness/generate-and-verify.sh agent-harness/prompts/my-game.txt my-game-name
```

The loop runs until `verify.sh` returns exit 0 (PASS) or `MAX_ITERATIONS` (default 5) is reached. No human steps between prompt and verified game.

---

## CyberRangeCZ Deployment Repos

Each game has a separate GitHub repo for CyberRangeCZ import:

| Game | Repo | Subnet |
|------|------|--------|
| ssh-weak-password | `IBsandeshCT/wmg-ssh-cyberrange` | — |
| shellshock | `IBsandeshCT/wmg-shellshock-cyberrange` | — |
| network-recon | `IBsandeshCT/wmg-network-recon-cyberrange` | — |
| suid-privesc | `IBsandeshCT/wmg-suid-privesc-cyberrange` | 10.1.28.0/24 |
| sqli-login | `IBsandeshCT/wmg-sqli-login-cyberrange` | 10.1.29.0/24 |
| dir-traversal | `IBsandeshCT/wmg-dir-traversal-cyberrange` | 10.1.30.0/24 |
| xss-stored | `IBsandeshCT/wmg-xss-stored-cyberrange` | 10.1.31.0/24 |
| ssh-weak-v2 | `IBsandeshCT/wmg-ssh-weak-v2-cyberrange` | 10.1.32.0/24 |
| sqli-v2 | `IBsandeshCT/wmg-sqli-v2-cyberrange` | 10.1.33.0/24 |
| privesc-v2 | `IBsandeshCT/wmg-privesc-v2-cyberrange` | 10.1.34.0/24 |
| ssh-weak-v3 | `IBsandeshCT/wmg-ssh-weak-v3-cyberrange` | 10.1.35.0/24 |
| sqli-v3 | `IBsandeshCT/wmg-sqli-v3-cyberrange` | 10.1.36.0/24 |

Next available subnet: **10.1.37.0/24**

---

## Research Findings (Weeks 1–3)

**Week 1:** Local Docker + Ansible environment established. Python version incompatibility discovered and resolved (18.04 → 22.04). First 3 games built and verified.

**Week 2:** Verification harness (`verify.sh`, `verify-all.sh`, `lib.sh`) designed and built. 4 more games added (ftp-anon, suid-privesc, sqli-login, dir-traversal, xss-stored, ssh-weak-v2, sqli-v2, privesc-v2). 100% pass rate maintained throughout.

**Week 3:** `generate-and-verify.sh` autonomous loop built. 2 more games (ssh-weak-v3, sqli-v3). All 11 original `training.json` files upgraded from 5-level to 9-level format with immersive scenario prose, MITRE ATT&CK tags, and 2–3 hints per level. 13/13 PASS.

**Key finding:** Claude can build a new, verified, CyberRangeCZ-ready game from a single-sentence learning objective with zero failed verification attempts across 13 games (13 first-attempt PASSes, 1 pre-run dead-end caught before verification).

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ansible -m ping` fails: Python SyntaxError | Target running old image; rebuild from `docker/Dockerfile.target` |
| SSH fails: `REMOTE HOST IDENTIFICATION HAS CHANGED` | `hosts.ini` must have `-o UserKnownHostsFile=/dev/null` |
| vsftpd hangs on deploy | Use `async: 86400, poll: 0`; create `/var/run/vsftpd/empty` first |
| `a2enmod cgi` `creates:` guard re-runs every time | Threaded MPM creates `cgid.load` not `cgi.load`; check actual file |
| Apache CGI exploit fails after deploy | Add explicit `meta: flush_handlers` after `a2enmod` tasks |
| sshd restart kills container | Never restart sshd where it is PID 1 (Docker init-less containers) |
