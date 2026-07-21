## 2026-07-21 — sqli-v2 game
- Changed: added games/sqli-v2/ (setup.yml + files/search.php + training.json)
- Changed: added agent-harness/exploits/sqli-v2.exploit
- Changed: added ~/wmg-sqli-v2-cyberrange/ CyberRange deployment repo (topology 10.1.33.0/24)
- Outcome: verify.sh PASS on first attempt (15.5s), idempotent on second run (changed=1 = Apache restart, by design)
- Outcome: verify-all.sh 10/10 PASS, 100% success rate
- Design: UNION-based SQLi in a 2-column book-catalogue search (Athenaeum Library) — teaches column-counting (ORDER BY) + UNION SELECT extraction; fully distinct from sqli-login's boolean login bypass. Flag WMG{un10n_b4s3d_sql1_l34ks_th3_db} in librarian_notes table
- Dead ends: none — PHP+SQLite UNION approach worked first try; payload comment `-- -` (trailing dash) discards leftover `%'`

## 2026-07-21 — ssh-weak-v2 game
- Changed: added games/ssh-weak-v2/ (setup.yml + files/wordlist.txt + training.json)
- Changed: added agent-harness/exploits/ssh-weak-v2.exploit
- Changed: added ~/wmg-ssh-weak-v2-cyberrange/ CyberRange deployment repo (topology 10.1.32.0/24)
- Outcome: verify.sh PASS on first attempt (6.3s), idempotent on second run (changed=0)
- Outcome: verify-all.sh 9/9 PASS, 100% success rate
- Design: fresh maritime scenario (Halcyon Marine), user deckhand/Sailor2024, flag WMG{w3ak_ssh_cr3ds_s1nk_sh1ps}, custom maritime wordlist crew-passwords.txt — fully distinct from ssh-weak-password
- Dead end (caught before running): initial setup.yml had an sshd HUP/reload task — removed it; the proven ssh-weak-password game reloads nothing (PID-1 sshd trap), so matched that pattern

## 2026-07-21 — xss-stored game
- Changed: added games/xss-stored/ (setup.yml + files/ + training.json)
- Changed: added agent-harness/exploits/xss-stored.exploit
- Changed: added ~/wmg-xss-stored-cyberrange/ CyberRange deployment repo
- Outcome: verify.sh PASS on first attempt (16.1s), idempotent on second run (changed=3: Apache restart + data file resets, by design)
- Outcome: verify-all.sh 8/8 PASS, 100% success rate
- Design: stored XSS in PHP guestbook (unsanitised message output); bot.php simulates admin victim; collect.php simulates exfiltration endpoint
- Dead ends: none — PHP bot simulation approach worked immediately

## 2026-07-21 — dir-traversal game
- Changed: added games/dir-traversal/ (setup.yml + training.json)
- Changed: added agent-harness/exploits/dir-traversal.exploit
- Changed: added ~/wmg-dir-traversal-cyberrange/ CyberRange deployment repo
- Outcome: verify.sh PASS on first attempt (13.8s), idempotent on second run (changed=1 is Apache restart, by design)
- Outcome: verify-all.sh 7/7 PASS, 100% success rate
- Dead end (attempt 1): tried /etc/flag-dirtrav.txt but Apache normalizes ../ sequences within web root only — corrected to place flag at /var/www/html/secrets/flag.txt

## 2026-07-21 — sqli-login game
- Changed: added games/sqli-login/ (setup.yml + files/login.php + training.json)
- Changed: added agent-harness/exploits/sqli-login.exploit
- Changed: added ~/wmg-sqli-login-cyberrange/ CyberRange deployment repo
- Outcome: verify.sh PASS on first run (44.7s), idempotent on second run (changed=1 is Apache restart, by design)
- Outcome: verify-all.sh 6/6 PASS, 100% success rate
- Dead ends: none — PHP + SQLite approach worked on first attempt

## 2026-07-21 — suid-privesc game
- Changed: added games/suid-privesc/ (setup.yml + training.json)
- Changed: added agent-harness/exploits/suid-privesc.exploit
- Changed: added ~/wmg-suid-privesc-cyberrange/ CyberRange deployment repo
- Outcome: verify.sh PASS on first run (5.2s), idempotent on second run (changed=0)
- Outcome: verify-all.sh 5/5 PASS, 100% success rate
- Dead ends: none — bash SUID -p pattern worked immediately

## 2026-07-21 — skills files + CLAUDE.md rewrite
- Changed: skills/cyberrange-platform.md, skills/ansible-conventions.md, skills/game-design.md, skills/verification.md
- Changed: CLAUDE.md rewritten as lazy senior dev guide
- Outcome: all 4 skills files based on actual source material, no invented content

## 2026-07-17 — Week 2 complete
- Changed: all 4 games verified passing
- Changed: agent-harness/verify-all.sh built and working
- Outcome: 100% pass rate locally
- Dead ends: apt-get update on Kali fails (no internet) — never retry
- Dead ends: Apache CGI needs forced restart — add explicit restart task always
- Dead ends: Python 3.6 on Ubuntu 18.04 incompatible with Ansible 2.21 — use Ubuntu 20.04
