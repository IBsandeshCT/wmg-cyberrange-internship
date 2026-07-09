# Training Level Types and Questions

## Level Types

### INFO_LEVEL
Information page with markdown content. No interaction required.

### ACCESS_LEVEL
Sandbox access instructions. Trainee submits passkey to continue.

### TRAINING_LEVEL
Task with answer submission. Trainee solves task and submits answer.

### ASSESSMENT_LEVEL
Test or questionnaire with questions.

## Question Types (Assessment Levels)

### Multiple Choice Question (MCQ)

```json
{
  "question_type": "MCQ",
  "text": "Question text?",
  "points": 100,
  "penalty": 0,
  "order": 0,
  "answer_required": true,
  "choices": [
    {
      "text": "Option 1",
      "correct": true,
      "order": 0
    },
    {
      "text": "Option 2",
      "correct": false,
      "order": 1
    }
  ]
}
```

**Fields**:
- `question_type`: `"MCQ"`
- `text`: Question text
- `points`: Points for correct answer
- `penalty`: Points deducted for wrong answer
- `order`: Question order
- `answer_required`: Must answer before submission
- `choices`: Array of options with `correct` boolean

### Extended Matching Item (EMI)

```json
{
  "question_type": "EMI",
  "text": "Match items",
  "points": 100,
  "penalty": 0,
  "order": 0,
  "answer_required": true,
  "extended_matching_options": [
    {
      "text": "Option 1",
      "order": 0
    },
    {
      "text": "Option 2",
      "order": 1
    }
  ],
  "extended_matching_statements": [
    {
      "text": "Statement 1",
      "order": 0,
      "correct_option_order": 0
    },
    {
      "text": "Statement 2",
      "order": 1,
      "correct_option_order": 1
    }
  ]
}
```

**Fields**:
- `question_type`: `"EMI"`
- `extended_matching_options`: Column options
- `extended_matching_statements`: Row statements with `correct_option_order`

### Freeform Question (FFQ)

```json
{
  "question_type": "FFQ",
  "text": "Enter your answer:",
  "points": 100,
  "penalty": 0,
  "order": 0,
  "answer_required": true,
  "choices": [
    {
      "text": "correct-answer",
      "correct": true,
      "order": 0
    }
  ]
}
```

**Fields**:
- `question_type`: `"FFQ"`
- `choices`: Array with correct answer(s)
- For questionnaires: `answer_required: false`, no `choices`

## Assessment Types

### TEST
Graded assessment with points:
- Questions have `points` and `penalty`
- Trainee receives score
- Used for knowledge testing

### QUESTIONNAIRE
Feedback collection:
- Questions typically have `points: 0`
- `answer_required: false` for optional questions
- Used for feedback and surveys

## Training Level Fields

### Common Fields
- `title`: Level title
- `level_type`: Level type enum
- `order`: Sequential order
- `estimated_duration`: Minutes

### TRAINING_LEVEL Specific
- `answer`: Static answer (if not variant)
- `answer_variable_name`: APG variable name
- `variant_answers`: Use APG (true/false)
- `content`: Task description (markdown)
- `solution`: Solution steps (markdown)
- `solution_penalized`: Penalty for viewing solution
- `hints`: Array of hint objects
- `incorrect_answer_limit`: Max wrong attempts
- `max_score`: Maximum points
- `mitre_techniques`: MITRE ATT&CK techniques
- `expected_commands`: Expected commands
- `commands_required`: Require command tracking

### ACCESS_LEVEL Specific
- `passkey`: Answer to submit
- `cloud_content`: Cloud sandbox instructions
- `local_content`: Local sandbox instructions

### ASSESSMENT_LEVEL Specific
- `questions`: Array of question objects
- `instructions`: Assessment instructions
- `assessment_type`: `"TEST"` or `"QUESTIONNAIRE"`

## Hint Structure

```json
{
  "title": "Hint title",
  "content": "Hint content (markdown)",
  "hint_penalty": 20,
  "order": 0
}
```

**Fields**:
- `title`: Hint title
- `content`: Hint text (markdown)
- `hint_penalty`: Points deducted for viewing
- `order`: Display order

## MITRE Techniques

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

Examples:
- `TA0007.T1046`: Network Service Scanning
- `TA0006.T1110`: Brute Force
- `TA0004.T1068`: Exploitation for Privilege Escalation

## Variable Substitution

In solutions and content, use:
- `${ANSWER}`: The correct answer
- `${variable_name}`: APG variable value (e.g., `${telnet_port}`)

## Examples

See sample trainings:
- `@game_builder/games/official_samples/library-demo-training/training.json`
- `@game_builder/games/official_samples/library-junior-hacker/training.json`

## References

- Training overview: `@game_builder/docs/docs/user-guide-advanced/trainings/trainings-overview.md`
- Question schema: `@game_builder/repos/backend-training/training-service/src/main/resources/questions-schema.json`

