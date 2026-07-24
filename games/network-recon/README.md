# network-recon — Network Reconnaissance and Service Enumeration

**Vulnerability:** Misconfigured service exposes flag via banner grab  
**Tools:** `nmap`, `nc`  
**Flag:** `WMG{r3c0n_1s_m0r3_th4n_just_p0rt_sc4nning}`

## Scenario

Three services run on different ports: FTP (decoy), HTTP (decoy), and a custom
banner service on port 8888 (the real lead). Students must enumerate all ports,
fingerprint services, and identify the non-standard service that yields the flag.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/network-recon/setup.yml
```

First run: `ok=15 changed=10 ignored=1` (ignored=1 is expected: pre-check confirms banner not yet running)  
Second run: `ok=13 changed=0 skipped=4`

## Verify

```bash
./agent-harness/verify.sh network-recon
```

## Expected exploit

```bash
nmap -sV -p 21,80,8888 127.0.0.1
# → 8888/tcp open  unknown (WMG-TELEMETRY-SVC)

echo | nc -w3 127.0.0.1 8888
# → WMG{r3c0n_1s_m0r3_th4n_just_p0rt_sc4nning}
```

## Training

`training.json` — 9 levels: port scan → service version detection → decoy identification → banner grab → flag → ASSESSMENT.  
MITRE ATT&CK: T1046 (Network Service Discovery), T1595.001 (Active Scanning: Scanning IP Blocks).  
Student-facing materials: see `briefing.md`, `hints.md`, `solution.md`.
