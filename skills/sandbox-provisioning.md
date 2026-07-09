# Sandbox Provisioning Guide

## Overview

Sandbox Provisioning uses Ansible playbooks to configure hosts after the networking stage (ansible-stage-one) completes. This is where you install packages, create users, configure services, and set up your training scenario.

## Directory Structure

```
provisioning/
├── playbook.yml          # Main playbook (required)
├── pre-playbook.yml      # Pre-setup playbook (optional)
├── requirements.yml      # Ansible Galaxy dependencies (optional)
├── roles/                # Custom roles
│   └── role-name/
│       ├── tasks/
│       ├── handlers/
│       ├── files/
│       ├── templates/
│       └── vars/
├── group_vars/           # Group variables
└── host_vars/            # Host-specific variables
```

## Minimal Playbook

If no provisioning is needed, use:

```yaml
- hosts: all
```

## Ansible Host Groups

### Default Groups
- `all`: All hosts and routers
- `management`: Management node (MAN)
- `routers`: All routers
- `hosts`: All hosts
- `ssh_nodes`: All SSH-managed nodes
- `winrm_nodes`: All WinRM-managed nodes
- `user_accessible_nodes`: Nodes in accessible networks
- `hidden_hosts`: Hidden hosts

### Custom Groups
Define in `topology.yml`:

```yaml
groups:
  - name: servers
    nodes:
      - server1
      - server2
```

## Special Variables

Available in all playbooks:

- `global_openstack_stack_id`: OpenStack stack ID
- `global_pool_id`: Pool ID
- `global_sandbox_id`: Sandbox UUID
- `global_sandbox_allocation_unit_id`: Allocation unit ID
- `global_sandbox_ip`: Sandbox IPv4 address
- `global_sandbox_name`: Sandbox name
- `global_head_ip`: Platform IP/FQDN
- `global_ssh_public_user_key`: Path to user SSH public key
- `global_ssh_public_mgmt_key`: Path to management SSH public key

## Inventory Variables

Each host has inventory variables:

```yaml
host-name:
  ansible_host: 192.168.128.3      # Management IP
  ansible_user: ubuntu              # Management user
  user_network_ip: 10.10.30.5      # User network IP
```

Routers have additional:

```yaml
router-name:
  interfaces:
    - def_gw_ip: 100.100.100.1
      mac: 00:00:00:00:00:16
      routes: []
  ip_forward: true
```

## Common Patterns

### Create User for Trainees

```yaml
- name: Create trainee user
  hosts: user_accessible_nodes
  become: yes
  roles:
    - role: user-access
      user_access_username: user
      user_access_password: Password123
      user_access_sudo: true
```

### Install Packages

```yaml
- name: Install packages
  hosts: hosts
  become: yes
  tasks:
    - apt:
        name:
          - package1
          - package2
        update_cache: yes
      when: ansible_os_family == "Debian"
```

### Copy Files

```yaml
- name: Copy files
  hosts: server
  become: yes
  tasks:
    - copy:
        src: files/data.txt
        dest: /home/user/data.txt
        owner: user
        group: user
        mode: '0644'
```

### Use Variables from variables.yml (APG)

```yaml
- name: Setup server
  hosts: server
  become: yes
  roles:
    - role: server
      telnet_port: "{{ telnet_port }}"
      flag: "{{ alice_flag }}"
```

### Configure Services

```yaml
- name: Start service
  hosts: server
  become: yes
  tasks:
    - systemd:
        name: myservice
        enabled: yes
        state: started
```

### Windows Hosts

```yaml
- name: Configure Windows
  hosts: winrm_nodes
  vars:
    ansible_connection: psrp
    ansible_psrp_auth: certificate
  tasks:
    - win_shell: |
        # PowerShell commands
```

## Pre-Playbook

Use `pre-playbook.yml` for setup needed before main playbook:

```yaml
- name: Install dependencies
  hosts: all
  become: yes
  tasks:
    - apt:
        name: python3-pip
        state: present
```

## Requirements File

Install Ansible Galaxy roles:

```yaml
# requirements.yml
- src: geerlingguy.docker
  version: 4.0.0
```

## Best Practices

1. **Idempotency**: Playbooks should be idempotent (safe to run multiple times)
2. **Error Handling**: Use `failed_when`, `ignore_errors` appropriately
3. **Conditionals**: Check OS family, distribution before tasks
4. **Roles**: Organize complex setups into roles
5. **Variables**: Use `group_vars` and `host_vars` for customization
6. **Testing**: Test playbooks on local VMs before deployment

## Command Logging

Enable command logging:

```yaml
- name: Setup logging
  hosts: hosts
  become: yes
  roles:
    - role: sandbox-logging
      slf_destination_port: '514'
```

## Example Playbook

See sample games:
- `@game_builder/games/official_samples/library-demo-training/provisioning/playbook.yml`
- `@game_builder/games/official_samples/library-junior-hacker/provisioning/playbook.yml`

## References

- Full documentation: `@game_builder/docs/docs/user-guide-advanced/sandboxes/sandbox-provisioning.md`
- Ansible docs: https://docs.ansible.com/
- Sample playbooks: `@game_builder/games/official_samples/*/provisioning/`

