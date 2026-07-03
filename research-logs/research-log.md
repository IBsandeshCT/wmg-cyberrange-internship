# Research Log — WMG Cyberrange Internship

Each entry documents one meaningful action taken while building the
cyberrange. Written chronologically; newest entries at the bottom.

---

## Entry 1 — 2026-07-03 10:20

**Action:** Initial repository and environment inspection.

**Files modified:** none.

**Command executed:**
```
ansible -i inventory/hosts.ini cyberrange -m ping
```

**Result:** Failed.

**Error:**
```
Module result deserialization failed: No start of json char found
...
SyntaxError: future feature annotations is not defined
```

**Root cause:** The task brief's assumed fix (set
`ansible_python_interpreter=/usr/bin/python3.6`) does not work with the
installed `ansible-core 2.21.1`. Ansible's own modules embed
`from __future__ import annotations`, a Python **3.7+** syntax feature, so
they fail to even parse under the target container's Python 3.6.5 — before
any version-compatibility check even runs. The original target container
(`rastasheep/ubuntu-sshd:18.04`) only ships Python 3.6.5.

**Fix applied:** Investigated multiple paths (see Entry 2) before landing on
rebuilding the target container from a newer base image.

**Verification:** N/A at this point — see later entries.

**Human intervention required:** No.

**Lessons learned:** Always verify environment assumptions handed down in a
task brief against the actual installed tool versions before proceeding —
the "known issue" workaround given was itself outdated for the Ansible
version actually in use.

---

## Entry 2 — 2026-07-03 10:35

**Action:** Attempted to fix the Python interpreter gap by installing newer
Python packages onto the Ubuntu 18.04 target via apt and the deadsnakes PPA.

**Files modified:** none (container-only changes, later discarded).

**Command executed:**
```
docker exec cyberrange-target apt-get install -y python3.8
docker exec cyberrange-target add-apt-repository -y ppa:deadsnakes/ppa
docker exec cyberrange-target apt-cache madison python3.10 python3.11 python3.12
```

**Result:** Python 3.8 installed successfully via apt, but
`ansible-core 2.21.1` requires **Python 3.9+** on managed nodes
(`Ansible requires Python 3.9 or newer on the target. Current version: 3.8.0`).
Deadsnakes PPA for `bionic` (18.04) no longer publishes builds beyond
Python 3.8 — Ubuntu 18.04 is past its supported window for that project.

**Root cause:** Ubuntu 18.04's package ecosystem has no path to Python 3.9+
without compiling from source.

**Fix applied (attempted then reverted):** Started compiling CPython 3.11.9
from source inside the container. This was correctly flagged by the human
supervisor as too slow/heavyweight for this use case and was stopped.

**Better fix (adopted):** Replace the target container entirely with one
built from the official `ubuntu:22.04` base image (ships Python 3.10 by
default) plus `openssh-server`, defined in `docker/Dockerfile.target`. This
keeps a real, reproducible, from-scratch build (rather than depending on a
possibly-stale third-party image tag) and takes ~15 seconds to build instead
of several minutes to compile Python.

**Verification:** `docker build -t cyberrange-target-base -f docker/Dockerfile.target .`
completed successfully in ~15s.

**Human intervention required:** Yes — the human supervisor stopped an
in-progress source compile and directed the container-swap approach instead.

**Lessons learned:** For legacy-OS training targets, prefer bootstrapping a
small custom Dockerfile over hunting for a third-party image with the exact
OS/tool combination needed — it's faster, transparent, and fully
reproducible. Compiling toolchains from source inside a container is a
last resort, not a first move.

---

## Entry 3 — 2026-07-03 10:45

**Action:** Rebuilt and relaunched the target container; fixed inventory and
SSH host-key handling; re-ran the Ansible ping test.

**Files modified:**
- `docker/Dockerfile.target` (new)
- `inventory/hosts.ini` (updated `ansible_python_interpreter`, added
  `UserKnownHostsFile=/dev/null` to `ansible_ssh_common_args`)

**Command executed:**
```
docker stop cyberrange-target && docker rm cyberrange-target
docker build -t cyberrange-target-base -f docker/Dockerfile.target .
docker run -d --name cyberrange-target -p 2222:22 --cap-add=NET_ADMIN cyberrange-target-base
ansible -i inventory/hosts.ini cyberrange -m ping
```

