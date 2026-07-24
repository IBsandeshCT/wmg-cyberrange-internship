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
- 13 working games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc, sqli-login, dir-traversal, xss-stored, ssh-weak-v2, sqli-v2, privesc-v2, ssh-weak-v3, sqli-v3
- sqli-v3: Apache+PHP+SQLite; lookup.php GET /lookup.php?id=N returns only "Patient found: <name>" or "No record found." — no data echoed
- sqli-v3: boolean blind injection via id param; hidden table clinic_secrets; flag WMG{bl1nd_sql1_tr00th_0r_n0_tr00th}
- sqli-v3 exploit: Python3 binary search using UNICODE(SUBSTR(record,N,1))>=MID; ~245 requests; ~15s total
- sqli-v3 distinct from sqli-login (auth bypass) and sqli-v2 (UNION extraction); teaches blind injection + sqlmap --technique=B
- CyberRange repo: ~/wmg-sqli-v3-cyberrange/ (topology 10.1.36.0/24 + provisioning)
- Next available subnet: 10.1.37.0/24

## Task: ssh-weak-v3 game (2026-07-22, rebuilt)
Plan: Fresh weak-SSH-password variant (Crestwood University, campus-themed wordlist) — COMPLETE, verify.sh PASS, idempotent
### Facts
- 12 working games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc, sqli-login, dir-traversal, xss-stored, ssh-weak-v2, sqli-v2, privesc-v2, ssh-weak-v3
- verify-all.sh passes 12/12 at 100%
- ssh-weak-v3: user itstaff/Campus2024; flag ~/ticket-export.txt; campus-passwords.txt wordlist (academic-themed); teaches OSINT-driven password targeting in education sector
- ssh-weak-v3 distinct from ssh-weak-password (student/password123), ssh-weak-v2 (deckhand/Sailor2024), and prior v3 (shiftlead/Apex2024 — replaced)
- CyberRange repo: ~/wmg-ssh-weak-v3-cyberrange/ (topology 10.1.35.0/24 + provisioning)
- Next available subnet: 10.1.36.0/24

## Task: privesc-v2 game (2026-07-22)
Plan: Fresh privesc via sudo misconfiguration (NOPASSWD find -exec) — COMPLETE, verify.sh PASS, idempotent
### Facts
- 11 working games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc, sqli-login, dir-traversal, xss-stored, ssh-weak-v2, sqli-v2, privesc-v2
- verify-all.sh passes 11/11 at 100%
- privesc-v2: user webadmin/Deploy2024!; /etc/sudoers.d/webadmin grants NOPASSWD /usr/bin/find; flag /root/flag.txt mode 0400; distinct technique from suid-privesc (SUID bash)
- privesc-v2 exploit: sshpass ssh webadmin@target 'sudo /usr/bin/find /etc/hostname -exec cat /root/flag.txt \;'
- privesc-v2 flag: WMG{sud0_f1nd_3xec_r00ts_y0u}
- privesc-v2 sudoers written with validate: 'visudo -cf %s' to avoid lockout; idempotent changed=0 on 2nd run
- CyberRange repo: ~/wmg-privesc-v2-cyberrange/ (topology 10.1.34.0/24 + provisioning)

## Task: sqli-v2 game (2026-07-21)
Plan: Fresh UNION-based SQLi (Athenaeum Library catalogue search) — COMPLETE, verify.sh PASS, idempotent
### Facts
- sqli-v2: Apache+PHP+SQLite; search.php runs SELECT title,author FROM books WHERE title LIKE '%$q%' (2 cols) — UNION-injectable; distinct from sqli-login (login bypass)
- sqli-v2: Apache+PHP+SQLite; search.php runs SELECT title,author FROM books WHERE title LIKE '%$q%' (2 cols) — UNION-injectable; distinct from sqli-login (login bypass)
- sqli-v2 exploit: curl -G search.php --data-urlencode "q=' UNION SELECT note,'x' FROM librarian_notes -- -" → flag rendered as a fake book title
- sqli-v2 flag: WMG{un10n_b4s3d_sql1_l34ks_th3_db} in librarian_notes.note table
- sqli-v2 idempotent: changed=1 on second run (unconditional Apache restart, by design)
- CyberRange repo: ~/wmg-sqli-v2-cyberrange/ (topology 10.1.33.0/24 + provisioning)

## Task: ssh-weak-v2 game (2026-07-21)
Plan: Fresh weak-SSH-password variant (Halcyon Marine, hydra dictionary attack) — COMPLETE, verify.sh PASS, idempotent
### Facts
- ssh-weak-v2: user 'deckhand'/'Sailor2024'; flag at ~/manifest.txt; wordlist crew-passwords.txt; distinct from ssh-weak-password (student/password123)
- ssh-weak-v2: user 'deckhand'/'Sailor2024'; flag at ~/manifest.txt; wordlist crew-passwords.txt; distinct from ssh-weak-password (student/password123)
- ssh-weak-v2 exploit: sshpass -p Sailor2024 ssh deckhand@target 'cat ~/manifest.txt'
- ssh-weak-v2 flag: WMG{w3ak_ssh_cr3ds_s1nk_sh1ps}
- ssh-weak-v2 idempotent: changed=0 on second run (no sshd reload task — matches proven ssh-weak-password pattern; avoids PID-1 sshd trap)
- CyberRange repo: ~/wmg-ssh-weak-v2-cyberrange/ (topology 10.1.32.0/24 + provisioning; handler restarts 'ssh' since target is not init-less there)

## Task: xss-stored game (2026-07-21)
Plan: Stored XSS via PHP guestbook with admin bot — COMPLETE, verify.sh PASS, idempotent
### Facts
- xss-stored: Apache + PHP guestbook; messages stored unsanitised in /var/www/data/messages.json
- xss-stored: Apache + PHP guestbook; messages stored unsanitised in /var/www/data/messages.json
- xss-stored exploit chain: POST XSS payload → GET /bot.php (simulates admin visit, writes cookie to collected.txt) → GET /collect.php (returns stolen cookie/flag)
- xss-stored key insight: bot.php detects 'collect.php' in any stored message and writes the admin cookie, simulating stored XSS firing in victim's browser
- xss-stored flag: WMG{xss_st0l3n_admin_s3ss10n} stored as admin_session cookie value in bot.php
- XSS idempotency: messages.json and collected.txt reset to empty on each deploy (changed=1 by design)
- CyberRange repo: ~/wmg-xss-stored-cyberrange/ (topology 10.1.31.0/24 + provisioning)
### Gaps
- None — verified working
