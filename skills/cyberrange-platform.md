# CyberRangeCZ Platform Reference

Distilled from `skills/sandbox-topology.md`, `skills/training-linear.md`,
`skills/training-levels.md`, `skills/starting-point-for-game-design.md`, and the
`junior-hacker` reference game. Read this before authoring any topology or training artifact.

---

## How the Platform Works

CyberRangeCZ (KYPO) runs on OpenStack at `cr.cyber.warwick.ac.uk`.

Two separate artifacts form a game:

1. **Sandbox Definition** — a Git repo with `topology.yml` + `provisioning/` (and optionally
   `variables.yml` for APG). Deployed as a **sandbox pool**: the platform pre-provisions N
   identical sandboxes so each trainee gets their own.

2. **Training Definition** — `training.json` uploaded manually via the portal UI. Describes
   levels, questions, hints, and scoring. Linked to the sandbox pool when creating a
   **training instance**.

The training instance is what trainees access. The sandbox pool provides the live machines.
They are linked — not bundled — so they can be updated independently.

---

## topology.yml Structure

### Top-level keys (all required)

```yaml
name: wmg-gamename-sandbox    # a-z start, [a-zA-Z0-9-] only, platform-unique
hosts: []
routers: []
wan: {}
networks: []
net_mappings: []
router_mappings: []
groups: []
```

### name rules
- First character: lowercase letter
- Allowed: `a-z`, `A-Z`, `0-9`, `-`
- Must be unique across the entire platform

### hosts entry
```yaml
- name: attacker
  base_box:
    image: kypo-kali-v2
    mgmt_user: kali          # must match the box: kali for Kali, debian/ubuntu for targets
  flavor: c2.r4gb.d25gb.swap
  volumes:
    - size: 25               # GB; first volume = system drive
  hidden: false              # optional; true hides from topology view
```

**Known working images and their mgmt_user:**
| Image | mgmt_user |
|-------|-----------|
| `kypo-kali-v2` | `kali` |
| `debian-12-x86_64` | `debian` |
| `ubuntu-noble-x86_64` | `ubuntu` |
| `ub18.04.01x86` | `ubuntu` |

**Note:** `ub18.04.01x86` (Ubuntu 18.04) is used in `junior-hacker` but has Python 3.6,
which is incompatible with Ansible 2.21. Use `ubuntu-noble-x86_64` or `debian-12-x86_64`
for new games.

### routers entry
```yaml
- name: router
  base_box:
    image: debian-12-x86_64
    mgmt_user: debian
  flavor: c1.r2gb.d10gb
```
Routers connect automatically to the WAN network. No volumes needed unless the image requires it.

### wan
```yaml
wan:
  name: internet-connection
  cidr: 100.100.100.0/24    # default; must not overlap any other network
```

### networks
```yaml
networks:
  - name: wmg-switch
    cidr: 10.1.27.0/24
    accessible_by_user: true    # default; false = trainees cannot reach hosts on this network
    hidden: false               # optional
```
All CIDRs (including WAN) must be disjunct (non-overlapping).

### net_mappings
```yaml
net_mappings:
  - host: attacker
    network: wmg-switch
    ip: 10.1.27.23
  - host: server
    network: wmg-switch
    ip: 10.1.27.10
```
- `.1` = router gateway (reserved)
- `.2` = DHCP (reserved)
- Hosts use `.3` onwards
- Keep host IPs stable — `training.json` content hardcodes them in prose

### router_mappings
```yaml
router_mappings:
  - router: router
    network: wmg-switch
    ip: 10.1.27.1
```

### groups
```yaml
groups: []    # usually empty; only define if you need custom Ansible groups
```

### Complete working example (from `~/wmg-ssh-cyberrange`)
```yaml
name: wmg-ssh-weak-password-sandbox
hosts:
  - name: attacker
    base_box: { image: kypo-kali-v2, mgmt_user: kali }
    flavor: c2.r4gb.d25gb.swap
    volumes: [ { size: 25 } ]
  - name: server
    base_box: { image: debian-12-x86_64, mgmt_user: debian }
    flavor: c1.r2gb.d10gb
    volumes: [ { size: 10 } ]
routers:
  - name: router
    base_box: { image: debian-12-x86_64, mgmt_user: debian }
    flavor: c1.r2gb.d10gb
wan:      { name: internet-connection, cidr: 100.100.100.0/24 }
networks: [ { name: wmg-switch, cidr: 10.1.27.0/24 } ]
net_mappings:
  - { host: attacker, network: wmg-switch, ip: 10.1.27.23 }
  - { host: server,   network: wmg-switch, ip: 10.1.27.10 }
router_mappings:
  - { router: router, network: wmg-switch, ip: 10.1.27.1 }
groups: []
```

---

## training.json Structure

