# Game 2: Shellshock Vulnerability (CVE-2014-6271)

## Scenario

`cyberrange-target` is running a web server with a small internal "status"
page implemented as a CGI script — the kind of legacy glue script that gets
written once and never looked at again. In 2014, a bug in `bash`'s handling
of function definitions passed through environment variables (nicknamed
"Shellshock") let attackers turn exactly this kind of script into arbitrary
remote code execution. Nobody ever went back and checked if this particular
script's bash was ever patched.

## Objective

Use the Shellshock vulnerability (CVE-2014-6271) to execute an arbitrary
command on the target through its CGI script, and use that to read a flag
file that lives outside the normal web root.

## Target

| Property | Value |
|---|---|
| Service | Apache HTTP Server |
| Path | `/cgi-bin/status.cgi` |

## Rules of Engagement

- Only attack the `cyberrange-target` container defined in this project's
  inventory.
- This is a local, isolated training range — techniques here are for
  learning only and must not be used against systems you do not own or
  have explicit permission to test.

## What "done" looks like

You can make an HTTP request to `status.cgi` that causes the server to run
a command of your choosing, and use that to print the contents of the flag
file to your terminal.

If you get stuck, open `hints.md`. The full walkthrough is in `solution.md`.
