# CyberRangeCZ Game Builder — Lazy Senior Dev Guide

---

## SECTION 0 — PRIME DIRECTIVE

**Think long, call once.**

Before every tool call answer these four questions:
1. What exactly do I need?
2. Can I chain multiple things into one call?
3. Do I already know this from prior context?
4. Is this call strictly necessary?

**Hard budget: 3 tool round trips per investigation.**
If you haven't found it in 3 tries, you're searching wrong — stop and restate the question.

**Cap every output:** append `| head -50` to every shell command that might be verbose.

**Never `cat` whole files.** Use `grep` and slice only:
```bash
grep -n "keyword" file.yml | head -20
sed -n '10,30p' file.yml
```

---

## SECTION 1 — PERSISTENT MEMORY

At the **start of every session**, read both:
- `DESIGN.md` — current task, plan, known facts (file:line), open gaps
- `CHANGELOG.md` — what changed, what failed, what dead ends were hit

At the **end of every session** (or whenever state changes), update both.

### DESIGN.md format
```
## Task
One sentence: what we are building right now.

## Plan
Ordered steps, checked off as done.

## Facts
- games/ssh-weak-password/setup.yml:42 — password hash uses fixed salt
- agent-harness/verify.sh:15 — exit 0 = PASS contract

## Gaps
- Unknown: does ftp-anon game need vsftpd restart handler?
```

### CHANGELOG.md format
```
## 2026-07-21
- Changed: rewrote shellshock CGI handler
- Outcome: verify.sh PASS on first run
- Dead end: tried restarting apache2 via notify — killed container (sshd-as-PID1 trap)
```

**Dead ends are the most valuable entries.** If you hit a dead end, log it immediately and stop retrying the same approach.

---

## SECTION 2 — LAZINESS LADDER

Before writing any code, climb this ladder:

1. **Does it need to exist?** Can the task be done by changing config, not adding code?
2. **Does it already exist?** Check `games/`, `~/junior-hacker/`, `~/wmg-ssh-cyberrange/`.
3. **Can it be one line?** Minimum code that works is the right answer.

Rules:
- No boilerplate nobody asked for.
- No abstractions unless they're solving a real, current problem.
- No helper functions for one-time operations.
- Copy a working pattern verbatim before inventing a new one.
- Three similar lines is better than a premature abstraction.

---

## SECTION 3 — EVIDENCE DISCIPLINE

- **Never fabricate** command output, exit codes, or commit hashes.
- **Never guess** — if you don't know, say "gap" and investigate.
- **Live code beats documentation** — if the skill file says X but the working game does Y, trust the game.
- Only claim PASS if you actually saw exit code 0.
- Only claim idempotent if you actually ran the playbook twice.

---

## SECTION 4 — CYBERRANGE ENVIRONMENT FACTS

**Platform:** CyberRangeCZ on OpenStack at `cr.cyber.warwick.ac.uk`

**Deployment unit:**
- Sandbox Definition = Git repo with `topology.yml` + `provisioning/`
- Training Definition = `training.json` uploaded manually via the portal
- These are separate artifacts; the portal links them.

**Local test environment:**
- Docker container `cyberrange-target` — Ubuntu 22.04
- Ports: SSH=2222, HTTP=80, FTP=21, custom banner=8888
- Ansible inventory: `~/wmg-cyberrange-internship/inventory/hosts.ini`
- `ansible_python_interpreter=/usr/bin/python3`

**Kali attacker (in CyberRange):**
- NO internet during provisioning
- NEVER use `apt-get` in attacker provisioning
- All tools pre-installed: `nmap`, `hydra`, `curl`, `netcat`, `sshpass`, `ftp`, `sqlmap`, `nikto`, `gobuster`, `john`, `hashcat`

**Target server (in CyberRange):**
- Debian 12, HAS internet during provisioning
- Use `ansible.builtin.apt` freely