### Top-level required fields
```json
{
  "title": "WMG Game Title",
  "description": "One sentence description.",
  "prerequisites": [],
  "outcomes": ["Learning objective."],
  "state": "UNRELEASED",
  "show_stepper_bar": true,
  "variant_sandboxes": false,
  "estimated_duration": 45,
  "levels": []
}
```

**Always:** `"show_stepper_bar": true`, `"variant_sandboxes": false` (unless using APG).
**Always:** `"state": "UNRELEASED"` — never upload as RELEASED.

### Level types

Levels are in a `levels` array. `order` starts at 0 with no gaps.

#### INFO_LEVEL (order 0)
```json
{
  "title": "Introduction",
  "level_type": "INFO_LEVEL",
  "order": 0,
  "estimated_duration": 0,
  "content": "# General information\n\nMarkdown content here."
}
```
No answer required. Used for disclaimer and storyline intro.

#### ACCESS_LEVEL (order 1)
```json
{
  "title": "Get Access",
  "level_type": "ACCESS_LEVEL",
  "order": 1,
  "estimated_duration": 0,
  "passkey": "start",
  "cloud_content": "SSH to your attacker: ...",
  "local_content": "Local instructions..."
}
```
Trainee submits the `passkey` to unlock. State the attacker and target IPs here.

#### TRAINING_LEVEL (orders 2+)
```json
{
  "title": "Find the flag",
  "level_type": "TRAINING_LEVEL",
  "order": 2,
  "estimated_duration": 10,
  "answer": "WMG{the_flag_here}",
  "answer_variable_name": null,
  "content": "Task description ending with the explicit question and 'The flag is ...'",
  "solution": "```\nexact commands and output\n```",
  "solution_penalized": true,
  "hints": [
    { "title": "First hint", "content": "Hint text.", "hint_penalty": 10, "order": 0 },
    { "title": "Second hint", "content": "More specific hint.", "hint_penalty": 20, "order": 1 }
  ],
  "incorrect_answer_limit": 10,
  "attachments": [],
  "max_score": 50
}
```

#### ASSESSMENT_LEVEL (final level)
```json
{
  "title": "Knowledge Check",
  "level_type": "ASSESSMENT_LEVEL",
  "order": 6,
  "estimated_duration": 5,
  "assessment_type": "QUESTIONNAIRE",
  "instructions": "Answer the questions below.",
  "questions": []
}
```

---

## Hint Rules

Hints are **objects**, never plain strings. Plain strings cause `HintImportDTO` errors on import.

```json
{ "title": "string", "content": "markdown string", "hint_penalty": 10, "order": 0 }
```

**Critical constraint:** The sum of all `hint_penalty` values in one level must not exceed
that level's `max_score`. If `max_score` is 50, hints can total at most 50 penalty points.

---

## String Length Limit

All string fields in `training.json` must be **under 255 characters**. This applies to
`title`, `answer`, `passkey`, and question `text` fields. Long Markdown content in `content`
and `solution` fields is not subject to this limit — only the scalar string fields.

---

## Question Types (ASSESSMENT_LEVEL)

### MCQ
```json
{
  "question_type": "MCQ",
  "text": "What does nmap do?",
  "points": 100,
  "penalty": 0,
  "order": 0,
  "answer_required": true,
  "choices": [
    { "text": "Network scanner", "correct": true,  "order": 0 },
    { "text": "Password cracker", "correct": false, "order": 1 },
    { "text": "File archiver",   "correct": false, "order": 2 },
    { "text": "Web server",      "correct": false, "order": 3 }
  ]
}
```

### FFQ (free-form)
```json
{
  "question_type": "FFQ",
  "text": "What did you find most difficult?",
  "points": 0,
  "penalty": 0,
  "order": 4,
  "answer_required": false,
  "choices": []
}
```

---

## APG (Automatic Problem Generation)

When `variant_sandboxes: true`, the platform generates unique flags per sandbox from
`variables.yml` in the sandbox repo root:

```yaml
root_flag:
  type: password
  length: 12
```

In provisioning, reference it with a default for local testing:
```yaml
content: "{{ root_flag | default('WMG{local-test-flag}') }}\n"
```

In `training.json`, the APG level uses:
```json
{
  "answer": null,
  "answer_variable_name": "root_flag",
  "variant_answers": true
}
```

Use `${ANSWER}` in `solution` text for variable substitution.

---

## Sandbox Pools and Training Instances

1. **Sandbox Definition** (Git repo) → imported into the platform to create a **sandbox pool**.
   The pool pre-provisions N sandboxes with Ansible.

2. **Training Definition** (`training.json`) → imported into the platform to create a
   **training definition**.

3. **Training Instance** → created in the portal, linking one training definition to one
   sandbox pool. This is what trainees access at their assigned URL.

The sandbox and training are separate — update one without changing the other.
