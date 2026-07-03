# Solution — Game 3: Network Reconnaissance

## 1. Full port scan

Don't rely on nmap's default top-1000 ports alone — scan everything:

```bash
nmap -p- cyberrange-target
```

Expected open ports: `21` (FTP), `80` (HTTP), `8888` (unknown).

## 2. Service/version detection

```bash
nmap -sV -p 21,80,8888 cyberrange-target
```

Expected:

```
PORT     STATE SERVICE VERSION
21/tcp   open  ftp     vsftpd 3.0.5
80/tcp   open  http    Apache httpd 2.4.52 ((Ubuntu))
8888/tcp open  sun-answerbook? (unrecognized — but nmap's fingerprint dump shows readable banner text)
```

Nmap's version probe on port 8888 usually captures the banner text directly
in its "unrecognized service" fingerprint dump — a strong hint on its own.

## 3. Check each service

**FTP (port 21) — decoy:**

```bash
curl -s ftp://cyberrange-target/readme.txt
```
Returns a generic "nothing sensitive here" note. Dead end.

**HTTP (port 80) — decoy:**

```bash
curl -s http://cyberrange-target/
```
Returns a placeholder "under construction" page. Dead end.

**Port 8888 — the actual target:**

```bash
nc cyberrange-target 8888
```

or, without `nc`, using bash's built-in `/dev/tcp`:

```bash
exec 3<>/dev/tcp/cyberrange-target/8888
cat <&3
```

Expected output:

```
==============================================
 WMG-TELEMETRY-SVC build 2019.03 (internal use)
==============================================
WMG{r3c0n_1s_m0r3_th4n_just_p0rt_sc4nning}
```

The service prints its banner (including the flag) immediately on connect
— no request or authentication needed, which is exactly why it stands out
as unusual once you've ruled out the two normal-looking services.

## Why this works (root cause)

- A real-world network rarely has a single obviously-vulnerable open port —
  attackers have to sift through multiple exposed services, most of which
  are legitimate and boring, to find the one that matters.
- Port 8888 runs an ad-hoc internal tool ("WMG-TELEMETRY-SVC") that was
  clearly never meant to be exposed and provides no authentication at all
  before handing over internal-looking data.
- Full-range port scanning (`-p-`) matters: a scan limited to nmap's default
  top ports would still catch 21/80 but could plausibly miss an unusual
  high port depending on the profile used.

## Remediation

- Don't expose internal tooling/telemetry endpoints without authentication,
  regardless of how "obscure" the port number is — security through
  obscurity is not a control.
- Run periodic external port scans against your own infrastructure to catch
  services that shouldn't be reachable.
- Apply the principle of least exposure: only open the ports a service
  actually needs to be reachable on, from a firewall/security-group level.