**Ansible rules:**
- Always idempotent — second run must be `changed=0 failed=0`
- Use handlers for service restarts
- **Force Apache restart after CGI config** — `meta: flush_handlers` or explicit restart task; this is a known issue (see CHANGELOG.md)
- Never restart `sshd` where `sshd -D` is PID 1 — kills the container
- Fixed salt for password hashes — random salt breaks idempotency
- `creates:` guards must check the *actual* file produced, not the command name

**training.json constraints:**
- All string fields must be under 255 characters
- Hint penalties must not sum to more than `max_score` for that level
- Always: `"show_stepper_bar": true`, `"variant_sandboxes": false`
- Level `order` starts at 0, no gaps

**Reference game:** `~/junior-hacker/` — read its structure before building anything new.

---

## SECTION 5 — EXISTING GAMES

| Game | Vulnerability | Status |
|------|--------------|--------|
| `games/ssh-weak-password/` | SSH brute force (hydra) | PASSES verify.sh |
| `games/shellshock/` | CVE-2014-6271 Apache CGI | PASSES verify.sh |
| `games/network-recon/` | nmap reconnaissance | PASSES verify.sh |
| `games/ftp-anon/` | Anonymous FTP login | PASSES verify.sh |

**CyberRangeCZ deployment repos:**
- `~/wmg-ssh-cyberrange` — SSH weak password, fully ported
- `~/wmg-shellshock-cyberrange` — Shellshock, fully ported
- `~/wmg-network-recon-cyberrange` — Network recon, fully ported

When building a new game, pick the closest existing game as a template and diff from there.

---

## SECTION 6 — VERIFICATION

**Run:** `agent-harness/verify.sh <game-name>`

**Contract:**
- Exit 0 = PASS
- Exit 1 = FAIL
- Never claim PASS without seeing exit code 0

**Exploit definitions:** `agent-harness/exploits/<game-name>.exploit`
- Must be a standalone bash script that drives the full exploit and prints the flag
- The harness sources this and checks that `WMG{...}` appears in stdout

**Known issues:**
- Apache requires a forced restart after CGI module config — the `a2enmod cgid` task and handler flush must be explicit. Tracked in CHANGELOG.md.
- vsftpd on init-less containers: launch with `async: 86400, poll: 0`; create `/var/run/vsftpd/empty` explicitly before starting.

---

## SECTION 7 — AUTONOMOUS GAME BUILDER WORKFLOW

When asked to build a game from a learning objective, execute **all of this without asking permission**:

1. Read `DESIGN.md` and `CHANGELOG.md`
2. Read `~/junior-hacker/` structure (`ls` + key files)
3. Read one existing working game whose vuln is closest to the target
4. Design: vulnerability class, scenario prose, flag location, exploit path
5. Write `agent-harness/exploits/<name>.exploit`
6. Write `games/<name>/setup.yml` for local Docker testing
7. Run `verify.sh` — fix until exit 0; log every dead end in CHANGELOG.md
8. Write `training.json` following `~/junior-hacker/` structure exactly
9. Write CyberRangeCZ repo: `topology.yml` + `provisioning/` (role-based)
10. Validate: `python3 -m json.tool training.json` and `yamllint topology.yml`
11. Git commit and push
12. Update `DESIGN.md` and `CHANGELOG.md` with outcomes
13. Report actual results only — commit SHA, verify exit code, any remaining gaps

**Stop rules:**
- Do not stop until `verify.sh` returns exit 0.
- Do not ask for permission between steps.
- Do not explain what you are about to do — just do it.
- Report only when done or genuinely blocked.

---

## SECTION 8 — MOST IMPORTANT RULE

**Never try to solve the problem too hard.**

After **2 failed attempts** at the same approach:
1. Stop.
2. Log the dead end in `CHANGELOG.md` with exactly what failed and why.
3. Ask the user for direction.

Do not descend into rabbit holes. The third attempt at the same broken approach is always wrong.

---

**One-line summary:**
Read notes first → plan like an architect → read code like a surgeon with output capped → record facts and dead ends → write minimum correct solution → verify it exits 0 → stop.
