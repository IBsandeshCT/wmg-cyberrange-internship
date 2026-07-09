# Sandbox Networking Guide

## Overview

Sandbox networking is automatically configured by `ansible-stage-one` before your custom provisioning runs. Understanding the network structure helps design effective topologies.

## Network Architecture

### Management Network
- **Purpose**: Platform access to VMs for provisioning and management
- **Access**: Not accessible to trainees
- **CIDR**: Platform-managed, separate from user networks
- **Access Method**: SSH/WinRM through proxy-jump

### User Networks
- **Purpose**: Trainee access to hosts
- **Access**: Controlled by `accessible_by_user` attribute
- **CIDR**: Defined in topology definition
- **Access Method**: SSH config or web console

### WAN Network
- **Purpose**: Router-to-router and Internet connectivity
- **CIDR**: Default `100.100.100.0/24` (configurable)
- **Auto-assignment**: Routers automatically connected

## Network Flow

```
Internet
  ↓
WAN (100.100.100.0/24)
  ↓
Router (gateway)
  ↓
User Network (e.g., 192.168.20.0/24)
  ↓
Hosts
```

## IP Address Allocation

### Reserved IPs
- **First IP** (.1): Network gateway (router)
- **Second IP** (.2): DHCP server
- **Third IP onwards**: Available for hosts

### Example
For network `192.168.20.0/24`:
- `192.168.20.1`: Router gateway (reserved)
- `192.168.20.2`: DHCP (reserved)
- `192.168.20.3+`: Available for hosts

## Router Configuration

Routers automatically:
- Connect to WAN network
- Enable IP forwarding
- Configure routing tables
- Act as gateways for connected networks

### Router Interfaces
Each router has:
- **WAN interface**: Connected to WAN network
- **Network interfaces**: One per connected network

## Access Control

### accessible_by_user
- `true` (default): Trainees can access hosts in this network
- `false`: Network hidden from trainees, not in SSH config

### hidden
- `true`: Host/router hidden from topology visualization
- `false` (default): Visible to trainees

## Routing

### Automatic Routing
- Routers automatically route between connected networks
- WAN provides Internet access
- Management network isolated from user networks

### Custom Routes
Define in topology definition (advanced):

```yaml
router_mappings:
  - router: router1
    network: network1
    ip: 192.168.20.1
    routes: []  # Custom routes if needed
```

## Network Isolation

### Isolated Networks
Networks with `accessible_by_user: false`:
- Not accessible to trainees
- Not included in SSH config
- Still reachable via routers (if configured)

### Management Isolation
Management network:
- Completely isolated from user networks
- Only accessible via proxy-jump
- Used for provisioning and monitoring

## NAT Configuration

Management node (MAN) provides:
- NAT for Internet access
- Firewall rules
- Logging forward

## DNS Configuration

- Routers forward DNS queries
- Management node may provide DNS
- Hosts use DHCP-assigned DNS

## Testing Connectivity

After provisioning, test:

```yaml
- name: Test connectivity
  hosts: all
  tasks:
    - ping:
        host: 8.8.8.8
    - ping:
        host: router-ip
```

## Common Patterns

### Single Network
Simple setup with one network:

```yaml
networks:
  - name: main-network
    cidr: 192.168.20.0/24

net_mappings:
  - host: server
    network: main-network
    ip: 192.168.20.5
  - host: client
    network: main-network
    ip: 192.168.20.6
```

### Multiple Networks
Separate networks for different purposes:

```yaml
networks:
  - name: server-network
    cidr: 192.168.20.0/24
    accessible_by_user: false
  - name: client-network
    cidr: 192.168.30.0/24

router_mappings:
  - router: router1
    network: server-network
    ip: 192.168.20.1
  - router: router1
    network: client-network
    ip: 192.168.30.1
```

### DMZ Pattern
Isolated server network:

```yaml
networks:
  - name: dmz
    cidr: 10.0.1.0/24
    accessible_by_user: false
  - name: internal
    cidr: 10.0.2.0/24
```

## Troubleshooting

### Host Cannot Reach Internet
- Check router is connected to WAN
- Verify router IP forwarding enabled
- Check NAT on management node

### Hosts Cannot Communicate
- Verify same network or router connection
- Check router routing tables
- Verify network CIDRs don't overlap

### Trainee Cannot Access Host
- Check `accessible_by_user: true` on network
- Verify host not `hidden: true`
- Check SSH config generation

## References

- ansible-stage-one: `@game_builder/repos/ansible-stage-one/provisioning/playbook.yml`
- Full docs: `@game_builder/docs/docs/user-guide-advanced/sandboxes/`
- Network diagram: `@game_builder/docs/docs/img/user-guide-advanced/sandboxes/`

