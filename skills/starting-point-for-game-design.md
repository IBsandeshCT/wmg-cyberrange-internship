# Starting Point for Game Design

This document describes **in detail** how the **st1-w3-enum-intro** game was built. Use it as the **gold reference** when creating new games: same structure, same design choices, and same file roles. The game lives at `game_builder/builder/st1-w3-enum-intro/`.

---

## 1. Purpose of This Document

- **Reference game:** `st1-w3-enum-intro` is the template for “how we create games.”
- **In-detail:** Everything that was done is documented here—topology, variables, playbook, training definition, README, presentation.
- **Use when:** Starting a new game; copying structure; checking conventions (hints, APG, level order, story).

---

## 2. Design Philosophy (What Makes This Game the Gold Example)

### 2.1 Narrative and pedagogy

- **Story first:** A simple, memorable scenario (e.g. “Wobbly Widgets Ltd”, forgotten staging server, Barry/Larry/Stuart) so the scenario is easy to recall and discuss.
- **Depth over breadth:** One chain (HTTP → Redis → rsync → takeover) so students see *how* one step leads to the next, not “many ports, shallow.”
- **No hand-holding:** Students do **not** get the target IP or ports; they must run a network scan (reusing last week’s skills) to discover the target and open ports.
- **Methodology in content:** Level text explains *why* we start at the web server, *why* we read errors/headers/source, *why* we enumerate each service on its own terms, and *why* correlation/chaining matters. The lab applies the method; the presentation (separate doc) teaches the method generically.

### 2.2 Technical and platform choices

- **Attacker + target + router:** Attacker (Kali) and target (server) on same network; router for connectivity. Target is **hidden** in the UI so students don’t see its name/IP until they discover it.
- **Single playbook target:** Only the **server** is provisioned; the attacker uses a pre-built image (e.g. kypo-kali-v2).
- **APG for final flag:** The last answer is a **variant** per sandbox (`root_flag`) so students can’t copy-paste one flag; it comes from `variables.yml` and is injected by the platform.
- **Training definition separate from sandbox:** Training definition lives in `game_builder/builder/traning-definitions/` (one JSON per training); the sandbox (topology + playbook + variables) lives in `game_builder/builder/<game-name>/`. They are linked when creating the training instance in the platform.

---

## 3. Directory Layout and File Roles

```
st1-w3-enum-intro/
├── topology.yml              # Sandbox: hosts, router, networks, IPs, flavors, volumes, hidden
├── variables.yml             # APG variables (e.g. root_flag) for variant answers
├── README.md                 # Game doc: story, levels, topology, services, steps, paths
├── PRESENTATION-10-SLIDES-NOTEBOOKLM.md   # Optional: slide outline for NotebookLM (methodology, not walkthrough)
└── provisioning/
    └── playbook.yml          # Ansible: single play for "server" host only
```

- **No** `training.json` inside the game dir: the training definition is in `game_builder/builder/traning-definitions/st1-w3-Enum-Intro-training-definition.json` and linked when creating the training instance.

---

## 4. Topology (`topology.yml`) — In Detail

### 4.1 What was done

| Element | Choice | Reason |
|--------|--------|--------|
| **Hosts** | `attacker`, `server` | Attacker = student machine (Kali); server = target to discover and compromise. |
| **Images** | `kypo-kali-v2`, `ubuntu-noble-x86_64` | Attacker has tools; server is generic Ubuntu for services. |
| **Flavors** | attacker: `c2.r4gb.d25gb.swap`, server: `c1.r2gb.d15gb.swap`, router: `c2.r4gb.d10gb.swap` | Attacker and router get more CPU/RAM; server lighter. |
| **Volumes** | attacker: 25 GB, server: 15 GB | Enough disk for tools and services. |
| **Hidden** | `attacker: false`, `server: true` | Target is hidden so students must scan to find it. |
| **Router** | `debian-12-x86_64`, same network | Connectivity; flavor can match or differ from hosts. |
| **Network** | `main-network`, `192.168.20.0/24` | Single subnet; students scan this range. |
| **IPs** | attacker 192.168.20.10, server 192.168.20.20, router 192.168.20.1 | Fixed for playbook and docs; students discover 192.168.20.20 via scan. |
| **groups** | `[]` | No host groups used. |

### 4.2 YAML structure (no extra keys)

