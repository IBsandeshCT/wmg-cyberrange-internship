# Game 1: SSH Weak Password Attack

## Scenario

The sysadmin of `cyberrange-target` was in a hurry when they provisioned a new
account for a summer intern named "student". Recon shows the machine exposes
SSH on port `2222`. Somewhere in your team's shared files is a common-password
wordlist that IT swears "nobody would actually use" — prove them wrong.

## Objective

Gain SSH access to the target as the `student` user and read the flag stored
in their home directory.

## Target

| Property | Value |
|---|---|
| Host | `127.0.0.1` (or the target's container name/IP if attacking from the shared Docker network) |
| Port | `2222` |
| Suspected service | SSH |

## Rules of Engagement

- Only attack the `cyberrange-target` container defined in this project's
  inventory. Do not scan or attack anything else on your network.
- This is a local, isolated training range — techniques here are for learning
  only and must not be used against systems you do not own or have explicit
  permission to test.

## What "done" looks like

You can SSH into the target as `student` and `cat` the contents of
`flag.txt` in their home directory.

If you get stuck, open `hints.md`. The full walkthrough is in `solution.md`
— try not to peek until you've made a real attempt.
