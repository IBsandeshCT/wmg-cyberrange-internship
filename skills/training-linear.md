# Linear Training Definition Guide

## Overview

Linear training definitions provide sequential learning paths with levels that trainees complete in order. Each level unlocks after the previous one is completed.

## File Structure

Training definitions are JSON files (`training.json`) with the following structure:

```json
{
  "title": "Training Title",
  "description": "Training description",
  "prerequisites": [],
  "outcomes": [],
  "state": "UNRELEASED",
  "levels": [],
  "estimated_duration": 45,
  "variant_sandboxes": false
}
```

## Top-Level Fields

### title
- **Type**: String
- **Required**: Yes
- **Description**: Name of the training

### description
- **Type**: String
- **Required**: No
- **Description**: Description visible to trainees

### prerequisites
- **Type**: Array of strings
- **Required**: No
- **Description**: Required knowledge/skills

### outcomes
- **Type**: Array of strings
- **Description**: Learning objectives

### state
- **Type**: String (enum)
- **Required**: Yes
- **Values**: `UNRELEASED`, `RELEASED`, `ARCHIVED`
- **Description**: Training definition state

### levels
- **Type**: Array of level objects
- **Required**: Yes
- **Description**: Sequential levels in the training

### estimated_duration
- **Type**: Integer (minutes)
- **Description**: Estimated completion time

### variant_sandboxes
- **Type**: Boolean
- **Description**: Enable APG (Automatic Problem Generation)

## Level Types

### 1. INFO_LEVEL
Information page for trainees:

```json
{
  "title": "Info",
  "level_type": "INFO_LEVEL",
  "order": 0,
  "estimated_duration": 0,
  "content": "# Welcome\n\nTraining information..."
}
```

**Fields**:
- `title`: Level title
- `level_type`: `"INFO_LEVEL"`
- `order`: Sequential order (0-based)
- `estimated_duration`: Minutes (0 for info)
- `content`: Markdown content

### 2. ACCESS_LEVEL
Instructions for accessing sandbox:

```json
{
  "title": "Get Access",
  "level_type": "ACCESS_LEVEL",
  "order": 1,
  "estimated_duration": 0,
  "passkey": "start",
  "cloud_content": "Access instructions...",
  "local_content": "Local sandbox instructions..."
}
```

**Fields**:
- `passkey`: Answer to submit (e.g., "start")
- `cloud_content`: Instructions for cloud sandbox
- `local_content`: Instructions for local sandbox

### 3. TRAINING_LEVEL
Task to solve with answer submission:

```json
{
  "title": "Finding open ports",
  "level_type": "TRAINING_LEVEL",
  "order": 2,
  "estimated_duration": 10,
  "minimal_possible_solve_time": 1,
  "answer": null,
  "answer_variable_name": "telnet_port",
  "content": "Task description...",
  "solution": "Solution steps...",
  "solution_penalized": true,
  "hints": [],
  "incorrect_answer_limit": 10,
  "max_score": 50,
  "variant_answers": true,
  "mitre_techniques": [],
  "expected_commands": [],
  "commands_required": true
}
```

**Key Fields**:
- `answer`: Static answer (if `variant_answers: false`)
- `answer_variable_name`: Variable name from `variables.yml` (if `variant_answers: true`)
- `variant_answers`: Use APG variable (true) or static answer (false)
- `solution`: Markdown solution (use `${ANSWER}` for variable substitution)
- `solution_penalized`: Penalty for viewing solution
- `hints`: Array of hint objects
- `max_score`: Maximum points
- `mitre_techniques`: MITRE ATT&CK techniques
- `expected_commands`: Commands trainee should use

**Hint Structure**:
```json
{
  "title": "Hint title",
  "content": "Hint content",
  "hint_penalty": 20,
  "order": 0
}
```

### 4. ASSESSMENT_LEVEL
Test or questionnaire:

```json
{
  "title": "Test Example",
  "level_type": "ASSESSMENT_LEVEL",
  "order": 5,
  "estimated_duration": 5,
  "questions": [],
  "instructions": "Test instructions",
  "assessment_type": "TEST"
}
```

**Assessment Types**:
- `TEST`: Graded assessment
- `QUESTIONNAIRE`: Feedback collection

**Question Types**: See [training-levels.md](training-levels.md)

## Answer Handling

### Static Answers
```json
{
  "answer": "correct-answer",
  "variant_answers": false
}
```

### APG Variable Answers
```json
{
  "answer": null,
  "answer_variable_name": "flag_value",
  "variant_answers": true
}
```

Variable must exist in `variables.yml`:
```yaml
flag_value: "generated-value"
```

## Solution Formatting

Use `${ANSWER}` for variable substitution:

```json
{
  "solution": "The answer is **${ANSWER}**. Found in /home/user/flag.txt"
}
```

For APG, `${ANSWER}` is replaced with the generated value.

## MITRE ATT&CK Integration

Link levels to MITRE techniques:

```json
{
  "mitre_techniques": [
    {
      "technique_key": "TA0007.T1046"
    }
  ]
}
```

Format: `TA<number>.<T<number>>`

## Command Tracking

Track expected commands:

```json
{
  "expected_commands": ["nmap", "hydra", "telnet"],
  "commands_required": true
}
```

## Level Ordering

- Levels must have sequential `order` values
- Start from 0
- No gaps allowed
- Trainees unlock levels sequentially

## Best Practices

1. **Start with INFO_LEVEL**: Provide overview
2. **ACCESS_LEVEL early**: Help trainees connect
3. **Progressive difficulty**: Easy to hard
4. **Clear instructions**: Detailed `content` fields
5. **Helpful hints**: Provide hints with penalties
6. **Solution clarity**: Clear solutions for learning

## Example

See `@game_builder/games/official_samples/library-demo-training/training.json`

## References

- Full docs: `@game_builder/docs/docs/user-guide-advanced/trainings/trainings-overview.md`
- Sample trainings: `@game_builder/games/official_samples/*/training.json`
- APG details: [training-apg.md](training-apg.md)