- `name`, `hosts`, `routers`, `networks`, `net_mappings`, `router_mappings`, `groups`.
- Each host: `name`, `base_box` (`image`, `mgmt_user`), `flavor`, `volumes` (list of `size`), `hidden` (optional, default false).
- Routers: `name`, `base_box`, `flavor` (no volumes in this example).

---

## 5. Variables (`variables.yml`) — APG

### 5.1 What was done

- **Single APG variable:** `root_flag` for the final takeover level.
- **Type:** `password` (flag-style random characters). Alternative is `type: text` for longer random text.
- **Options:** `length: 12` (or 36 for longer flags). Omitted length uses platform default.
- **Comments:** In-file comment documents that `type: text` is for longer text and `type: password` for flag-style, with optional `length`.

### 5.2 Platform behaviour

- Platform injects `root_flag` into the sandbox context; the playbook uses `{{ root_flag | default('WMG{local-test-flag}') }}` so local/test runs work without the platform.
- Training definition sets `variant_sandboxes: true` and the takeover level uses `answer_variable_name: "root_flag"` (no fixed `answer`).

---

## 6. Provisioning (`provisioning/playbook.yml`) — In Detail

### 6.1 Structure

- **Single play:** `hosts: server` only. Attacker is not modified (pre-built image).
- **Order of setup:** (1) apt cache, (2) Nginx + custom page + headers, (3) Redis (bind, protected-mode, key), (4) rsync daemon (config, secrets, module dir, files), (5) sysadmin user + sudoers, (6) root flag file, (7) SSH password auth. Handlers: restart sshd.

### 6.2 Service-by-service choices

| Service | Purpose in game | Implementation notes |
|---------|-----------------|----------------------|
| **Nginx (80)** | First clue: REDIS error, headers, HTML comment with rsync hint. | Custom `index.html` with comment `<!-- Devs: remember to rsync website to latest version before testing -->`. `add_header` in default site for `X-Cache: Redis` and `X-Cache-Backend: Redis`. |
| **Redis (6379)** | No auth; key `user:lazydev` = password for rsync. | `bind 0.0.0.0`, `protected-mode no`. One key set via `redis-cli SET user:lazydev "{{ lazydev_password }}"`. |
| **rsync (873)** | Module `website`; auth `lazydev`/password from Redis; file `sysadmin.txt` with sysadmin password. | `rsyncd.conf` with module `[website]`, `auth users = lazydev`, `secrets file = /etc/rsync.secrets`. Content: `index.html` + `sysadmin.txt` with `sysadmin:supersecret123`. |
| **sysadmin** | SSH login and sudo to root. | User with hashed password, in `sudo` group; `/etc/sudoers.d/sysadmin` with `NOPASSWD: ALL`. **Validate:** `validate: "visudo -cf %s"` on the copy task. |
| **Root flag** | APG value in `/root/flag.txt`. | `content: "{{ root_flag | default('WMG{local-test-flag}') }}\n"`. |
| **SSH (22)** | Password auth for sysadmin. | `PasswordAuthentication yes` in `sshd_config`; handler to restart sshd. |

### 6.3 Ansible / YAML gotchas encountered

- **Task names:** Avoid unquoted colons in task names (e.g. “Set user:lazydev in Redis” can be parsed as key-value). Use simpler names like “Set lazydev password in Redis.”
- **sudoers file:** Use `validate: "visudo -cf %s"` on the task that copies the sudoers snippet; ensure correct indentation (validate under the `copy` module).
- **Handlers:** Define handler (e.g. “Restart sshd”) and use `notify: Restart sshd` on the task that changes sshd_config; handler uses `listen: Restart sshd` if you want a single handler for multiple notifiers.

### 6.4 Variables in playbook

- Play-level `vars`: e.g. `lazydev_password: "dev123"`, `rsync_module_path: "/srv/rsync/website"`. Platform-injected `root_flag` is used in the flag task with a default for local runs.

---

## 7. Training Definition — In Detail

**Path:** `game_builder/builder/traning-definitions/st1-w3-Enum-Intro-training-definition.json`

### 7.1 Top-level fields

- **title**, **description:** Match the game and story (enumeration intro, forgotten staging server, depth over breadth).
- **state:** `UNRELEASED` until ready for production.
- **show_stepper_bar:** `true`.
- **variant_sandboxes:** `true` (required for APG; final level uses `answer_variable_name`).
- **estimated_duration:** e.g. 90 (minutes).
- **prerequisites**, **outcomes:** Arrays (can be empty).

