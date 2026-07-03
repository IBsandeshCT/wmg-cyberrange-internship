# Game 3: Network Reconnaissance

## Scenario

You've been handed an IP address and nothing else — no service list, no
documentation. Your job is to figure out what's actually running on
`cyberrange-target` and use that information to find something you're not
supposed to see.

## Objective

Enumerate the open ports and services on the target, inspect each one, and
retrieve the flag from the correct service. Not every open port matters —
part of this exercise is telling real leads apart from decoys.

## Target

| Property | Value |
|---|---|
| Host | `cyberrange-target` (shared Docker network) or the container's published ports on `127.0.0.1` |

## Rules of Engagement

- Only scan/attack the `cyberrange-target` container defined in this
  project's inventory.
- This is a local, isolated training range — techniques here are for
  learning only and must not be used against systems you do not own or
  have explicit permission to test.

## What "done" looks like

You've identified all open services, ruled out the decoys, and connected
to the correct one to print the flag.

If you get stuck, open `hints.md`. The full walkthrough is in `solution.md`.
