# Building CyberRangeCZ Games — WMG Internship

## Overview

WMG (Warwick Manufacturing Group, University of Warwick) summer internship. Build small,
self-contained, reproducible cyber-security training **games** — one well-known vulnerability
class each — provisioned entirely by Ansible so any game can be torn down and rebuilt from source.

- **Target platform:** CyberRangeCZ (KYPO), the MUNI cyber range. Games ship as a
  `topology.yml` + `training.json` + Ansible `provisioning/` bundle.
- **Research question:** Can an AI coding agent, given the right patterns, reliably author
  correct, idempotent, deployable CyberRangeCZ games from a plain-English brief?
- **Flags:** always `WMG{...}`, lower-snake, readable only after the intended exploit.

## Authoritative Documentation

The CyberRangeCZ conventions used here are distilled from **Mirek's skills**, mirrored into
`skills/` in this repo and kept in sync with `~/mirek-skills/`. **`~/mirek-skills/` is the
single source of truth** — read the relevant file before authoring any artifact:

| Topic | Skill file |
|-------|-----------|
| Vocabulary (sandbox, pool, level, phase, APG) | `skills/terminology.md` |
| `topology.yml` structure & rules | `skills/sandbox-topology.md` |
| Topology worked examples | `skills/sandbox-examples.md` |
| Networking (WAN, routers, IP allocation) | `skills/sandbox-networking.md` |
| `provisioning/` playbooks & patterns | `skills/sandbox-provisioning.md` |
| ansible-stage-one (auto networking) | `skills/backend-ansible-stage-one.md` |
| Linear `training.json` | `skills/training-linear.md` |
| Level & question types | `skills/training-levels.md` |
| Adaptive (phases, decision matrix) | `skills/training-adaptive.md` |
| APG / variant answers | `skills/training-apg.md` |
| Gold reference walkthrough | `skills/starting-point-for-game-design.md` |
| Backend lifecycle | `skills/backend-sandbox-service.md` |

## Environment

- **Host:** Windows 11 + **WSL2 Ubuntu**. Do all Linux work inside WSL, not Windows.
- **Docker Desktop** with WSL2 integration — for local target/attacker containers.
- **ansible-core 2.21** (via `pip install --user`; only on PATH in a login shell — use
  `bash -lc`, not `bash -c`). Uses `ansible.builtin` modules only.
- Managed nodes need **Python ≥ 3.9** (modules embed `from __future__ import annotations`).
  Controller runs Python 3.14 — no `crypt`/`passlib` on it.
- Target base image is **`ubuntu:22.04`** (Python 3.10). Never `ubuntu:18.04` / stock
  `-sshd` images (Python 3.6.5, no upgrade path — see `research-logs/research-log.md`).

## Two repo shapes — know which you're in

1. **Local dev/test (this repo):** Docker target + `games/<name>/setup.yml` single-file
   playbooks against `inventory/hosts.ini`. Where you build and prove a game.
2. **CyberRangeCZ deployment (e.g. `~/wmg-ssh-cyberrange`):** `topology.yml` + `training.json`
   + role-based `provisioning/`. What actually deploys.

Build and verify in shape 1, then port to shape 2. Never author shape 2 blind.

## CyberRangeCZ conventions

### `topology.yml` — see `skills/sandbox-topology.md`

Real example from `~/wmg-ssh-cyberrange`:

```yaml
name: wmg-ssh-weak-password-sandbox        # a-z start, [a-zA-Z0-9-] only, unique
hosts:
  - name: attacker
    base_box: { image: kypo-kali-v2, mgmt_user: kali }
    flavor: c2.r4gb.d25gb.swap
    volumes: [ { size: 25 } ]
  - name: server                            # add `hidden: true` to force discovery
    base_box: { image: debian-12-x86_64, mgmt_user: debian }
    flavor: c1.r2gb.d10gb
    volumes: [ { size: 10 } ]
routers:
  - name: router
    base_box: { image: debian-12-x86_64, mgmt_user: debian }
    flavor: c1.r2gb.d10gb
wan:      { name: internet-connection, cidr: 100.100.100.0/24 }
networks: [ { name: wmg-switch, cidr: 10.1.27.0/24 } ]
net_mappings:    [ {host: attacker, network: wmg-switch, ip: 10.1.27.23},
                   {host: server,   network: wmg-switch, ip: 10.1.27.10} ]
router_mappings: [ {router: router,  network: wmg-switch, ip: 10.1.27.1} ]
groups: []
```

