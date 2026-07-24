## Task: documentation update (2026-07-24)
Plan: Rewrite all docs to reflect 13 games, 9-level training.json, ongoing model comparison — COMPLETE

## Current state: 13 games, all PASS, model comparison in progress

### Facts
- 13 verified working games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc, sqli-login, dir-traversal, xss-stored, ssh-weak-v2, sqli-v2, privesc-v2, ssh-weak-v3, sqli-v3
- verify-all.sh: 13/13 PASS 100% (last confirmed 2026-07-24)
- All 13 training.json files: 9-level deep format, immersive scenario prose, MITRE ATT&CK technique_key, 2-3 hints per level, scoring L2=50/false, L3-L7=100/true, L6=150, ASSESSMENT=0
- All 11 original games upgraded from 5-level to 9-level format on 2026-07-24
- sqli-v3 (13th game): Python3 binary blind SQLi, boolean UNICODE+SUBSTR search, ~245 requests
- ssh-weak-v3 (12th game): Crestwood University scenario, itstaff/Campus2024, campus-passwords.txt wordlist
- Model comparison: Sonnet 4.6 used for all 13 games; Fable 5, Haiku 4.5, Opus 4.8 evaluation in progress
- generate-and-verify.sh: autonomous generate→verify→repair loop, MAX_ITERATIONS=5 default
- Next available subnet: 10.1.37.0/24
- Next task: model comparison experiments (Fable 5, Haiku 4.5, Opus 4.8 vs Sonnet 4.6)

### CyberRange repos
- ~/wmg-ssh-cyberrange/ — ssh-weak-password
- ~/wmg-shellshock-cyberrange/ — shellshock
- ~/wmg-network-recon-cyberrange/ — network-recon
- ~/wmg-suid-privesc-cyberrange/ — 10.1.28.0/24
- ~/wmg-sqli-login-cyberrange/ — 10.1.29.0/24
- ~/wmg-dir-traversal-cyberrange/ — 10.1.30.0/24
- ~/wmg-xss-stored-cyberrange/ — 10.1.31.0/24
- ~/wmg-ssh-weak-v2-cyberrange/ — 10.1.32.0/24
- ~/wmg-sqli-v2-cyberrange/ — 10.1.33.0/24
- ~/wmg-privesc-v2-cyberrange/ — 10.1.34.0/24
- ~/wmg-ssh-weak-v3-cyberrange/ — 10.1.35.0/24
- ~/wmg-sqli-v3-cyberrange/ — 10.1.36.0/24
- ftp-anon: no CyberRange repo yet (IPs inferred from platform defaults)

### Gaps
- Model comparison not yet run: need timed generation runs with Fable 5, Haiku 4.5, Opus 4.8
- ftp-anon CyberRange repo not created
- No per-student flag variants (APG) — all games use a fixed flag

## Task: training.json deep upgrade — all 11 games (2026-07-24)
Plan: Expand all games from 5-level to 9-level training.json with immersive stories, MITRE techniques, 2-3 hints per level, traceability to setup.yml, and ASSESSMENT_LEVEL — COMPLETE, verify-all.sh 13/13 PASS
### Facts
- All 11 upgraded games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc, sqli-login, dir-traversal, xss-stored, ssh-weak-v2, sqli-v2, privesc-v2
- 4 new training.json (ssh-weak-password, shellshock, network-recon, ftp-anon); 7 expanded from 5→9 levels
- Every level: MITRE ATT&CK technique_key, incorrect_answer_limit=10, hint_penalty_sum < max_score
- Scoring: L2 sol_pen=false max_score=50; L3-L7 sol_pen=true max_score=100 (L6=150); ASSESSMENT max_score=0
- verify-all.sh: 13 games 13/13 PASS 100% (includes sqli-v3 and ssh-weak-v3 which are unrelated)
- No setup.yml or Ansible files touched — only training.json modified

