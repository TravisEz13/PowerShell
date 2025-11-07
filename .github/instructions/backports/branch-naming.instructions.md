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

## Branch Naming Guidelines

1. **Use descriptive postfixes** when needed:
   - `retry` - Second or third attempt
   - `conflict-resolution` - Manual conflict resolution required
   - `manual` - Manual backport due to bot failure

2. **Keep it concise**: Branch names should be clear but not overly long

3. **Use hyphens**: Separate parts with hyphens (kebab-case)

## Special Cases

### Agent-Assigned Branches

When using GitHub Copilot agents or similar automation:
- The branch name is pre-assigned by the system
- Do not create new branches
- Work directly on the assigned branch
- Branch may not follow the standard naming convention

### Multiple Backport Attempts

If a backport needs to be retried:
- Add a postfix: `backport-26193-retry`
- Document reason for retry in PR description
- Close the previous backport PR if it exists
