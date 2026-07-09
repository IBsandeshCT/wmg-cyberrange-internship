# Sandbox Topology Definition Guide

## Overview

The topology definition (`topology.yml`) describes the network structure, hosts, routers, and their interconnections for a sandbox.

## File Structure

```yaml
name: sandbox-name
hosts: []
routers: []
wan: {}
networks: []
net_mappings: []
router_mappings: []
groups: []
monitoring_targets: []
```

## Required Attributes

### name
- **Type**: String
- **Restrictions**: 
  - Only characters: `a-z`, `A-Z`, `0-9`, `-`
  - First character must be lowercase letter
  - Must be unique within the platform

### hosts
List of end host VMs. Each host has:

```yaml
- name: host-name
  base_box:
    image: image-name
    mgmt_user: username
    mgmt_protocol: ssh  # optional: ssh (default) or winrm
  flavor: flavor-name
  hidden: false  # optional: hide from topology visualization
  volumes: []    # optional: list of volume sizes in GB
  extra: {}      # optional: custom metadata
```

**Key Points**:
- `mgmt_user` must have sudo privileges
- `mgmt_protocol` defaults to `ssh` for Linux, use `winrm` for Windows
- First volume in `volumes` list is used as system drive
- See [openstack_resources.md](openstack_resources.md) for available images

### routers
List of router VMs. Same structure as hosts:

```yaml
- name: router-name
  base_box:
    image: debian-12-x86_64  # Recommended for routers
    mgmt_user: debian
  flavor: standard.small
  hidden: false  # optional
```

**Recommendations**:
- Use `debian-12-x86_64` or `ubuntu-noble-x86_64` for routers
- Routers automatically connect to WAN network

### wan
Special network for router-to-router and Internet connectivity:

```yaml
wan:
  name: wan  # optional, default: "wan"
  cidr: 100.100.100.0/24  # optional, default: "100.100.100.0/24"
```

**Important**: WAN CIDR must not overlap with other networks or management network.

### networks
List of virtual networks:

```yaml
- name: network-name
  cidr: 192.168.20.0/24
  accessible_by_user: true  # optional, default: true
  hidden: false  # optional
```

**Key Points**:
- `accessible_by_user: false` blocks trainee access to hosts in this network
- Networks must have disjunct (non-overlapping) CIDRs
- Must not overlap with WAN or management network

### net_mappings
Connect hosts to networks:

```yaml
- host: host-name
  network: network-name
  ip: 192.168.20.5
```

**Restrictions**:
- IP must be within network CIDR
- Cannot use first IP (gateway) or second IP (DHCP)
- Each host should connect to one network (multiple possible but not recommended)

### router_mappings
Connect routers to networks:

```yaml
- router: router-name
  network: network-name
  ip: 192.168.20.1  # Typically .1 for gateway
```

**Key Points**:
- Each network should connect to one router
- One router can connect to multiple networks
- Router IP is typically the network gateway (.1)

### groups
Ansible groups for provisioning:

```yaml
- name: group-name
  nodes:
    - host-name
    - router-name
```

**Reserved Groups** (cannot redefine):
- `management`: Management node
- `routers`: All routers
- `hosts`: All hosts
- `ssh_nodes`: SSH-managed nodes
- `winrm_nodes`: WinRM-managed nodes
- `user_accessible_nodes`: Nodes in accessible networks
- `hidden_hosts`: Hidden hosts

### monitoring_targets
TCP port monitoring configuration:

```yaml
- node: host-name
  targets:
    - port: 80
      interface: eth0
```

## Naming Restrictions

- **Allowed characters**: `a-z`, `A-Z`, `0-9`, `-`
- **First character**: Must be lowercase letter
- **Uniqueness**: All names (hosts, routers, networks) must be unique within definition

## CIDR Restrictions

1. **Disjunct Networks**: All networks (including WAN) must have non-overlapping CIDRs
2. **Management Network**: Must not overlap with management network CIDR
3. **IP Addresses**: 
   - First IP: Reserved for gateway
   - Second IP: Reserved for DHCP
   - Use IPs from third address onwards

## Flavor Selection

See [openstack_resources.md](openstack_resources.md) for available flavors.

**Guidelines**:
- Use smallest flavor that meets requirements
- Consider: VCPUs, RAM, Disk size

## Image Selection

See [openstack_resources.md](openstack_resources.md) for available images.

**Common Images**:
- `debian-12-x86_64` (mgmt_user: `debian`) - Recommended for routers
- `ubuntu-noble-x86_64` (mgmt_user: `ubuntu`)
- `kali` (mgmt_user: `debian`) - For attacker machines
- `win10edu` (mgmt_user: `windows`, mgmt_protocol: `winrm`) - Windows hosts

## Example

See [sandbox-examples.md](sandbox-examples.md) for complete examples.

## References

- Full documentation: `@game_builder/docs/docs/user-guide-advanced/sandboxes/topology-definition.md`
- Sample topologies: `@game_builder/games/official_samples/*/topology.yml`
- Backend validation: `@game_builder/repos/backend-topology-definition`

