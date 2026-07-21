## Task: sqli-login game (2026-07-21)
Plan: SQL injection login bypass via Apache + PHP + SQLite — COMPLETE, verify.sh PASS, idempotent
### Facts
- 6 working games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc, sqli-login
- verify-all.sh passes 6/6 at 100%
- sqli-login: Apache + PHP + SQLite; login.php concatenates input directly into SQL query
- sqli-login exploit: curl POST with username=' OR '1'='1' -- bypasses auth and reveals flag
- sqli-login DB: Python 3 (pre-installed) initialises SQLite at /var/www/db/app.db
- Apache restart (changed=1) is unconditional — by design, same as shellshock
- CyberRange repo: ~/wmg-sqli-login-cyberrange/ (topology 10.1.29.0/24 + provisioning)
- suid-privesc: copy of bash at /usr/local/bin/suid-shell with mode 04755 (root SUID)
- Apache needs forced restart after CGI/PHP module install (known issue)
- Kali has no internet during CyberRange provisioning
### Gaps
- Resume button on CyberRange training run not working (pre-existing)
- Student end-to-end run not yet completed on real platform (pre-existing)
