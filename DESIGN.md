## Task: dir-traversal game (2026-07-21)
Plan: Directory traversal path traversal via Apache file serving — COMPLETE, verify.sh PASS, idempotent
### Facts
- 7 working games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc, sqli-login, dir-traversal
- verify-all.sh passes 7/7 at 100%
- dir-traversal: Apache serves /var/www/html/; no path validation; files at /files/documents/ (public) and /secrets/ (traversable)
- dir-traversal exploit: curl http://target/files/../../secrets/flag.txt → reads flag via path traversal
- dir-traversal fix: First attempt used /etc/flag-dirtrav.txt but Apache resolved ../ to web root only; corrected to /var/www/html/secrets/flag.txt
- Apache restart (changed=1) is unconditional — by design, same as shellshock and sqli-login
- CyberRange repo: ~/wmg-dir-traversal-cyberrange/ (topology 10.1.30.0/24 + provisioning)
### Gaps
- None — verified working
