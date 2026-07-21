## 2026-07-17 — Week 2 complete
- Changed: all 4 games verified passing
- Changed: agent-harness/verify-all.sh built and working
- Outcome: 100% pass rate locally
- Dead ends: apt-get update on Kali fails (no internet) — never retry
- Dead ends: Apache CGI needs forced restart — add explicit restart task always
- Dead ends: Python 3.6 on Ubuntu 18.04 incompatible with Ansible 2.21 — use Ubuntu 20.04
