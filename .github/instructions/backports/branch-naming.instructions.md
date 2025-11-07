---
applyTo:
  - "tools/releaseTools.psm1"
  - ".github/prompts/backport-pr-to-release-branch*.prompt.md"
  - ".github/agents/backport-agent.md"
---

# Backport Branch Naming Conventions

## Overview

Branch naming conventions for backporting PRs in the PowerShell repository.

## Automated Bot Branches

**Format**: `backport/release/v<version>/<pr-number>-<short-commit-hash>`

**Examples**:
- `backport/release/v7.4/26193-4aff02475`
- `backport/release/v7.5/23456-abc123def`

**When used**: Created automatically by the PowerShell repository's backport bot (pwshBot).

## Manual Backport Branches

**Format**: `backport/release/v<version>/<pr-number>-<short-commit-hash>`

**Examples**:
- `backport/release/v7.4/26398-e7bf5621b`
- `backport/release/v7.5/23456-abc123def`

**When used**: Manual backports should follow the same format as automated bot branches for consistency.

## Branch Naming Guidelines

1. **Always include the commit hash**: Use the first 8-9 characters of the merge commit SHA
2. **Use the full release version**: Include `v` prefix (e.g., `v7.4`, not `7.4`)
3. **Use forward slashes**: Separate parts with forward slashes for hierarchical organization
4. **Match bot format**: Manual backports should be indistinguishable from automated ones

## ❌ Common Mistakes to Avoid

**NEVER use these patterns:**
- ❌ `backport-<pr-number>-to-v<version>` (e.g., `backport-26398-to-v7.4`)
- ❌ `backport-<version>-<pr-number>` (e.g., `backport-7.4-26398`)
- ❌ `<pr-number>-backport` (e.g., `26398-backport`)
- ❌ `backport/<pr-number>` (missing version info)

**Why these are wrong:**
- Missing the hierarchical `release/v<version>` structure
- Not following the repository's established convention
- Won't match automated tooling expectations
- Makes it harder to track which release branch the backport targets

## Format Template

```
backport/release/v<version>/<pr-number>-<short-hash>
└─────┘ └─────┘ └──────┘ └────────┘ └─────────┘
  │       │        │          │           │
  │       │        │          │           └─ First 8-9 chars of merge commit SHA
  │       │        │          └───────────── Original PR number
  │       │        └──────────────────────── Version (with 'v' prefix)
  │       └───────────────────────────────── Literal "release"
  └───────────────────────────────────────── Literal "backport"
```

**Real example breakdown for PR 26398:**
- Merge commit: `e7bf5621b...`
- Target version: `7.4`
- **Correct branch**: `backport/release/v7.4/26398-e7bf5621b`

## Special Cases

### Agent-Assigned Branches

When using GitHub Copilot agents or similar automation:
- The branch name is pre-assigned by the system
- Do not create new branches
- Work directly on the assigned branch
- Branch may not follow the standard naming convention

### Multiple Backport Attempts

If a backport needs to be retried, the hash should be different.
- Document reason for retry in PR description
- Close the previous backport PR if it exists