**Result:** First re-run failed with:
```
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
... Permission denied (publickey,password).
```

**Error / Root cause:** The new container generates fresh SSH host keys on
every build/run. The previous container's key was cached in
`~/.ssh/known_hosts` under the same `127.0.0.1:2222` address, so OpenSSH
refused to connect, treating it as a possible MITM attack —
`StrictHostKeyChecking=no` alone does not override a *changed* (as opposed
to *unknown*) host key.

**Fix applied:** Added `-o UserKnownHostsFile=/dev/null` to
`ansible_ssh_common_args` in the inventory, which is appropriate for this
ephemeral, disposable local training container (not a real production host).

**Verification:**
```
target | SUCCESS => { "changed": false, "ping": "pong" }
```

**Human intervention required:** No.

**Lessons learned:** Any training range whose container gets rebuilt
regularly should never rely on `known_hosts` pinning — always pair
`StrictHostKeyChecking=no` with `UserKnownHostsFile=/dev/null` for ephemeral
lab targets.

---

## Entry 4 — 2026-07-03 10:55

**Action:** Installed verification tooling (hydra, nmap) needed to prove the
games are actually exploitable, without requiring host `sudo` access (not
available non-interactively in this session).

**Files modified:** `docker/Dockerfile.attacker` (new)

**Command executed:**
```
sudo apt-get install -y hydra nmap curl   # failed: sudo needs a password
docker build -t cyberrange-attacker -f docker/Dockerfile.attacker .
docker network create cyberrange-net
docker network connect cyberrange-net cyberrange-target
```

**Result:** `sudo` failed non-interactively. Built a small Kali-Linux-based
"attacker toolbox" image instead (`hydra`, `nmap`, `netcat`, `curl`,
`openssh-client`, `ftp`), and put it on a shared user-defined Docker network
with the target so tools can reach it by container name without depending on
host networking mode quirks under Docker Desktop/WSL2.

**Root cause:** No passwordless sudo configured for this session/user.

**Fix applied:** Containerized attacker toolchain instead of host installs.

**Verification:**
```
docker run --rm cyberrange-attacker hydra -h   # prints usage
docker run --rm cyberrange-attacker nmap -V    # Nmap version 7.99
docker run --rm --network cyberrange-net cyberrange-attacker nmap -p22 cyberrange-target
# -> 22/tcp open ssh
```

**Human intervention required:** No (worked around cleanly).

**Lessons learned:** Don't block on host package manager permissions when a
container can provide the same tool with zero host footprint — this also
makes the verification process itself reproducible for anyone cloning the
repo, since it doesn't depend on what's installed on their WSL distro.

---

## Entry 5 — 2026-07-03 11:10

**Action:** Built and verified Game 1 (SSH Weak Password Attack).

**Files modified:**
- `games/ssh-weak-password/setup.yml` (new)
- `games/ssh-weak-password/files/wordlist.txt` (new)
- `games/ssh-weak-password/briefing.md` (new)
- `games/ssh-weak-password/hints.md` (new)
- `games/ssh-weak-password/solution.md` (new)

**Command executed:**
```
ansible-playbook -i inventory/hosts.ini games/ssh-weak-password/setup.yml   # x2, to check idempotency
sshpass -p password123 ssh -p 2222 student@127.0.0.1 'cat ~/flag.txt'
docker run --rm --network cyberrange-net -v "$(pwd)/games/ssh-weak-password/files:/wordlists:ro" \
  cyberrange-attacker hydra -l student -P /wordlists/wordlist.txt ssh://cyberrange-target
```

**Result:** All green.
- Playbook run 1: `ok=7 changed=4 failed=0`
- Playbook run 2 (idempotency check): `ok=7 changed=0 failed=0`
- SSH login as `student`/`password123` succeeded; `flag.txt` readable:
  `WMG{ssh_w3ak_p4ssw0rds_are_never_ok}`
- Hydra cracked the password from the shipped wordlist:
  `[22][ssh] host: cyberrange-target login: student password: password123`

**Error:** None after the environment-level fixes above.

**Root cause:** N/A.

**Fix applied:** N/A.

**Verification:** See Result above — all 7 success criteria for Game 1 met.

**Human intervention required:** No.