## Task: sqli-v3 game (2026-07-22)
Plan: Fresh boolean-based blind SQLi (Northgate Veterinary Clinic) — COMPLETE, verify.sh PASS
### Facts
- sqli-v3: Apache+PHP+SQLite; lookup.php GET /lookup.php?id=N returns only "Patient found: <name>" or "No record found." — no data echoed
- sqli-v3: boolean blind injection via id param; hidden table clinic_secrets; flag WMG{bl1nd_sql1_tr00th_0r_n0_tr00th}
- sqli-v3 exploit: Python3 binary search using UNICODE(SUBSTR(record,N,1))>=MID; ~245 requests; ~15s total
- sqli-v3 distinct from sqli-login (auth bypass) and sqli-v2 (UNION extraction); teaches blind injection + sqlmap --technique=B
- CyberRange repo: ~/wmg-sqli-v3-cyberrange/ (topology 10.1.36.0/24 + provisioning)

## Task: ssh-weak-v3 game (2026-07-22, rebuilt)
Plan: Fresh weak-SSH-password variant (Crestwood University, campus-themed wordlist) — COMPLETE, verify.sh PASS, idempotent
### Facts
- ssh-weak-v3: user itstaff/Campus2024; flag ~/ticket-export.txt; campus-passwords.txt wordlist (academic-themed); teaches OSINT-driven password targeting in education sector
- CyberRange repo: ~/wmg-ssh-weak-v3-cyberrange/ (topology 10.1.35.0/24 + provisioning)

## Task: privesc-v2 game (2026-07-22)
Plan: Fresh privesc via sudo misconfiguration (NOPASSWD find -exec) — COMPLETE, verify.sh PASS, idempotent
### Facts
- privesc-v2: user webadmin/Deploy2024!; /etc/sudoers.d/webadmin grants NOPASSWD /usr/bin/find; flag /root/flag.txt mode 0400
- privesc-v2 exploit: sshpass ssh webadmin@target 'sudo /usr/bin/find /etc/hostname -exec cat /root/flag.txt \;'
- privesc-v2 flag: WMG{sud0_f1nd_3xec_r00ts_y0u}
- CyberRange repo: ~/wmg-privesc-v2-cyberrange/ (topology 10.1.34.0/24 + provisioning)

## Task: sqli-v2 game (2026-07-21)
Plan: Fresh UNION-based SQLi (Athenaeum Library catalogue search) — COMPLETE, verify.sh PASS, idempotent
### Facts
- sqli-v2: Apache+PHP+SQLite; search.php UNION-injectable; flag WMG{un10n_b4s3d_sql1_l34ks_th3_db} in librarian_notes table
- CyberRange repo: ~/wmg-sqli-v2-cyberrange/ (topology 10.1.33.0/24 + provisioning)

## Task: ssh-weak-v2 game (2026-07-21)
Plan: Fresh weak-SSH-password variant (Halcyon Marine, hydra dictionary attack) — COMPLETE, verify.sh PASS, idempotent
### Facts
- ssh-weak-v2: user 'deckhand'/'Sailor2024'; flag at ~/manifest.txt; wordlist crew-passwords.txt
- CyberRange repo: ~/wmg-ssh-weak-v2-cyberrange/ (topology 10.1.32.0/24 + provisioning)

## Task: xss-stored game (2026-07-21)
Plan: Stored XSS via PHP guestbook with admin bot — COMPLETE, verify.sh PASS, idempotent
### Facts
- xss-stored: Apache + PHP guestbook; messages stored unsanitised in /var/www/data/messages.json
- xss-stored exploit chain: POST XSS payload → GET /bot.php → GET /collect.php (returns stolen cookie/flag)
- flag: WMG{xss_st0l3n_admin_s3ss10n} stored as admin_session cookie value in bot.php
- CyberRange repo: ~/wmg-xss-stored-cyberrange/ (topology 10.1.31.0/24 + provisioning)
