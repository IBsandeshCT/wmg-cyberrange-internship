# Hints — Game 3: Network Reconnaissance

Work through these one at a time.

## Hint 1

Start with a full port scan, not just the well-known ones. This target has
more than one open port, and at least one of them isn't on a "standard"
service port.

```
nmap -p- cyberrange-target
```

## Hint 2

Once you know which ports are open, use version/service detection to see
what's actually behind each one:

```
nmap -sV -p <ports> cyberrange-target
```

## Hint 3

Not every service you find is going to matter. Sysadmins leave things
lying around — decoys and dead ends are normal in real recon. Check each
service's actual content before assuming it's the way in.

## Hint 4

An anonymous FTP server and a website are both worth a quick look, but
think about which port doesn't fit the pattern of "normal" services. What
happens if you just connect to it with a raw TCP client, like `nc` or
`/dev/tcp`?

## Hint 5

```
nc cyberrange-target <the odd port>
```

Some services announce themselves the moment you connect — no request
needed.
