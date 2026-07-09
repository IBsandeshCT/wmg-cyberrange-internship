# Ansible Stage One (Networking) Understanding

## Overview

`ansible-stage-one` is the first provisioning stage that automatically configures networking for all sandboxes. It runs before your custom provisioning playbooks.

## Purpose

1. **Network Configuration**: Sets up network interfaces on all nodes
2. **Routing**: Configures routing tables on routers
3. **NAT**: Sets up NAT on management node
4. **User Access**: Configures user SSH access
5. **Testing**: Verifies network connectivity

## Playbook Structure

### 1. Connection Check
```yaml
- name: check the connection with virtual machines
  hosts: management, routers, ssh_nodes
  tasks:
    - ping:
        register: result
        until: result is not failed
        retries: 25
        delay: 60
```

### 2. Sandbox Networking
```yaml
- name: Sandbox networking
  hosts: management, routers
  become: yes
  roles:
    - role: interface
      # Configures network interfaces
      # Sets up routing
```

**Key Tasks**:
- Configures network interfaces based on inventory
- Sets up routing tables
- Enables IP forwarding on routers

### 3. Netplan Configuration
```yaml
- name: Sandbox networking for netplan hosts
  hosts: ssh_nodes,!routers,!windows_hosts
  tasks:
    - name: Create Netplan configuration
      copy:
        content: |
          network:
            version: 2
            ethernets:
              {{ interface }}:
                dhcp4: true
```

**Purpose**: Configures Netplan on Ubuntu/Debian 12+ hosts

### 4. Management Node Setup
```yaml
- name: Install Chrony on MAN node
  hosts: man
  tasks:
    - apt:
        name: chrony
    - apt:
        name: guacd
```

**Purpose**: Sets up time sync and Guacamole daemon

### 5. NAT Configuration
```yaml
- name: NAT on MAN node
  hosts: man
  tasks:
    - name: setup NAT
      include_role:
        name: iptables
      vars:
        iptables_rules:
          - table: nat
            chain: POSTROUTING
            jump: MASQUERADE
```

**Purpose**: Provides Internet access for sandbox VMs

### 6. Firewall Rules
```yaml
- name: Setup DROP rules on MAN
  hosts: man
  tasks:
    - include_role:
        name: iptables
      vars:
        iptables_rules:
          - chain: FORWARD
            destination: '{{ item }}'
            jump: DROP
      loop: '{{ private_ip_address_range }}'
```

**Purpose**: Blocks private IP ranges from management network

### 7. Network Testing
```yaml
- name: Test sandbox networking
  hosts: management, routers, ssh_nodes
  tasks:
    - command: 'ping -c 3 {{ hostvars["man"]["default_gateway_interface_ip"] }}'
      until: ping_result is not failed
      retries: 18
      delay: 10
```

**Purpose**: Verifies network connectivity

### 8. User Access Configuration
```yaml
- name: User access on MAN and UAN
  hosts: man, uan
  roles:
    - role: user-access
      user_access_username: user
      user_access_ssh_public_key_options: 'restrict,port-forwarding,command="/usr/sbin/nologin"'
```

**Purpose**: Sets up trainee SSH access

## Inventory Variables Used

### Host Variables
- `interfaces`: Network interface definitions
- `user_network_ip`: IP on user-accessible network
- `ip_forward`: Enable IP forwarding (routers)

### Router Interfaces
```yaml
interfaces:
  - def_gw_ip: 100.100.100.1
    mac: 00:00:00:00:00:16
    routes: []
```

### Management Node
- `default_gateway_interface`: Interface to Internet
- `default_gateway_interface_ip`: IP of gateway interface

## Network Configuration Details

### Interface Configuration
- Interfaces configured based on MAC addresses
- Routes set up for network connectivity
- Default gateways configured

### IP Forwarding
- Enabled on routers automatically
- Required for inter-network routing

### DHCP Configuration
- OpenStack provides DHCP
- Second IP (.2) reserved for DHCP server

## What It Doesn't Do

- ❌ Install packages (your provisioning does this)
- ❌ Create users (your provisioning does this)
- ❌ Configure services (your provisioning does this)
- ❌ Set up training-specific content (your provisioning does this)

## What It Does

- ✅ Configures all network interfaces
- ✅ Sets up routing
- ✅ Enables IP forwarding
- ✅ Configures NAT
- ✅ Sets up firewall rules
- ✅ Configures user SSH access
- ✅ Tests connectivity

## Timing

- **Runs**: Automatically after OpenStack stack creation
- **Before**: Your custom provisioning
- **Duration**: ~5-10 minutes depending on topology size

## Dependencies

### Required Roles
- `interface`: Network interface configuration
- `iptables`: Firewall rules
- `user-access`: SSH access setup
- `man-logging-forward`: Logging configuration

### Required Packages
- `chrony`: Time synchronization
- `guacd`: Guacamole daemon

## Customization

### Cannot Customize
- Network interface configuration (automatic)
- Routing setup (automatic)
- NAT configuration (automatic)

### Can Customize (in your provisioning)
- Additional network services
- Custom firewall rules (after stage one)
- Additional user accounts
- Service configurations

## Troubleshooting

### Network Not Working
- Check ansible-stage-one logs
- Verify inventory has correct interface definitions
- Check router IP forwarding enabled
- Verify NAT configured on MAN

### Hosts Cannot Communicate
- Check routing tables on routers
- Verify network CIDRs don't overlap
- Check firewall rules

### User Cannot Access
- Check user-access role ran successfully
- Verify network has `accessible_by_user: true`
- Check SSH keys configured

## References

- Source code: `@game_builder/repos/ansible-stage-one/provisioning/playbook.yml`
- Roles: `@game_builder/repos/ansible-stage-one/provisioning/roles/`
- Documentation: `@game_builder/docs/docs/user-guide-advanced/sandboxes/sandbox-provisioning.md`

