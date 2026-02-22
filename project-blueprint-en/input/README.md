# Input — Human-Created Content

This directory contains files **created and edited by humans**.
AI references these files as read-only and generates deliverables in `output/`.

## Directory Structure

```text
input/
└── requirements/          Requirement memos
    ├── REQ_001_xxx.md     Requirement memo per feature
    ├── REQ_002_xxx.md
    └── ...
```

## How to Write Requirement Memos

Free-form writing is fine, but including the following information improves AI output quality:

- **What you want to build** (feature overview)
- **Who will use it** (target users)
- **Why it's needed** (background and purpose)
- **Constraints and conditions** (technical constraints, deadlines, priorities)

Bullet points, rough notes, or transcribed meeting notes are all acceptable. AI will structure them.

## File Naming Convention

```text
REQ_<sequential-number>_<feature-name>.md
```

Examples: `REQ_001_user-auth.md`, `REQ_002_dashboard.md`
