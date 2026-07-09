# Sandbox Definition Examples

## Simple Two-Host Setup

```yaml
name: simple-demo

hosts:
  - name: server
    base_box:
      image: ubuntu-noble-x86_64
      mgmt_user: ubuntu
    flavor: standard.small

  - name: client
    base_box:
      image: ubuntu-noble-x86_64
      mgmt_user: ubuntu
    flavor: standard.small

routers:
  - name: router
    base_box:
      image: debian-12-x86_64
      mgmt_user: debian
    flavor: standard.small

networks:
  - name: server-network
    cidr: 192.168.20.0/24
    accessible_by_user: false

  - name: client-network
    cidr: 192.168.30.0/24

net_mappings:
  - host: server
    network: server-network
    ip: 192.168.20.5
  - host: client
    network: client-network
    ip: 192.168.30.5

router_mappings:
  - router: router
    network: server-network
    ip: 192.168.20.1
  - router: router
    network: client-network
    ip: 192.168.30.1

groups: []
```

## Client-Server with Hidden Server

```yaml
name: hidden-server-demo

hosts:
  - name: server
    base_box:
      image: debian-12-x86_64
      mgmt_user: debian
    flavor: standard.small
    hidden: true  # Hidden from topology view

  - name: client
    base_box:
      image: ubuntu-noble-x86_64
      mgmt_user: ubuntu
    flavor: standard.small

routers:
  - name: router
    base_box:
      image: debian-12-x86_64
      mgmt_user: debian
    flavor: standard.small

networks:
  - name: server-network
    cidr: 10.0.1.0/24
    accessible_by_user: false  # Not accessible to trainees

  - name: client-network
    cidr: 10.0.2.0/24

net_mappings:
  - host: server
    network: server-network
    ip: 10.0.1.10
  - host: client
    network: client-network
    ip: 10.0.2.10

router_mappings:
  - router: router
    network: server-network
    ip: 10.0.1.1
  - router: router
    network: client-network
    ip: 10.0.2.1

groups: []
```

## Multi-Network with Multiple Routers

```yaml
name: multi-network-demo

hosts:
  - name: web-server
    base_box:
      image: ubuntu-noble-x86_64
      mgmt_user: ubuntu
    flavor: standard.medium

  - name: db-server
    base_box:
      image: debian-12-x86_64
      mgmt_user: debian
    flavor: standard.medium
    hidden: true

  - name: attacker
    base_box:
      image: kali
      mgmt_user: debian
    flavor: standard.small

routers:
  - name: dmz-router
    base_box:
      image: debian-12-x86_64
      mgmt_user: debian
    flavor: standard.small

  - name: internal-router
    base_box:
      image: debian-12-x86_64
      mgmt_user: debian
    flavor: standard.small

networks:
  - name: dmz
    cidr: 10.0.1.0/24
    accessible_by_user: false

  - name: internal
    cidr: 10.0.2.0/24
    accessible_by_user: false

  - name: attacker-network
    cidr: 10.0.3.0/24

net_mappings:
  - host: web-server
    network: dmz
    ip: 10.0.1.10
  - host: db-server
    network: internal
    ip: 10.0.2.10
  - host: attacker
    network: attacker-network
    ip: 10.0.3.10

router_mappings:
  - router: dmz-router
    network: dmz
    ip: 10.0.1.1
  - router: internal-router
    network: internal
    ip: 10.0.2.1
  - router: dmz-router
    network: attacker-network
    ip: 10.0.3.1

groups:
  - name: servers
    nodes:
      - web-server
      - db-server
```

## Windows Host Example

```yaml
name: windows-demo

hosts:
  - name: windows-client
    base_box:
      image: win10edu
      mgmt_user: windows
      mgmt_protocol: winrm  # Required for Windows
    flavor: standard.medium

  - name: linux-server
    base_box:
      image: ubuntu-noble-x86_64
      mgmt_user: ubuntu
    flavor: standard.small

routers:
  - name: router
    base_box:
      image: debian-12-x86_64
      mgmt_user: debian
    flavor: standard.small

networks:
  - name: main-network
    cidr: 192.168.100.0/24

net_mappings:
  - host: windows-client
    network: main-network
    ip: 192.168.100.10
  - host: linux-server
    network: main-network
    ip: 192.168.100.20

router_mappings:
  - router: router
    network: main-network
    ip: 192.168.100.1

groups: []
```

## With Volumes

```yaml
name: volumes-demo

hosts:
  - name: server
    base_box:
      image: ubuntu-noble-x86_64
      mgmt_user: ubuntu
    flavor: standard.small
    volumes:
      - size: 20   # System drive (must accommodate image)
      - size: 50   # Additional volume
      - size: 100  # Data volume

routers:
  - name: router
    base_box:
      image: debian-12-x86_64
      mgmt_user: debian
    flavor: standard.small

networks:
  - name: main-network
    cidr: 192.168.50.0/24

net_mappings:
  - host: server
    network: main-network
    ip: 192.168.50.10

router_mappings:
  - router: router
    network: main-network
    ip: 192.168.50.1

groups: []
```

## Custom WAN Configuration

```yaml
name: custom-wan-demo

hosts:
  - name: server
    base_box:
      image: ubuntu-noble-x86_64
      mgmt_user: ubuntu
    flavor: standard.small

routers:
  - name: router
    base_box:
      image: debian-12-x86_64
      mgmt_user: debian
    flavor: standard.small

wan:
  name: internet
  cidr: 172.16.0.0/24  # Custom WAN CIDR

networks:
  - name: server-network
    cidr: 192.168.20.0/24

net_mappings:
  - host: server
    network: server-network
    ip: 192.168.20.10

router_mappings:
  - router: router
    network: server-network
    ip: 192.168.20.1

groups: []
```

## Real-World Examples

See complete working examples:
- `@game_builder/games/official_samples/library-demo-training/topology.yml`
- `@game_builder/games/official_samples/library-junior-hacker/topology.yml`
- `@game_builder/games/official_samples/library-secret-laboratory/topology.yml`

## References

- Topology guide: [sandbox-topology.md](sandbox-topology.md)
- Networking guide: [sandbox-networking.md](sandbox-networking.md)
- Full docs: `@game_builder/docs/docs/user-guide-advanced/sandboxes/topology-definition.md`

