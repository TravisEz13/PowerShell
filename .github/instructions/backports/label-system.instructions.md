---
applyTo:
  - "tools/releaseTools.psm1"
  - ".github/prompts/backport-pr-to-release-branch*.prompt.md"
  - ".github/agents/backport-agent.md"
---

# Backport Label System

## Overview

The PowerShell repository uses a label-based system to track backport status for merged PRs.

## Label Pattern

Format: `Backport-<version>.x-<state>`

**Version examples**:
- `7.4` → `Backport-7.4.x-*`
- `7.5` → `Backport-7.5.x-*`
- `7.3` → `Backport-7.3.x-*`

## Label States

### Consider
**Label**: `Backport-7.4.x-Consider`

**Meaning**: PR is being evaluated for backporting to the release

**Usage**:
- Applied manually by maintainers during triage
- Indicates the change might be appropriate for the release
- Requires approval before backporting

**Next steps**: Review, then either approve or reject

### Approved
**Label**: `Backport-7.4.x-Approved`

**Meaning**: PR has been approved for merging into the release branch

**Usage**:
- **MAINTAINER-ONLY**: Applied by maintainers after review
- **DO NOT USE**: Agents and Copilot should NEVER add or remove this label
- Triggers automated backport bot (if applicable)
- Indicates high priority for backporting

**Next steps**: Backport should be created (manually or automatically)

### Migrated
**Label**: `Backport-7.4.x-Migrated`

**Meaning**: A backport PR has been created

**Usage**:
- Applied when backport PR is created
- Indicates work is in progress
- Does NOT mean the backport is merged yet

**Next steps**: Backport PR needs review and merge

### Done
**Label**: `Backport-7.4.x-Done`

**Meaning**: Backport PR has been merged

**Usage**:
- Applied after backport PR is merged
- Indicates the change is now in the release branch
- Final state for backport tracking

**Next steps**: None - backport is complete

## Label Workflow

### Typical Flow

```
1. PR merged to main
   ↓
2. Maintainer adds: Backport-7.4.x-Consider
   ↓
4. Backport PR created
   Maintainer adds: Backport-7.4.x-Migrated
   (removes: Backport-7.4.x-Consider)
   ↓
5. Backport PR merged
   Maintainer adds: Backport-7.4.x-Done
   (removes: Backport-7.4.x-Migrated)
```

### Multiple Version Backports

A single PR can be backported to multiple versions:

```
Original PR #26193 labels:
- Backport-7.4.x-Migrated
- Backport-7.5.x-Done
- Backport-7.3.x-Consider
```

Each version has independent state tracking.

## Label Management Commands

### Adding Labels

```powershell
# Mark for consideration
gh pr edit 26193 --add-label "Backport-7.4.x-Consider" --repo PowerShell/PowerShell

# Approve for backport
gh pr edit 26193 --add-label "Backport-7.4.x-Migrated" --remove-label "Backport-7.4.x-Consider" --repo PowerShell/PowerShell

# Mark as migrated (backport PR created)
gh pr edit 26193 --add-label "Backport-7.4.x-Migrated" --remove-label "Backport-7.4.x-Migrated" --repo PowerShell/PowerShell

# Mark as done (backport PR merged)
gh pr edit 26193 --add-label "Backport-7.4.x-Done" --remove-label "Backport-7.4.x-Migrated" --repo PowerShell/PowerShell
```

### Querying by Label

```powershell
# Find all PRs needing backport consideration
gh pr list --repo PowerShell/PowerShell --label "Backport-7.4.x-Consider" --state merged

# Find all approved backports
gh pr list --repo PowerShell/PowerShell --label "Backport-7.4.x-Approved" --state merged

# Find all in-progress backports
gh pr list --repo PowerShell/PowerShell --label "Backport-7.4.x-Migrated" --state merged

# Find all completed backports
gh pr list --repo PowerShell/PowerShell --label "Backport-7.4.x-Done" --state merged
```

## Changelog (CL) Labels

In addition to backport labels, PRs should have a changelog label that gets copied to the backport PR.

### Common CL Labels

