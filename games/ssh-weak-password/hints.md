# Hints — Game 1: SSH Weak Password Attack

Work through these one at a time. Each hint gives away a little more.

## Hint 1

What port is SSH running on for this target? Confirm the service is up
before trying to authenticate against it:

```
nmap -p 2222 127.0.0.1
```

## Hint 2

The account you're after has a very ordinary-sounding username. Think about
who you were told just joined the team.

## Hint 3

You don't need to guess passwords one at a time — that's what tools like
`hydra` are for. It needs a username (or list of usernames), a wordlist of
candidate passwords, and a target service.

## Hint 4

A wordlist has already been placed on this range (see `files/wordlist.txt`
next to this game's playbook). It's a short list of some of the most common
passwords ever leaked in real breaches — the kind you'd find in any
"top 20 worst passwords" article.

## Hint 5

Hydra's SSH module syntax looks roughly like:

```
hydra -l <username> -P <wordlist> ssh://<target> -s <port>
```

Once you find the working password, SSH in normally and look around the
account's home directory.
