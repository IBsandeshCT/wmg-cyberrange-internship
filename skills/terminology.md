# Terminology Reference

## Sandbox Terms

### Sandbox
An isolated virtual environment with virtual networks enabling users to connect to VMs and communicate within the network. Runs in the cloud and is remotely accessible.

### Sandbox Definition
Definition of the internal structure of sandboxes (networks and hosts) and user customization. Consists of:
- **Topology Definition**: Network structure
- **Sandbox Provisioning**: Host configuration

### Topology Definition
YAML file (`topology.yml`) describing:
- Hosts (VMs)
- Routers (network routing nodes)
- Networks (virtual networks)
- Network mappings (host-to-network connections)
- Router mappings (router-to-network connections)

### Topology Instance
A deployed instance of a topology definition - an actual running sandbox.

### Pool
A group of cloud sandboxes created based on the same sandbox definition. Used to provide sandboxes for training instances.

### Host
A virtual machine (VM) in the sandbox. Can be:
- **Regular host**: End-user machine
- **Router**: Network routing node
- **Management Node (MAN)**: Platform management node (auto-created)
- **User Access Node (UAN)**: Trainee gateway (auto-created)

### Base Box
Specification of the VM image and management user:
- **image**: OpenStack image name
- **mgmt_user**: User with sudo privileges for provisioning
- **mgmt_protocol**: `ssh` (default) or `winrm` for Windows

### Flavor
OpenStack VM hardware specification (VCPUs, RAM, Disk size).

### Network
Virtual network connecting hosts and routers. Has:
- **name**: Unique network identifier
- **cidr**: IP address range (e.g., `192.168.20.0/24`)
- **accessible_by_user**: Whether trainees can access this network

### WAN
Special network connecting routers to each other and the Internet. Default CIDR: `100.100.100.0/24`

## Training Terms

### Training Definition
Blueprint defining the training scenario. Can be:
- **Linear**: Sequential levels
- **Adaptive**: Dynamic difficulty based on performance

### Training Instance
A time-limited deployment of a training definition during which trainees have access. Linked to a pool of sandboxes.

### Training Run
A single trainee's execution of a training. Each run gets assigned a sandbox from the pool.

### Level (Linear Training)
A step in a linear training:
- **INFO_LEVEL**: Information page
- **ACCESS_LEVEL**: Instructions for sandbox access
- **TRAINING_LEVEL**: Task to solve with answer submission
- **ASSESSMENT_LEVEL**: Test or questionnaire

### Phase (Adaptive Training)
A step in an adaptive training:
- **Info Phase**: Information page
- **Access Phase**: Sandbox access instructions
- **Training Phase**: Task with dynamic difficulty
- **Adaptive Questionnaire Phase**: Pre-training knowledge assessment
- **General Questionnaire Phase**: Feedback collection

### APG (Automatic Problem Generation)
Technique for generating variant answers per sandbox using `variables.yml` to reduce answer sharing.

## Technical Terms

### Ansible Stage One
The first provisioning stage that sets up networking. Handled automatically by the platform using `ansible-stage-one` playbook.

### Sandbox Provisioning
Custom Ansible playbooks that configure hosts after networking is set up. Defined in the `provisioning/` directory.

### Management Network
Network used by the platform to manage sandbox VMs. Not accessible to trainees.

### User Network
Network accessible to trainees for connecting to hosts.

### Proxy Jump
SSH jump host for accessing sandbox VMs through the management network.

## References

- Full terminology: `@game_builder/docs/docs/basic-concepts/terminology.md`
- Topology details: `@game_builder/rules/sandbox-topology.md`

