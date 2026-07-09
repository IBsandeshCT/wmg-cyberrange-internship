# Adaptive Training Definition Guide

## Overview

Adaptive training definitions provide dynamic difficulty adjustment based on trainee performance. The system selects task variants of appropriate difficulty using a computational model.

## Key Concepts

### Phases vs Levels
- **Linear**: Uses "levels" (sequential)
- **Adaptive**: Uses "phases" (graph structure with dynamic selection)

### Decision Matrix
Computational model that selects task difficulty based on:
- Pre-training questionnaire results
- Keyword usage (expected commands)
- Completion time
- Solution display events
- Submitted incorrect answers

## File Structure

Similar to linear training but uses phases:

```json
{
  "title": "Adaptive Training",
  "description": "Description",
  "prerequisites": [],
  "outcomes": [],
  "state": "UNRELEASED",
  "phases": [],
  "estimated_duration": 60
}
```

## Phase Types

### 1. Info Phase
Information page (similar to INFO_LEVEL):

```json
{
  "title": "Welcome",
  "phase_type": "INFO_PHASE",
  "order": 0,
  "content": "# Welcome\n\nTraining information..."
}
```

### 2. Access Phase
Sandbox access instructions:

```json
{
  "title": "Get Access",
  "phase_type": "ACCESS_PHASE",
  "order": 1,
  "passkey": "start",
  "cloud_content": "Access instructions...",
  "local_content": "Local instructions..."
}
```

### 3. Adaptive Questionnaire Phase
Pre-training knowledge assessment:

```json
{
  "title": "Pre-Training Assessment",
  "phase_type": "ADAPTIVE_QUESTIONNAIRE_PHASE",
  "order": 2,
  "questions": [],
  "relations": []
}
```

**Relations**: Link questions to training phases for difficulty calculation.

### 4. General Questionnaire Phase
Feedback collection (not linked to phases):

```json
{
  "title": "Feedback",
  "phase_type": "GENERAL_QUESTIONNAIRE_PHASE",
  "order": 10,
  "questions": []
}
```

### 5. Training Phase
Task with dynamic difficulty:

```json
{
  "title": "Network Scanning",
  "phase_type": "TRAINING_PHASE",
  "order": 3,
  "tasks": [],
  "decision_matrix": {}
}
```

## Training Phase Structure

### Tasks
Array of task variants (hardest to easiest by order):

```json
{
  "tasks": [
    {
      "order": 0,
      "title": "Hard Task",
      "content": "Task description...",
      "answer": null,
      "answer_variable_name": "flag",
      "variant_answers": true,
      "solution": "Solution...",
      "hints": []
    },
    {
      "order": 1,
      "title": "Medium Task",
      "content": "Easier variant...",
      "answer": null,
      "answer_variable_name": "flag",
      "variant_answers": true,
      "solution": "Solution...",
      "hints": []
    },
    {
      "order": 2,
      "title": "Easy Task",
      "content": "Easiest variant...",
      "answer": null,
      "answer_variable_name": "flag",
      "variant_answers": true,
      "solution": "Solution...",
      "hints": []
    }
  ]
}
```

**Task Selection**: System selects task with lowest order number that matches trainee's computed difficulty.

### Decision Matrix
Weights for difficulty calculation:

```json
{
  "decision_matrix": {
    "pre_training_questionnaire_weight": 0.3,
    "keyword_used_weight": 0.2,
    "completed_in_time_weight": 0.2,
    "solution_displayed_weight": 0.1,
    "submitted_answers_weight": 0.2
  }
}
```

**Weights**:
- `pre_training_questionnaire_weight`: Correct answers in related questions
- `keyword_used_weight`: Number of expected commands used
- `completed_in_time_weight`: Task completed within estimated time
- `solution_displayed_weight`: Solution was viewed
- `submitted_answers_weight`: Number of incorrect submissions

## Adaptive Questionnaire Relations

Link questions to training phases:

```json
{
  "relations": [
    {
      "phase_id": 3,
      "question_ids": [0, 1, 2],
      "essential_ratio": 0.6
    }
  ]
}
```

**Fields**:
- `phase_id`: Training phase ID (order)
- `question_ids`: Related question indices
- `essential_ratio`: Required knowledge ratio (0.0-1.0)

## Question Types (Adaptive)

### Multiple Choice Question (MCQ)
```json
{
  "question_type": "MCQ",
  "text": "Question?",
  "points": 0,
  "order": 0,
  "answer_required": true,
  "choices": [
    {
      "text": "Option 1",
      "correct": true,
      "order": 0
    }
  ]
}
```

### Free Form Question (FFQ)
```json
{
  "question_type": "FFQ",
  "text": "Answer:",
  "points": 0,
  "order": 1,
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

### Rating Form Question (RFQ)
```json
{
  "question_type": "RFQ",
  "text": "Rate your knowledge:",
  "points": 0,
  "order": 2,
  "answer_required": true,
  "min_rating": 1,
  "max_rating": 5
}
```

## Workflow

1. **Pre-Training Questionnaire**: Assess knowledge
2. **Access Phase**: Connect to sandbox
3. **Training Phases**: Dynamic task selection based on performance
4. **Post-Training Questionnaire**: Collect feedback

## Best Practices

1. **Task Variants**: Create 3-5 difficulty variants per phase
2. **Clear Ordering**: Hardest (order 0) to easiest (highest order)
3. **Decision Matrix**: Balance weights appropriately
4. **Relations**: Link questions to relevant phases
5. **Essential Ratio**: Set appropriate knowledge thresholds

## Example

See adaptive training samples:
- `@game_builder/games/official_samples/library-demo-training-adaptive/`
- `@game_builder/games/official_samples/library-junior-hacker-adaptive/`

## References

- Full docs: `@game_builder/docs/docs/user-guide-advanced/trainings/trainings-overview.md`
- Adaptive workflow diagram: `@game_builder/docs/docs/img/user-guide-advanced/trainings/adaptive-workflow.svg`
- Research paper: https://ieeexplore.ieee.org/document/9926178

