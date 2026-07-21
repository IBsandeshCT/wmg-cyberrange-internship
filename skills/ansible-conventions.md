# Ansible Conventions for CyberRange Games

Patterns taken directly from the four working games in `games/`. Copy verbatim rather than
inventing new approaches. Second run must always be `changed=0 failed=0`.

---

## Module Rule

Always use fully-qualified `ansible.builtin.*` module names. Never use bare names like `apt`,
`copy`, `template` — they work but are ambiguous and may resolve differently in future.

```yaml
ansible.builtin.apt:
ansible.builtin.copy:
ansible.builtin.template:
ansible.builtin.lineinfile:
ansible.builtin.file:
ansible.builtin.user:
ansible.builtin.shell:
ansible.builtin.command:
ansible.builtin.service:
ansible.builtin.wait_for:
ansible.builtin.get_url:
ansible.builtin.unarchive:
```

---

## Kali Attacker Role: Ping Only

Kali has **no internet during CyberRange provisioning**. Never run `apt-get` in attacker
provisioning. All tools (nmap, hydra, curl, netcat, sshpass, ftp, sqlmap, nikto, gobuster,
john, hashcat, fcrackzip) are pre-installed on the `kypo-kali-v2` image.

The attacker playbook play is typically empty or just a ping:
```yaml
- name: Attacker (no provisioning needed)
  hosts: attacker
  gather_facts: false
  tasks: []
```

Only the **server** play does real work.

---

## Target Server: Has Internet

Debian 12 / Ubuntu 22.04 target boxes have internet during provisioning.
Use `ansible.builtin.apt` freely, always with `update_cache: yes` on the first apt task per play.

```yaml
- name: Install packages
  ansible.builtin.apt:
    name:
      - vsftpd
      - apache2
      - build-essential
    state: present
    update_cache: yes
```

---

## Idempotency Patterns

### Setting a user password
**Do not** use `password_hash` with a random salt — it generates a new hash on every run.

Option A — `chpasswd` with `changed_when: false` (used in `ssh-weak-password`):
```yaml
- name: Set student's password
  ansible.builtin.shell: "echo '{{ student_user }}:{{ student_password }}' | chpasswd"
  changed_when: false
```

Option B — `password_hash` with a **fixed salt** in vars:
```yaml
vars:
  student_password_salt: wmgsshsalt01234   # fixed, never random
  student_password_hash: "{{ 'password123' | password_hash('sha512', student_password_salt) }}"
```

### Compile steps: `creates:` guard
The `creates:` key skips the task if the file already exists. Point it at the **actual output
file**, not the source:

```yaml
- name: Extract bash source
  ansible.builtin.unarchive:
    src: /usr/src/bash-4.3.tar.gz
    dest: /usr/src
    remote_src: yes
    creates: /usr/src/bash-4.3/configure   # the extracted dir, not the tarball

- name: Configure bash build
  ansible.builtin.command: ./configure
  args:
    chdir: /usr/src/bash-4.3
    creates: /usr/src/bash-4.3/Makefile    # configure produces Makefile

- name: Compile bash
  ansible.builtin.command: make
  args:
    chdir: /usr/src/bash-4.3
    creates: /usr/src/bash-4.3/bash        # make produces the binary
```

**Pitfall for `a2enmod cgi`:** Ubuntu's threaded MPM substitutes `mod_cgid` for `mod_cgi`,
so the created file is `cgid.load`, not `cgi.load`:
```yaml
- name: Enable Apache CGI module
  ansible.builtin.command: a2enmod cgi
  args:
    creates: /etc/apache2/mods-enabled/cgid.load   # NOT cgi.load
```

### File and directory creation
```yaml
- name: Ensure runtime dir exists
  ansible.builtin.file:
    path: /var/run/vsftpd/empty
    state: directory
    owner: root
    group: root
    mode: '0755'
```
`state: directory` is idempotent — does nothing if it already exists.

### Planting flags
```yaml
- name: Plant the flag
  ansible.builtin.copy:
    content: "{{ flag_content }}\n"
    dest: /opt/flag.txt
    owner: root
    group: root
    mode: '0644'
```
Using `content:` directly is idempotent — Ansible compares the hash and only changes when
the content differs.

---

## Apache CGI Restart: The Known Issue

Apache must be **force-restarted** after enabling CGI modules, not just started for the first
time. Without the restart, the CGI module is loaded in config but the running process still
serves requests without CGI support.

