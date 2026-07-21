## Task: sqli-v2 game (2026-07-21)
Plan: Fresh UNION-based SQLi (Athenaeum Library catalogue search) — COMPLETE, verify.sh PASS, idempotent
### Facts
- 10 working games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc, sqli-login, dir-traversal, xss-stored, ssh-weak-v2, sqli-v2
- verify-all.sh passes 10/10 at 100%
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
