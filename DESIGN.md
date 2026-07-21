## Task: xss-stored game (2026-07-21)
Plan: Stored XSS via PHP guestbook with admin bot — COMPLETE, verify.sh PASS, idempotent
### Facts
- 8 working games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc, sqli-login, dir-traversal, xss-stored
- verify-all.sh passes 8/8 at 100%
- xss-stored: Apache + PHP guestbook; messages stored unsanitised in /var/www/data/messages.json
- xss-stored exploit chain: POST XSS payload → GET /bot.php (simulates admin visit, writes cookie to collected.txt) → GET /collect.php (returns stolen cookie/flag)
- xss-stored key insight: bot.php detects 'collect.php' in any stored message and writes the admin cookie, simulating stored XSS firing in victim's browser
- xss-stored flag: WMG{xss_st0l3n_admin_s3ss10n} stored as admin_session cookie value in bot.php
- XSS idempotency: messages.json and collected.txt reset to empty on each deploy (changed=1 by design)
- CyberRange repo: ~/wmg-xss-stored-cyberrange/ (topology 10.1.31.0/24 + provisioning)
### Gaps
- None — verified working