The pattern that works (from `games/shellshock/setup.yml`):
```yaml
- name: Enable Apache CGI module
  ansible.builtin.command: a2enmod cgi
  args:
    creates: /etc/apache2/mods-enabled/cgid.load

- name: Enable serve-cgi-bin configuration
  ansible.builtin.command: a2enconf serve-cgi-bin
  args:
    creates: /etc/apache2/conf-enabled/serve-cgi-bin.conf

- name: Check whether Apache is already running
  ansible.builtin.command: pgrep -x apache2
  register: apache_running
  changed_when: false
  failed_when: false

- name: Start Apache (first run only)
  ansible.builtin.command: apache2ctl start
  when: apache_running.rc != 0

- name: Restart Apache to apply CGI configuration
  ansible.builtin.service:
    name: apache2
    state: restarted
```

The final `restarted` task runs every time (no `when:` guard). This is intentional — it is
idempotent in terms of outcome (Apache ends up running the new config) even though it
generates a `changed` on each run.

**Never restart sshd** where `sshd -D` is PID 1. It kills the container.

---

## vsftpd on Init-less Containers

`systemd-tmpfiles` is not available in Docker containers without systemd. vsftpd needs
`/var/run/vsftpd/empty` — create it explicitly or every FTP session fails silently.

vsftpd does not self-daemonize when launched manually, so use `async + poll: 0`:

```yaml
- name: Ensure vsftpd chroot jail directory exists
  ansible.builtin.file:
    path: /var/run/vsftpd/empty
    state: directory
    owner: root
    group: root
    mode: '0755'

- name: Check whether vsftpd is already running
  ansible.builtin.command: pgrep -x vsftpd
  register: vsftpd_running
  changed_when: false
  failed_when: false

- name: Stop vsftpd (config changed)
  ansible.builtin.command: pkill -x vsftpd
  when: vsftpd_conf.changed and vsftpd_running.rc == 0
  changed_when: true

- name: Start vsftpd (fire-and-forget)
  ansible.builtin.command: vsftpd /etc/vsftpd.conf
  async: 86400
  poll: 0
  when: vsftpd_running.rc != 0 or vsftpd_conf.changed
  changed_when: true

- name: Wait for FTP port
  ansible.builtin.wait_for:
    port: 21
    host: 127.0.0.1
    timeout: 15
```

Same pattern applies to any foreground daemon (custom Python banner services, etc.).

---

## Custom Foreground Service (Python)

From `games/network-recon/setup.yml`:
```yaml
- name: Check whether banner service is listening
  ansible.builtin.wait_for:
    port: "{{ banner_port }}"
    timeout: 1
  register: banner_check
  ignore_errors: true

- name: Launch banner service in background
  ansible.builtin.command: python3 /opt/banner_service.py
  async: 86400
  poll: 0
  when: banner_check is failed
```

---

## vars/main.yml Pattern

Declare all secrets, ports, and flag content in a `vars:` block at the top of the play
(for local `setup.yml`) or in `roles/<host>/vars/main.yml` (for CyberRange provisioning):

```yaml
vars:
  student_user: student
  student_password: password123
  flag_content: "WMG{ssh_w3ak_p4ssw0rds_are_never_ok}"
  ftp_root: /var/ftp
  banner_port: 8888
```

For CyberRange APG with a default for local testing:
```yaml
vars:
  flag_content: "{{ root_flag | default('WMG{local-test-flag}') }}"
```

---

## sudoers Files

Always validate:
```yaml
- name: Deploy sudoers snippet
  ansible.builtin.copy:
    content: "sysadmin ALL=(ALL) NOPASSWD: ALL\n"
    dest: /etc/sudoers.d/sysadmin
    mode: '0440'
    validate: "visudo -cf %s"
```

---

## YAML Pitfalls

**Unquoted colons in task names** — Ansible parses them as key-value pairs:
```yaml
# BAD — breaks YAML
- name: Set user:lazydev password in Redis

# GOOD
- name: Set lazydev password in Redis
```

**Line endings** — provision only from the WSL (LF) checkout. A CRLF shebang (`#!/usr/bin/env bash\r`) breaks CGI scripts silently. Pin in `.gitattributes`:
```
*.cgi *.py *.j2 *.sh eol=lf
```

---

## CyberRange Provisioning Layout

```
provisioning/
├── playbook.yml          # one play per host: hosts: server, hosts: attacker
├── requirements.yml      # roles: []  collections: []
└── roles/
    ├── server/
    │   ├── tasks/main.yml
    │   ├── vars/main.yml
    │   ├── handlers/main.yml
    │   └── files/
    └── attacker/
        └── tasks/main.yml   # usually empty or ping only
```

`playbook.yml` maps each host to its role:
```yaml
- name: Provision server
  hosts: server
  become: yes
  roles: [server]

- name: Provision attacker
  hosts: attacker
  become: yes
  roles: [attacker]
```

`ansible-stage-one` runs automatically before your playbook and configures networking.
You only install packages, create users, and set up the scenario.