- `CL-BuildPackaging` - Build, packaging, or infrastructure changes
- `CL-Engine` - PowerShell engine changes
- `CL-General` - General improvements
- `CL-Cmdlets-Utility` - Utility cmdlet changes
- `CL-Cmdlets-Management` - Management cmdlet changes
- `CL-BreakingChange` - Breaking changes (rare in backports)

### CL Label Workflow

```powershell
# Extract CL label from original PR
$pr = gh pr view 26193 --repo PowerShell/PowerShell --json labels | ConvertFrom-Json
$clLabel = $pr.labels | Where-Object { $_.name -like "CL-*" } | Select-Object -First 1 -ExpandProperty name

# Add to backport PR
gh pr edit 26389 --add-label $clLabel --repo PowerShell/PowerShell
```

## Agent and Copilot Label Usage

**IMPORTANT RESTRICTIONS**:
- **NEVER** add or remove `Backport-*-Approved` labels (maintainer-only)
- **CAN** add or remove `Backport-*-Done` labels (maintainer-only, added after merge)
- **CAN** add `Backport-*-Migrated` and remove `Backport-*-Consider` when creating backport PRs
- **CAN** add CL labels to backport PRs

These labels are applied to **original PRs only**, not to backport PRs themselves. Backport PRs receive CL labels but not backport state labels.

## Best Practices

### When Creating Backport PR

1. **Update original PR labels**:
   ```powershell
   gh pr edit <original-pr> --add-label "Backport-X.X.x-Migrated" --remove-label "Backport-X.X.x-Consider" --repo PowerShell/PowerShell
   ```

2. **Add CL label to backport PR**:
   ```powershell
   gh pr edit <backport-pr> --add-label "<original-cl-label>" --repo PowerShell/PowerShell
   ```

### When Backport PR Merges

Maintainer should update:
```powershell
gh pr edit <original-pr> --add-label "Backport-X.X.x-Done" --remove-label "Backport-X.X.x-Migrated" --repo PowerShell/PowerShell
```

## Reporting and Tracking

### Using tools/releaseTools.psm1

```powershell
Import-Module ./tools/releaseTools.psm1

# Get report of approved backports
Get-PRBackportReport -Version 7.4 -TriageState Approved

# Get report of completed backports
Get-PRBackportReport -Version 7.4 -TriageState Done

# Open in browser
Get-PRBackportReport -Version 7.4 -TriageState Approved -Web
```

## Common Scenarios

### Scenario 1: Manual Backport of Consider PR

```powershell
# Original PR has: Backport-7.4.x-Consider
# After creating backport PR (agents/Copilot CAN do this):

gh pr edit 26193 --add-label "Backport-7.4.x-Migrated" --remove-label "Backport-7.4.x-Consider" --repo PowerShell/PowerShell
```

**Note**: If original PR has `Backport-7.4.x-Approved`, only maintainers should transition it to `Migrated` by removing the `Approved` label.

### Scenario 2: Backport PR Failed/Rejected

```powershell
# Remove Migrated, add back Consider for re-evaluation
gh pr edit 26193 --add-label "Backport-7.4.x-Consider" --remove-label "Backport-7.4.x-Migrated" --repo PowerShell/PowerShell
```

### Scenario 3: Backport No Longer Needed

```powershell
# Remove all backport labels for that version
gh pr edit 26193 --remove-label "Backport-7.4.x-Consider" --repo PowerShell/PowerShell
```

### Scenario 4: Checking Backport Status

```powershell
# Get all backport labels for a PR
$pr = gh pr view 26193 --repo PowerShell/PowerShell --json labels | ConvertFrom-Json
$pr.labels | Where-Object { $_.name -like "Backport-*" } | Select-Object -ExpandProperty name

# Output example:
# Backport-7.4.x-Done
# Backport-7.5.x-Migrated
# Backport-7.3.x-Consider
```

## Related Resources

- Backport process: `.github/instructions/backports/backport-process.instructions.md`
- GitHub CLI usage: `.github/instructions/backports/gh-cli-usage.instructions.md`
- Release tools: `tools/releaseTools.psm1`
