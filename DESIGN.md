## Task: suid-privesc game (2026-07-21)
Plan: SUID bash privilege escalation — COMPLETE, verify.sh PASS, idempotent
### Facts
- 5 working games: ssh-weak-password, shellshock, network-recon, ftp-anon, suid-privesc
- verify-all.sh passes 5/5 at 100%
- suid-privesc: copy of bash at /usr/local/bin/suid-shell with mode 04755 (root SUID)
- suid-privesc exploit: sshpass → SSH as trainee → run suid-shell -p -c "cat /root/flag.txt"
- CyberRange repo: ~/wmg-suid-privesc-cyberrange/ (topology + provisioning)
- Apache needs forced restart after CGI config (known issue)
- Kali has no internet during CyberRange provisioning
### Gaps
- Resume button on CyberRange training run not working (pre-existing)
- Student end-to-end run not yet completed on real platform (pre-existing)
