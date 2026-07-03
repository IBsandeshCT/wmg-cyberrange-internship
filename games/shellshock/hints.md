# Hints — Game 2: Shellshock

Work through these one at a time.

## Hint 1

Browse to `/cgi-bin/status.cgi` on the target normally first. What does it
tell you about how the server is set up? CGI scripts are executed by
whatever interpreter their shebang line points to.

## Hint 2

CGI is a very old standard: the web server takes parts of the incoming HTTP
request — headers like `User-Agent`, `Referer`, `Cookie` — and exposes them
to the CGI script as **environment variables**. If the interpreter that
processes those environment variables has a bug in how it parses them,
that's your way in.

## Hint 3

Shellshock (CVE-2014-6271) is a bug in `bash` where anything defined as an
environment variable in the exact form of a function definition — for
example a variable whose value looks like `() { :; };` — causes bash to
keep executing whatever text follows the `;` as a normal shell command,
even though it should have stopped after parsing the function.

## Hint 4

You can set arbitrary HTTP headers with `curl -H "Header: value"`. Try
setting the `User-Agent` header to a Shellshock payload and see what
happens when the CGI script runs.

## Hint 5

The payload shape is:

```
() { :; }; <your command here>
```

You'll want your command to print something (`echo`) and then read a file
that isn't part of the normal website content.
