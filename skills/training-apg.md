# Automatic Problem Generation (APG) Guide

## Overview

APG (Automatic Problem Generation) creates variant answers for each sandbox instance, reducing answer sharing and enabling unique problem instances per trainee.

## How APG Works

1. **Variables Definition**: Define variables in `variables.yml`
2. **Value Generation**: Platform generates unique values per sandbox
3. **Provisioning**: Values injected into Ansible playbooks
4. **Answer Storage**: Values stored for answer validation
5. **Answer Validation**: Trainee answers compared to stored values

## Enabling APG

### 1. Set Training Flag
```json
{
  "variant_sandboxes": true
}
```

### 2. Create variables.yml
In sandbox definition root:

```yaml
telnet_port: 3302
alice_flag: "flag{alice-secret}"
root_flag: "flag{root-secret}"
password: "weakpass123"
```

### 3. Use in Provisioning
Reference variables in Ansible:

```yaml
- name: Setup server
  hosts: server
  become: yes
  roles:
    - role: server
      telnet_port: "{{ telnet_port }}"
      flag: "{{ alice_flag }}"
```

### 4. Reference in Training
Use `answer_variable_name` in training levels:

```json
{
  "title": "Find the port",
  "level_type": "TRAINING_LEVEL",
  "answer_variable_name": "telnet_port",
  "variant_answers": true,
  "solution": "The telnet service runs on port **${ANSWER}**"
}
```

## Variable Naming

- Use descriptive names: `telnet_port`, `alice_flag`, `root_flag`
- Follow naming conventions: lowercase, underscores
- Match variable names exactly between `variables.yml` and training JSON

## Variable Types

Variables can be defined with types for automatic generation:

### Port Type
```yaml
telnet_port:
  type: port
  min: 1500
  max: 9999  # optional
```

### Text Type
```yaml
alice_flag:
  type: text
```

### Simple Values
You can also define static values (though these won't be unique per sandbox):

```yaml
telnet_port: 3302
alice_flag: "flag{alice-secret}"
root_flag: "flag{root-secret}"
```

### Common Patterns

**Ports**:
```yaml
telnet_port:
  type: port
  min: 1500
ssh_port:
  type: port
  min: 2000
```

**Flags/Answers**:
```yaml
alice_flag:
  type: text
root_flag:
  type: text
secret_key:
  type: text
```

**Passwords** (static or generated):
```yaml
weak_password: "password123"
admin_password:
  type: text
```

**File Names**:
```yaml
secret_file: "secret.txt"
config_file: "config.yml"
```

**Usernames**:
```yaml
target_user: "alice"
admin_user: "admin"
```

## Using Variables in Provisioning

### In Playbooks
```yaml
- name: Configure service
  hosts: server
  become: yes
  tasks:
    - lineinfile:
        path: /etc/service/config
        line: "PORT={{ telnet_port }}"
```

### In Roles
```yaml
# roles/server/tasks/main.yml
- name: Create flag file
  copy:
    content: "{{ flag }}"
    dest: /home/alice/flag.txt
```

### In Templates
```yaml
# roles/server/templates/config.j2
port: {{ telnet_port }}
flag: {{ alice_flag }}
```

## Using Variables in Training

### Training Level
```json
{
  "answer_variable_name": "telnet_port",
  "variant_answers": true,
  "solution": "Scan with nmap to find port **${ANSWER}**"
}
```

### Solution Substitution
Use `${ANSWER}` in solutions:
- Replaced with actual generated value
- Works in markdown content
- Can be used multiple times

## Answer Storage

Generated values are stored in:
- **Answers Storage Service**: Platform service
- **Per Sandbox**: Each sandbox has unique values
- **Per Training Run**: Values linked to training run

## Validation

Trainee answers are compared to stored values:
- Exact match (case-sensitive)
- For ports: numeric comparison
- For flags: string comparison

## Best Practices

1. **Meaningful Names**: Use descriptive variable names
2. **Documentation**: Document expected variable values
3. **Testing**: Test with sample values
4. **Consistency**: Use same variable names across provisioning and training
5. **Validation**: Ensure variables are used correctly

## Example Workflow

### 1. Define Variables
```yaml
# variables.yml
telnet_port: 3302
alice_flag: "flag{alice-secret-123}"
root_flag: "flag{root-secret-456}"
```

### 2. Use in Provisioning
```yaml
# provisioning/playbook.yml
- name: Setup server
  hosts: server
  roles:
    - role: server
      telnet_port: "{{ telnet_port }}"
      alice_flag: "{{ alice_flag }}"
      root_flag: "{{ root_flag }}"
```

### 3. Reference in Training
```json
{
  "levels": [
    {
      "title": "Find Port",
      "level_type": "TRAINING_LEVEL",
      "answer_variable_name": "telnet_port",
      "variant_answers": true,
      "solution": "Port is **${ANSWER}**"
    },
    {
      "title": "Get Alice Flag",
      "level_type": "TRAINING_LEVEL",
      "answer_variable_name": "alice_flag",
      "variant_answers": true,
      "solution": "Flag is **${ANSWER}**"
    }
  ]
}
```

## Common Patterns

### Port Discovery
```yaml
# variables.yml
service_port: 3302
```

```json
{
  "answer_variable_name": "service_port",
  "content": "Find the port where the service is running"
}
```

### Flag Collection
```yaml
# variables.yml
user_flag: "flag{user-secret}"
root_flag: "flag{root-secret}"
```

```json
{
  "answer_variable_name": "user_flag",
  "content": "Find the flag in the user's home directory"
}
```

### Password Cracking
```yaml
# variables.yml
weak_password: "password123"
```

```json
{
  "answer_variable_name": "weak_password",
  "content": "Crack the weak password"
}
```

## Troubleshooting

### Variable Not Found
- Check `variables.yml` exists in sandbox definition root
- Verify variable name matches exactly
- Ensure `variant_sandboxes: true` in training

### Value Not Generated
- Check training has `variant_sandboxes: true`
- Verify at least one level uses `variant_answers: true`
- Check variable is referenced in training

### Answer Mismatch
- Verify variable name matches
- Check value format (case-sensitive)
- Ensure provisioning sets value correctly

## References

- Sample APG training: `@game_builder/games/official_samples/library-demo-training/`
- Variables example: `@game_builder/games/official_samples/library-demo-training/variables.yml`
- Training docs: `@game_builder/docs/docs/user-guide-advanced/trainings/trainings-overview.md`