### 7.2 Level sequence (order and types)

| order | title | level_type | Purpose |
|-------|--------|------------|---------|
| 0 | Introduction | INFO_LEVEL | Story + instructions (network scan to find target; no IP/ports given). |
| 1 | Get access | ACCESS_LEVEL | Passkey **start**; student connects and submits to unlock next. |
| 2 | Web server clue | TRAINING_LEVEL | Identify cache backend from HTTP (answer: **redis**). |
| 3 | Redis – users | TRAINING_LEVEL | Get lazydev password from Redis (answer: **dev123**). |
| 4 | rsync – website content | TRAINING_LEVEL | Get sysadmin password from rsync module (answer: **supersecret123**). |
| 5 | Takeover | TRAINING_LEVEL | SSH + sudo, read flag (answer: **root_flag** via APG). |
| 6 | Feedback | ASSESSMENT_LEVEL | Questionnaire (difficulty, pace, preferences, free text). |

### 7.3 Level content structure (TRAINING_LEVEL)

- **Why we do this:** Short “why” (e.g. why start at web server, why Redis matters, why rsync).
- **What happens in real setups:** One short paragraph on real-world misconfigurations.
- **Research / methodology:** Where useful (e.g. Redis: “look up how to list keys”).
- **Exercise:** Clear task and **exact question** (e.g. “What is the name of the cache backend (one word)?”).
- **Answers:** Lowercase where applicable (`redis`, `dev123`, `supersecret123`); last level uses `answer_variable_name: "root_flag"`, `answer: null`.

### 7.4 Hints

- **Format:** Array of objects: `{ "title": "...", "content": "...", "hint_penalty": 1, "order": 0 }`. **Not** plain strings—the platform expects objects; plain strings can cause import errors (e.g. HintImportDTO).
- **Order:** Use `order` so hints appear in a sensible sequence (e.g. “List keys” before “Read a value”).
- **Penalty:** Non-zero `hint_penalty` if the platform uses it for scoring.

### 7.5 ACCESS_LEVEL

- **passkey:** e.g. `"start"`.
- **cloud_content** / **local_content:** Short instruction (“Connect to your sandbox and submit **start** to begin.”).

### 7.6 ASSESSMENT_LEVEL (questionnaire)

- **assessment_type:** `"QUESTIONNAIRE"`.
- **instructions:** One line (“Give us some feedback…”).
- **questions:** Array of objects. Each question: `question_type` (e.g. `MCQ`, `FFQ`), `text`, `points`, `penalty`, `order`, `answer_required`, `choices` (for MCQ: `text`, `correct`, `order`). All choices can be `correct: true` for opinion questions.

### 7.7 Other level fields (typical)

- **estimated_duration**, **minimal_possible_solve_time** per level (or null).
- **solution:** `"The answer is **${ANSWER}**."` (or “unique per sandbox” for APG).
- **solution_penalized:** true.
- **incorrect_answer_limit**, **max_score**, **variant_answers** (true only for APG level), **commands_required**, **expected_commands**, **reference_solution**, **mitre_techniques**, **attachments** as needed.

---

## 8. README (`README.md`) — In Detail

### 8.1 Sections (in order)

