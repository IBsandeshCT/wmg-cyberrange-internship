# Game Design Reference

Distilled from `junior-hacker`, `skills/starting-point-for-game-design.md`, and the four
working WMG games. Read before designing any new game.

---

## Flag Format

```
WMG{descriptive_flag_here}
```

- Lowercase, underscores only inside the braces
- Descriptive: the flag should hint at the vulnerability (`WMG{ssh_w3ak_p4ssw0rds_are_never_ok}`)
- Leetspeak substitutions are common but not required
- The flag is the answer to the final TRAINING_LEVEL

---

## Level Progression Pattern

The canonical sequence (from `junior-hacker` and `starting-point-for-game-design.md`):

| order | type | purpose |
|-------|------|---------|
| 0 | INFO_LEVEL | Disclaimer + storyline intro. No answer. |
| 1 | ACCESS_LEVEL | Connect to attacker. Passkey = `"start"`. State IPs. |
| 2 | TRAINING_LEVEL | First recon step (easiest) |
| 3 | TRAINING_LEVEL | Mid step — exploit or discovery |
| 4 | TRAINING_LEVEL | Flag retrieval — hardest, highest score |
| 5 | ASSESSMENT_LEVEL | Questionnaire (not graded TEST) |

`max_score` should increase with each level: e.g. 10 → 15 → 20 → 20 → 20.
`estimated_duration` should be realistic: 0 for INFO/ACCESS, 3–10 min per TRAINING level.

Three TRAINING levels is the minimum. Add more for complex multi-step exploits.

---

## Chaining Answers Between Levels

The solution to level N should be **needed to complete** level N+1. This prevents skipping.
From `junior-hacker`'s INFO_LEVEL content:

> "The solution of a level **will be required** in the further levels. Do not try to skip ahead."

Examples:
- Level 2: trainee scans and finds open port → answer is the port number
- Level 3: trainee connects to that port using the result from level 2 → answer is the command used
- Level 4: trainee uses the credential found in level 3 to read the flag

Design so that without doing the previous step, the next step is impossible.

---

## Storytelling Style

From `junior-hacker` and the `starting-point-for-game-design.md` gold reference:

**Story first.** Every game needs a one-paragraph scenario that makes the vulnerability
feel real. The character, setting, and motivation matter.

- Use concrete characters and organisations ("Wobbly Widgets Ltd", "a crowded urban settlement")
- Give the trainee a role: "You are a junior hacker", "You are a security analyst"
- Make the goal clear and slightly dramatic: "steal anything valuable", "gain admin access"
- Keep it plausible — the scenario should feel like a real misconfiguration, not a CTF puzzle

**What content fields should contain:**
1. Story context paragraph (why you are doing this)
2. What the vulnerability is / what real systems do wrong
3. Clear exercise instructions ending with the exact question
4. "The flag is..." — always end with the explicit flag prompt

Example (from `junior-hacker` level 1):
> "You studied hard in the past weeks. Now, you are ready for real-world hacking training...
> The flag for this level is the command suffix (option) used for printing more information
> about some tool (there are two possibilities, submit the longer one)."

**ACCESS_LEVEL content:** State exact IPs (attacker and target), what services are running,
and remind trainees not to attack anything outside the sandbox.

---

## Hint Writing Rules

Hints are always objects (never plain strings):
```json
{ "title": "...", "content": "...", "hint_penalty": N, "order": 0 }
```

**Progressive structure:**
- Hint 0 (order 0): Direction only — "What tool to use?" — small penalty (1–5 points)
- Hint 1 (order 1): Syntax — "The command syntax is..." — medium penalty (5–10 points)
- Hint 2 (order 2): Near-complete answer — much higher penalty (10–20 points)

**Penalty constraint:** `sum(hint_penalty)` across all hints in one level ≤ `max_score`.

From `junior-hacker` level 3 (max_score: 20):
- Hint 0: "What connection method to use?" — penalty 5
- Hint 1: "What is the syntax for entering the SSH command?" — penalty 7
- Hint 2: "What password to use?" — penalty 4
- Total: 16 ≤ 20 ✓

---

## MITRE ATT&CK Technique Mapping

Add `mitre_techniques` to TRAINING_LEVEL entries where applicable:

```json
"mitre_techniques": [
  { "technique_key": "TA0007.T1046" }
]
```

Common mappings for our games:
| Game / step | Technique |
|-------------|-----------|
| Network scanning (nmap) | `TA0007.T1046` — Network Service Scanning |
| SSH brute force (hydra) | `TA0006.T1110` — Brute Force |
| Web exploitation (Shellshock) | `TA0002.T1059` — Command and Scripting Interpreter |
| Anonymous FTP access | `TA0009.T1083` — File and Directory Discovery |
| Banner grabbing / recon | `TA0007.T1046` — Network Service Scanning |

Format is always `TA<4-digit>.T<4-digit>`.

---

## Assessment Level Format

Use `"assessment_type": "QUESTIONNAIRE"` for end-of-game feedback (not graded `TEST`).

Standard structure: 4 MCQ opinion questions + 1 FFQ free text.

```json
{
  "title": "Feedback",
  "level_type": "ASSESSMENT_LEVEL",
  "order": 5,
  "estimated_duration": 5,
  "assessment_type": "QUESTIONNAIRE",
  "instructions": "Please answer the following questions.",
  "questions": [
    {
      "question_type": "MCQ",
      "text": "How difficult was this game?",
      "points": 0,
      "penalty": 0,
      "order": 0,
      "answer_required": true,
      "choices": [
        { "text": "Too easy",      "correct": true, "order": 0 },
        { "text": "About right",   "correct": true, "order": 1 },
        { "text": "Too difficult", "correct": true, "order": 2 }
      ]
    },
    {
      "question_type": "FFQ",
      "text": "What would you change or improve?",
      "points": 0,
      "penalty": 0,
      "order": 3,
      "answer_required": false,
      "choices": []
    }
  ]
}
```

For opinion MCQ questions all choices should be `"correct": true` since there is no wrong opinion.

---

## Solution Field Format

Solutions should show exact commands with expected output in a fenced code block:

```json
"solution": "```\nkali@attacker:~# nmap 10.1.27.10\n...\n2049/tcp open  nfs\n```\n\nThe flag is **WMG{flag_here}**."
```

Always `"solution_penalized": true` for TRAINING levels except the first (tutorial) level.

---

## Design Checklist

- [ ] One-paragraph story scenario
- [ ] Clear chain: step N result required for step N+1
- [ ] Trainee discovers rather than being told (IPs, ports, credentials where possible)
- [ ] INFO_LEVEL: disclaimer + storyline
- [ ] ACCESS_LEVEL: exact IPs, passkey = `"start"`
- [ ] TRAINING levels: progressive, max_score increases
- [ ] Hints: objects with title/content/penalty/order; sum ≤ max_score
- [ ] ASSESSMENT_LEVEL: questionnaire at end
- [ ] Flag is `WMG{descriptive_name}`, readable only after the exploit
- [ ] MITRE techniques mapped
- [ ] All string fields under 255 characters
- [ ] `"show_stepper_bar": true`, `"variant_sandboxes": false`
- [ ] `"state": "UNRELEASED"`