- `mgmt_user` **must** match the box: `kali` for Kali, `debian`/`ubuntu` for the target.
- **IP allocation:** `.1` = router gateway, `.2` = DHCP (reserved). Hosts use `.3`+. Keep
  host IPs stable — `training.json` hardcodes them in prose (e.g. `10.1.27.10`).
- Networks (incl. WAN) must have disjunct CIDRs. `accessible_by_user: false` hides a
  network from trainees; `hidden: true` hides a host from the topology view.

### `training.json` (linear) — see `skills/training-linear.md`, `skills/training-levels.md`

- Top level: `title`, `description`, `prerequisites`, `outcomes`, `state:"UNRELEASED"`,
  `show_stepper_bar:true`, `levels`, `estimated_duration`, `variant_sandboxes:false`.
- Level types, in order (sequential `order` from 0, no gaps):
  - `INFO_LEVEL` (order 0): disclaimer + storyline intro; no answer.
  - `ACCESS_LEVEL`: `passkey` (e.g. `"start"`), `cloud_content` + `local_content` (how to
    SSH to the attacker box; state target/attacker IPs and "attack nothing outside sandbox").
  - `TRAINING_LEVEL`: `answer` (or `answer_variable_name` + `variant_answers:true` for APG),
    `content` (ends with an explicit "The flag is…" line), `solution` (fenced, with expected
    output), `solution_penalized`, ordered `hints` (objects: `title`, `content`,
    `hint_penalty`, `order` — **never plain strings**), `incorrect_answer_limit:10`,
    `max_score` (rising per level), optional `mitre_techniques` + `expected_commands`.
  - `ASSESSMENT_LEVEL`: `QUESTIONNAIRE` (or `TEST`) with MCQ `questions` (one `correct:true`).
- One flag = one level; each level's task assumes the previous level's result.

### `provisioning/` — see `skills/sandbox-provisioning.md`

`ansible-stage-one` configures networking automatically **before** your playbook runs (see
`skills/backend-ansible-stage-one.md`); you only install packages, create users, and set up
the scenario. Layout from `~/wmg-ssh-cyberrange`:

```
provisioning/
├── playbook.yml            # one play PER host: hosts: server / attacker, become: yes, roles: [<host>]
├── requirements.yml        # roles: []  collections: []  (ansible.builtin only unless truly needed)
└── roles/<host>/
    ├── tasks/main.yml      # the work
    ├── vars/main.yml       # user names, passwords, flag_content, fixed salt
    ├── handlers/main.yml   # e.g. Restart ssh — NOT on sshd-as-PID1 containers
    └── files/              # wordlists, payloads, decoys
```

Separate role per host; `playbook.yml` maps hosts→roles. Idempotent: a second run reports
`changed=0`. Default Ansible groups (`all`, `hosts`, `routers`, `user_accessible_nodes`, …)
are available without declaring them.

### APG (variant answers) — see `skills/training-apg.md`

For per-sandbox unique flags (defeats answer sharing): set `variant_sandboxes:true`, add a
`variables.yml` in the sandbox root (`root_flag: {type: password, length: 12}`), reference it
in provisioning (`content: "{{ root_flag | default('WMG{local-test-flag}') }}\n"`), and in
the level use `answer_variable_name:"root_flag"` with `answer:null`. `${ANSWER}` substitutes
in solutions.

## Idempotency & correctness rules (learned the hard way)

- **Passwords:** `password_hash('sha512', <fixed_salt>)` with a *fixed* salt in vars (see
  `roles/server/vars/main.yml`: `student_password_salt: wmgsshsalt01234`). A random salt
  breaks idempotency. Or `chpasswd` via `shell` + `changed_when: false`.