1. **Title and one-line summary** — Game name, one sentence (e.g. intro session, depth over breadth, chained story).
2. **Story** — One short paragraph (e.g. Wobbly Widgets, Barry/Larry/Stuart, forgotten server).
3. **Game levels summary** — Table: Order, Level, Type, Summary (what student does and what they submit).
4. **Topology summary** — Table: Host, Image, Flavor, Volumes, IP, Hidden; plus a line on flavors and network.
5. **Services on server** — Bullet list: per service (port), what is configured and what the student sees or uses.
6. **APG (variant answers)** — How `variables.yml` and training definition are set (e.g. `root_flag`, `variant_sandboxes`, `answer_variable_name`).
7. **Steps to complete the game** — Numbered list: connect & start, scan, web, Redis, rsync, takeover, feedback. Concrete enough to follow (e.g. “submit **start**”, “nmap 192.168.20.0/24”, “submit **redis**”, “rsync --list-only rsync://lazydev@<target>/website/”, “sudo cat /root/flag.txt”).
8. **Training definition** — Path to the JSON and note to link sandbox definition to that training when creating the instance.
9. **Presentation (NotebookLM)** — Path to `PRESENTATION-10-SLIDES-NOTEBOOKLM.md` and one line on purpose.
10. **License** — Same as project (or your choice).

This gives future authors and instructors a single place to see story, levels, topology, services, and exact steps.

---

## 9. Presentation Outline (`PRESENTATION-10-SLIDES-NOTEBOOKLM.md`)

- **Purpose:** Input for NotebookLM to generate slides. **Generic** service enumeration methodology, not a copy of the game steps.
- **Structure per slide:** Overview, Graphic needed, Narrative.
- **Content:** Scenario (e.g. forgotten staging server) as hook; rest is methodology: why discovery first, why start at “first thing that talks to the internet”, why read errors/headers/source, why enumerate each service on its own terms, why correlate/chaining, why “no exploit” still leads to compromise, takeaways (reusable method).
- **No game answers** in the slide text (no redis, dev123, website, supersecret123, flag). The lab is where students *apply* the method; the deck teaches the method.

---

## 10. Checklist — When Creating a New Game

Use this to avoid missing pieces.

### 10.1 Design

- [ ] Story or scenario (one short paragraph).
- [ ] Clear chain or sequence (what leads to what).
- [ ] Decide: do students discover target/ports (e.g. scan) or get them? Prefer discovery where it fits the learning goal.
- [ ] Decide: one final APG answer (e.g. flag)? If yes, plan `variables.yml` and `answer_variable_name`.

### 10.2 Sandbox (game directory)

- [ ] `topology.yml`: hosts, router, networks, IPs, flavors, volumes, `hidden` where needed.
- [ ] `variables.yml`: APG variables and types (e.g. `password`, `length`); comment options.
- [ ] `provisioning/playbook.yml`: single or multiple plays; order of services; handlers; validate sudoers if used; no colons in task names that break YAML.
- [ ] Test playbook locally (e.g. default APG value).

### 10.3 Training definition

- [ ] JSON in `game_builder/builder/traning-definitions/<Name>-training-definition.json`.
- [ ] Levels: INFO (intro) → ACCESS (passkey) → TRAINING (… ) → TRAINING (final) → ASSESSMENT (questionnaire).
- [ ] Hints as objects `{ title, content, hint_penalty, order }`, not plain strings.
- [ ] Answers lowercase where applicable; last level `answer_variable_name` and `variant_sandboxes: true` if APG.
- [ ] Content: “Why”, “What happens in real setups”, “Exercise” + exact question.

### 10.4 Documentation

- [ ] README: story, levels table, topology table, services, APG, steps to complete, path to training definition, optional presentation path.
- [ ] Optional: presentation outline (methodology-focused, for NotebookLM or similar).

### 10.5 Platform

- [ ] Create sandbox definition from topology + playbook + variables.
- [ ] Create training definition in platform (import JSON).
- [ ] Create training instance; link to sandbox pool so variant_sandboxes/APG work.

---

## 11. Reference File Locations

| What | Where |
|------|--------|
| Gold game root | `game_builder/builder/st1-w3-enum-intro/` |
| Topology | `game_builder/builder/st1-w3-enum-intro/topology.yml` |
| Variables | `game_builder/builder/st1-w3-enum-intro/variables.yml` |
| Playbook | `game_builder/builder/st1-w3-enum-intro/provisioning/playbook.yml` |
| Training definition | `game_builder/builder/traning-definitions/st1-w3-Enum-Intro-training-definition.json` |
| README | `game_builder/builder/st1-w3-enum-intro/README.md` |
| Presentation outline | `game_builder/builder/st1-w3-enum-intro/PRESENTATION-10-SLIDES-NOTEBOOKLM.md` |

---

## 12. Related Rules

- **Sandbox:** [sandbox-topology.md](sandbox-topology.md), [sandbox-provisioning.md](sandbox-provisioning.md)
- **Training:** [training-linear.md](training-linear.md), [training-levels.md](training-levels.md), [training-apg.md](training-apg.md)
- **Master overview:** [master-quick-reference.md](master-quick-reference.md) — quick decision tree and complete game structure; this document is the **detailed** starting point using st1-w3-enum-intro as the reference.