**Lessons learned:** Using `chpasswd` via `shell` with `changed_when: false`
is simpler and just as idempotent in practice as generating a crypt hash
with a fixed salt for the `user` module's `password` field — no need for
`passlib` on the controller (which wasn't installed, and Python's `crypt`
module used to hash things on the controller is gone as of Python 3.13,
which this controller's Python 3.14 has). Also: never issue an `ansible.builtin.service`
restart against `sshd` on a container where `sshd -D` is PID 1 — it would
kill the container's main process instead of gracefully restarting.

---

## Entry 6 — 2026-07-03 11:25

**Action:** Built and verified Game 2 (Shellshock, CVE-2014-6271), including
compiling a genuinely vulnerable bash 4.3 from source alongside the
container's normal patched bash.

**Files modified:**
- `games/shellshock/setup.yml` (new)
- `games/shellshock/files/status.cgi` (new)
- `games/shellshock/briefing.md` (new)
- `games/shellshock/hints.md` (new)
- `games/shellshock/solution.md` (new)

**Command executed:**
```
ansible-playbook -i inventory/hosts.ini games/shellshock/setup.yml
docker run --rm --network cyberrange-net cyberrange-attacker \
  curl -s -H 'User-Agent: () { :; }; echo; echo; /bin/cat /opt/flag.txt' \
  http://cyberrange-target/cgi-bin/status.cgi
```

**Result:** First run: `ok=12 changed=10 failed=0`. Exploit immediately
retrieved the flag: `WMG{sh3llsh0ck_cve_2014_6271_env_vars_are_scary}`.
Confirmed `/flag.txt` and `/opt/flag.txt` both return HTTP 404 directly
(the flag has no route except the exploit).

**Error:** None on the exploit path. Idempotency check (see Entry 7) did
surface two real bugs.

**Root cause:** The target's own `/bin/bash` (5.1.16) is already patched, so
the CGI script's shebang points at a separately built, deliberately
unpatched bash 4.3 (`/usr/local/bin/bash-vulnerable`), leaving the rest of
the system (including SSH, apt, and Ansible's own remote execution) on the
safe, patched interpreter.

**Fix applied:** N/A for the exploit path — worked first try.

**Verification:** Exploit output matched the expected flag; direct HTTP
access to the flag file 404s as expected.

**Human intervention required:** No.

**Lessons learned:** For CVE-reproduction labs, don't touch the system's
real `/bin/bash` — build the vulnerable version to a separate path and
point only the target script's shebang at it. This keeps the rest of the
training range (including the Ansible control channel) stable and avoids
accidentally breaking every other shell script on the box.

---

## Entry 7 — 2026-07-03 11:35

**Action:** Re-ran Game 2's playbook a second time to verify idempotency;
found and fixed two non-idempotent tasks.

**Files modified:** `games/shellshock/setup.yml`

**Command executed:**
```
ansible-playbook -i inventory/hosts.ini games/shellshock/setup.yml   # 2nd run
```

**Result (before fix):** `ok=11 changed=2 failed=0 skipped=1` — two tasks
kept reporting `changed` on every run.

**Error / Root cause:**
1. `Enable Apache's CGI module` used `creates: /etc/apache2/mods-enabled/cgi.load`,
   but Ubuntu's default MPM (`mpm_event`) is threaded and incompatible with
   `mod_cgi`, so `a2enmod cgi` silently substitutes `mod_cgid` instead. The
   real enabled file is `cgid.load`, so the `creates` guard never matched
   and the command re-ran every time (harmlessly, but inaccurately reported
   as `changed`).
2. `Ensure Apache is running` ran `apache2ctl start` unconditionally and
   tried to detect "already running" by checking `apache_start.stderr` for
   the word "already" — but `apache2ctl`/`apachectl` prints that message to
   **stdout**, not stderr, so the check never matched and the task always
   reported `changed`.

**Fix applied:**
1. Changed the `creates` guard to `/etc/apache2/mods-enabled/cgid.load`.
2. Replaced the stderr-sniffing hack with an explicit `pgrep -x apache2`
   pre-check task (`changed_when: false`), and made the actual `apache2ctl
   start` task conditional on `apache_running.rc != 0`.

**Verification:**
```
ansible-playbook -i inventory/hosts.ini games/shellshock/setup.yml
# -> ok=11 changed=0 failed=0 skipped=2
```
Re-ran the Shellshock exploit after the fix — still returns the flag
correctly.

**Human intervention required:** No.

**Lessons learned:** Don't infer "already running"/"no-op" state by
grepping a specific output stream from a wrapper script (`apachectl`) whose
stdout/stderr split isn't documented or guaranteed — use a dedicated,
purpose-built check (`pgrep`) instead. Also: always verify a module's
*actual* on-disk side effects (`ls mods-enabled/`) rather than assuming the
`creates:` path matches the command's own naming.

---

## Entry 8 — 2026-07-03 11:50

**Action:** Built Game 3 (Network Reconnaissance) — anonymous FTP decoy,
decoy HTTP vhost on port 8080, and a custom Python TCP banner service on
port 7777 holding the real flag.

**Files modified:**
- `games/network-recon/setup.yml` (new)
- `games/network-recon/files/banner_service.py.j2` (new)
- `games/network-recon/files/ftp_readme.txt` (new)
- `games/network-recon/files/decoy_index.html` (new)
- `games/network-recon/briefing.md` (new)
- `games/network-recon/hints.md` (new)
- `games/network-recon/solution.md` (new)

**Command executed:**
```
ansible-playbook -i inventory/hosts.ini games/network-recon/setup.yml
```

**Result (first attempt):** The playbook hung indefinitely on the
`Start vsftpd` task and the PowerShell tool auto-backgrounded the command.

**Error:** No error text — a genuine hang.

**Root cause:** Unlike `apache2ctl start` (which forks to background and
returns immediately), invoking `vsftpd /etc/vsftpd.conf` directly runs it in
the foreground on this system, so the Ansible `command` task blocked
forever waiting for a process that never exits.

**Fix applied:** Stopped the stuck task (`TaskStop`), killed the orphaned
`vsftpd` process in the container, and changed the "start vsftpd" task to
use `async: 86400, poll: 0` (fire-and-forget), matching the pattern already
used for the custom banner service.

**Verification:** Re-ran the playbook; `Start vsftpd` now returns
immediately and the process is confirmed running via `pgrep`.

**Human intervention required:** No.

**Lessons learned:** Never assume a daemon self-backgrounds just because
another one on the same box does (`apache2ctl` does, plain `vsftpd` on this
image doesn't) — verify empirically, and default to `async`/`poll: 0` for
any service-launching `command` task on an init-system-less container.

---

## Entry 9 — 2026-07-03 12:00

**Action:** Verified all three Game 3 services with nmap and manual
connections; found and fixed a second real bug (anonymous FTP silently
non-functional).

**Files modified:** `games/network-recon/setup.yml`

**Command executed:**
```
docker run --rm --network cyberrange-net cyberrange-attacker nmap -sV -p21,80,8080,7777 cyberrange-target
docker run --rm --network cyberrange-net cyberrange-attacker curl -s ftp://cyberrange-target/readme.txt
```

**Result:** nmap correctly identified all four ports/services, including
capturing the port-7777 banner (and flag) directly in its fingerprint dump.
However, the FTP download failed with curl exit code 8 ("weird server
reply"), and nmap flagged vsftpd itself as
`vsftpd (broken: not found: directory given in 'secure_chroot_dir':/var/run/vsftpd/empty)`.

**Error:** `curl: (8)` / nmap's "broken" annotation on the vsftpd version
string.

**Root cause:** vsftpd's default config references
`secure_chroot_dir=/var/run/vsftpd/empty`, a directory normally created at
boot by `systemd-tmpfiles`. This container has no systemd, so the directory
never gets created and every FTP session — even anonymous, read-only ones —
fails before a file can be transferred.

**Fix applied:** Added an explicit
`ansible.builtin.file: path=/var/run/vsftpd/empty state=directory` task
before starting vsftpd.

**Verification:**
```
curl -s ftp://cyberrange-target/readme.txt
# -> returns the decoy readme content correctly
```
Confirmed via `/var/log/vsftpd.log` inside the container that the
subsequent login and download both succeeded. Re-ran the full playbook
afterward: `ok=17 changed=0 failed=0 skipped=5` (fully idempotent).

**Human intervention required:** No.

**Lessons learned:** Packages designed around systemd often silently rely
on `systemd-tmpfiles.d` to create runtime directories at boot. Any package
providing a `/usr/lib/tmpfiles.d/*.conf` file is a candidate for this class
of bug when deployed into a systemd-less container — check for and
recreate those paths explicitly rather than assuming "apt install" alone
leaves a service fully functional.

---

## Entry 10 — 2026-07-03 12:15

**Action:** `games/network-recon/setup.yml` was simplified externally
(dropped the separate Apache vhost/port-8080 decoy in favor of overwriting
the default site's `index.html` on port 80, and moved the banner service
from port 7777 to port 8888). Re-verified the game end-to-end against this
simplified version and updated `solution.md` to match the new ports/design
(`hints.md` and `briefing.md` didn't reference specific ports, so no change
needed there).

**Files modified:** `games/network-recon/solution.md`

**Command executed:**
```
ansible-playbook -i inventory/hosts.ini games/network-recon/setup.yml
nmap -sV -p21,80,8888 cyberrange-target
curl -s ftp://cyberrange-target/readme.txt
curl -s http://cyberrange-target/
exec 3<>/dev/tcp/cyberrange-target/8888; cat <&3
```

**Result:** All green with the new design — FTP and HTTP(80) both serve
decoys, port 8888 serves the banner + flag
(`WMG{r3c0n_1s_m0r3_th4n_just_p0rt_sc4nning}`).

**Error:** None.

**Root cause:** N/A — this was a design simplification, not a bug fix.

**Fix applied:** N/A (docs update only).

**Verification:** See Result above.

**Human intervention required:** No (external edit was pre-applied to the
file; documentation was reconciled to match).

**Lessons learned:** Keep an eye out for external edits to files mid-task
and treat them as authoritative — re-verify against the changed file rather
than assuming previous test results still apply, then bring the
documentation back into sync rather than reverting the change.

---

## Entry 11 — 2026-07-03 12:30

**Action:** Full clean-slate end-to-end verification: destroyed and
rebuilt `cyberrange-target` from scratch, confirmed only `sshd` was running
pre-playbook, then ran all three games' playbooks in sequence against the
same fresh container (proving they coexist without conflict), followed by
a second pass of all three to confirm idempotency of the full combined
stack.

**Files modified:** none.

**Command executed:**
```
docker rm -f cyberrange-target
docker run -d --name cyberrange-target -p 2222:22 --cap-add=NET_ADMIN cyberrange-target-base
docker network connect cyberrange-net cyberrange-target
ansible -i inventory/hosts.ini cyberrange -m ping
ansible-playbook -i inventory/hosts.ini games/ssh-weak-password/setup.yml
ansible-playbook -i inventory/hosts.ini games/shellshock/setup.yml
ansible-playbook -i inventory/hosts.ini games/network-recon/setup.yml
# then all three again, unchanged
```

**Result:**
- Ping: success.
- Game 1: `ok=7 changed=4 failed=0` → re-run `changed=0`.
- Game 2: `ok=13 changed=10 failed=0` → re-run `changed=0`.
- Game 3: `ok=15 changed=10 failed=0 ignored=1` (the ignored failure is the
  expected/intentional `wait_for` pre-check on first run) → re-run
  `changed=0`.
- All three flags retrieved correctly in the same pass:
  `WMG{ssh_w3ak_p4ssw0rds_are_never_ok}`,
  `WMG{sh3llsh0ck_cve_2014_6271_env_vars_are_scary}`,
  `WMG{r3c0n_1s_m0r3_th4n_just_p0rt_sc4nning}`.
- Confirmed Game 3 overwriting `/var/www/html/index.html` does not break
  Game 2's Shellshock exploit (which targets `/cgi-bin/status.cgi`, an
  unrelated path).

**Error:** None on this clean run. (An earlier, separate rebuild attempt
appeared to show services already running before their playbooks had been
invoked; a follow-up fresh rebuild with an immediate `pgrep` check before
running any playbook showed only `sshd` present, and the subsequent full
run behaved exactly as expected — treating the earlier anomaly as a
one-off observation, not a reproducible bug, since it did not recur.)

**Root cause:** N/A for the clean run.

**Fix applied:** N/A.

**Verification:** See Result above — this is the final, authoritative
end-to-end verification of all three games together, from a genuinely
fresh container.

**Human intervention required:** No.

**Lessons learned:** Always do at least one full-stack, fresh-container
run of every game together, not just each game in isolation — it's the
only way to catch cross-game conflicts (like two games both wanting
`apache2` or both writing to the same web root).

---

## Entry 12 — 2026-07-03 (independent verification pass)

**Action:** A second work pass on this repository (this session) inspected
the already-built project from scratch, then independently re-verified
every success criterion rather than trusting prior entries at face value.
This entry documents what was found and confirmed.

**Files modified:** `games/network-recon/setup.yml` (ports corrected —
see below; superseded/reconciled by Entry 10, written concurrently),
`research-logs/research-log.md` (this entry).

**Findings and actions:**

1. `ansible`/`ansible-playbook` are installed via `pip install --user`
   under `~/.local/bin`, which is only on `PATH` in a login shell — plain
   `bash -c` cannot find them, `bash -lc` can. Not a bug, just an
   environment quirk worth documenting (added to README troubleshooting).
2. Re-ran Games 1 and 2 against the already-provisioned container: both
   idempotent (`changed=0 failed=0`), and independently re-verified the
   actual exploits (`sshpass` SSH login + flag read, `hydra` crack, and the
   Shellshock `curl` payload) rather than trusting the existing log
   entries alone.
3. At the time this session started, `games/network-recon/setup.yml` still
   used the original design (decoy Apache vhost on port 8080, banner
   service on port 7777), which does not match the task's required port
   scheme (FTP 21 / HTTP 80 / custom service 8888). Fixed by dropping the
   separate decoy vhost entirely (it would have silently lost to
   `000-default.conf` for any plain request anyway, since neither vhost
   sets a `ServerName` to disambiguate) and instead overwriting the
   default site's `index.html` on port 80, and moving the banner service
   to port 8888. (This is the same edit Entry 10 describes reconciling
   documentation against — the two write-ups describe the same change.)
4. Mid-session, a transient infrastructure blip occurred: `docker ps`
   showed `cyberrange-target`'s `StartedAt` jump forward with
   `RestartCount` still `0`, consistent with Docker Desktop's WSL2 VM
   being paused/resumed under memory pressure rather than a real container
   crash. Apache and vsftpd survived (real daemons that double-fork and
   detach from their controlling session), but the plain
   `banner_service.py` process — a single foreground Python script backed
   only by Ansible's `async`/`poll: 0` job wrapper, not a true daemon —
   did not. Re-running `games/network-recon/setup.yml` detected the gap
   (`wait_for` on port 8888 timed out) and relaunched it automatically:
   this is the intended self-healing behavior of the existing
   check-then-launch pattern, not a bug, and required no code change.
5. Ran a full re-verification pass on the current live container (all
   three playbooks run to completion, all `changed=0` on this repeat run,
   all three flags re-confirmed by direct exploit) to produce this
   session's own first-hand evidence, independent of earlier sessions'
   results.

**Result:** All three games confirmed working end-to-end on the live
container: idempotent playbooks, all three flags retrievable exactly as
specified, `README.md` and every game's `briefing.md`/`hints.md`/
`solution.md` present and accurate against the current port scheme.

**Error:** None outstanding.

**Root cause:** N/A (verification pass; the one real fix — Game 3's ports
— is covered above and in Entry 10).

**Fix applied:** See point 3 above.

**Verification:** See point 5 above; also directly observed:
```
target : ok=7  changed=0 failed=0   (ssh-weak-password, re-run)
target : ok=11 changed=0 failed=0   (shellshock, re-run)
target : ok=13 changed=0 failed=0   (network-recon, re-run)
WMG{ssh_w3ak_p4ssw0rds_are_never_ok}
WMG{sh3llsh0ck_cve_2014_6271_env_vars_are_scary}
WMG{r3c0n_1s_m0r3_th4n_just_p0rt_sc4nning}
```

**Human intervention required:** No.

**Lessons learned:** When picking up an in-progress project, don't assume
existing log entries reflect the current state of the repo or the live
environment — re-run and re-observe everything first-hand before adding to
the record. Also: a fire-and-forget script launched via `async: 86400,
poll: 0` is only as robust as the process it launches; a real daemon that
double-forks survives infrastructure hiccups that a naive foreground
script does not, but a detect-and-relaunch guard (already present here)
makes that difference invisible to the end user.