- **CVE reproduction:** build the vulnerable binary to its own path (e.g.
  `/usr/local/bin/bash-vulnerable`) and point the target's shebang there — never replace `/bin/bash`.
- **Foreground daemons** on init-less containers (`vsftpd`, custom scripts): launch with
  `async: 86400, poll: 0`, guarded by a `pgrep`/`wait_for` check-then-launch task.
- **systemd-less containers:** create runtime dirs `systemd-tmpfiles` would (e.g. vsftpd's
  `/var/run/vsftpd/empty`) explicitly, or the service starts but silently fails.
- **`creates:` guards:** verify the *actual* file a command produces (`a2enmod cgi` makes
  `cgid.load` under the threaded MPM) — check with `ls` first.
- **Never restart `sshd`** where `sshd -D` is PID 1; it kills the container.
- **Task names:** avoid unquoted colons (`Set user:lazydev …` parses as key-value) — YAML breaks.
- **sudoers:** always `validate: "visudo -cf %s"` on the copy task.
- **Windows+WSL:** provision only from the LF (WSL) checkout; a CRLF shebang breaks CGI. Pin
  `*.cgi *.py *.j2 *.sh` to `eol=lf` in `.gitattributes`. Never commit a PAT in a git remote URL.

## Reuse over invention

- **Always start from an existing game** in this repo, `~/wmg-ssh-cyberrange`, or
  `~/junior-hacker` (the public MUNI reference). Copy its structure, then adapt.
- Match existing naming, IP scheme, level ordering, hint/scoring style, and file layout.
- Reuse a solved pattern (password hashing, async daemon launch, decoy services) verbatim
  rather than writing a new one. Study `research-logs/research-log.md` before touching Ansible.

## The three working games (use as templates)

| Game | Vuln | Services / flag path | Key technique |
|---|---|---|---|
| `games/ssh-weak-password` | Weak SSH creds | SSH 22, `~/flag.txt` (0600) | hydra dict attack; weak `student`/`password123` |
| `games/shellshock` | CVE-2014-6271 | Apache CGI 80, `/opt/flag.txt` | separate vulnerable bash 4.3; `curl` header payload |
| `games/network-recon` | Enumeration | FTP 21 + HTTP 80 decoys, banner TCP 8888 | real flag behind one port; decoys distract |

Each game dir: `setup.yml`, `files/`, `briefing.md` (student scenario), `hints.md`
(progressive), `solution.md` (full instructor walkthrough with exact commands + output).
`~/wmg-ssh-cyberrange` is `ssh-weak-password` already ported to CyberRangeCZ shape — mirror
its layout when porting the others.

## Local Docker test harness

- `docker/Dockerfile.target` — `ubuntu:22.04` + `openssh-server` + `python3` + `sudo`,
  `root:root`, `PermitRootLogin yes`, `CMD sshd -D`, SSH published on host `2222`.
- `docker/Dockerfile.attacker` — `kalilinux/kali-rolling` + hydra, nmap, netcat, curl,
  openssh-client, ftp. Run tools against the target by container name on `cyberrange-net`.
- `inventory/hosts.ini` — `target` at `127.0.0.1:2222`, `ansible_user=root`, host-key checks
  off (`StrictHostKeyChecking=no`, `UserKnownHostsFile=/dev/null`), py3 interpreter pinned.

## Golden rule: test locally with Docker before pushing to CyberRange

Never push a game to CyberRangeCZ until it is proven end-to-end against the local Docker target:
1. `ansible -i inventory/hosts.ini cyberrange -m ping` succeeds.
2. Run `setup.yml` twice — second run MUST be `changed=0 failed=0` (idempotent).
3. Run the real exploit from the attacker container and confirm the exact `WMG{...}` flag.
4. Rebuild the target from scratch and run all games together — confirm no conflicts.

Then port to `topology.yml` + `training.json` + role-based `provisioning/`, re-verifying idempotency.

## THE GOLDEN RULE

**Always read `~/mirek-skills/` (mirrored in `skills/`) before generating any CyberRangeCZ
artifact** — topology, training definition, provisioning, or APG variables. It is the
authoritative source; these notes only summarise it and record what broke in practice.
