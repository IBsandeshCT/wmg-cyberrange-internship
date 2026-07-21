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
