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

### Using PowerShell Backport MCP Server (Preferred)

**PREFERRED METHOD**: Use the PowerShell Backport MCP server tools for label management.

#### Transition from Consider to Migrated

```
# MCP Tool Call (not a PowerShell command)
mcp_powershell_ba_Set_PRBackportMigrated -PRNumber 26193 -Version "7.4"
```

This automatically:
- Removes `Backport-7.4.x-Consider` label
- Adds `Backport-7.4.x-Migrated` label

#### Add Labels

```
# MCP Tool Calls (not PowerShell commands)
mcp_powershell_ba_Add_PRLabel -PRNumber 26193 -Labels @("Backport-7.4.x-Done")

# Add multiple labels
mcp_powershell_ba_Add_PRLabel -PRNumber 26193 -Labels @("Backport-7.4.x-Done", "CL-BuildPackaging")
```

#### Remove Labels

```
# MCP Tool Calls (not PowerShell commands)
mcp_powershell_ba_Remove_PRLabel -PRNumber 26193 -Labels @("Backport-7.4.x-Migrated")

# Remove multiple labels
mcp_powershell_ba_Remove_PRLabel -PRNumber 26193 -Labels @("Backport-7.4.x-Consider", "Backport-7.4.x-Migrated")
```

### Fallback: GitHub CLI Commands

**If MCP server unavailable**, use GitHub CLI commands as documented in: `.github/instructions/backports/gh-cli-fallback.instructions.md`

## Agent and Copilot Label Usage

**IMPORTANT RESTRICTIONS**:
- **NEVER** add or remove `Backport-*-Approved` labels (maintainer-only)
- **CAN** add or remove `Backport-*-Done` labels (maintainer-only, added after merge)
- **CAN** add `Backport-*-Migrated` and remove `Backport-*-Consider` when creating backport PRs
- **CAN** add CL labels to backport PRs

These labels are applied to **original PRs only**, not to backport PRs themselves. Backport PRs receive CL labels but not backport state labels.

## Best Practices

### When Creating Backport PR

1. **Update original PR labels** (use MCP server):
   ```
   # MCP Tool Call (not a PowerShell command)
   mcp_powershell_ba_Set_PRBackportMigrated -PRNumber <original-pr> -Version "<version>"
   ```

2. **Add CL label to backport PR** (use MCP server):
   ```
   # MCP Tool Call (not a PowerShell command)
   mcp_powershell_ba_Add_PRLabel -PRNumber <backport-pr> -Labels @("<original-cl-label>")
   ```

**Fallback to GitHub CLI** if MCP server unavailable (see `.github/instructions/backports/gh-cli-fallback.instructions.md`)

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

```
# Original PR has: Backport-7.4.x-Consider
# After creating backport PR (agents/Copilot CAN do this):

# MCP Tool Call (not a PowerShell command)
mcp_powershell_ba_Set_PRBackportMigrated -PRNumber 26193 -Version "7.4"
```

**Note**: If original PR has `Backport-7.4.x-Approved`, only maintainers should transition it to `Migrated` by removing the `Approved` label.

### Scenario 2: Backport PR Failed/Rejected

```
# MCP Tool Calls (not PowerShell commands)
mcp_powershell_ba_Remove_PRLabel -PRNumber 26193 -Labels @("Backport-7.4.x-Migrated")
mcp_powershell_ba_Add_PRLabel -PRNumber 26193 -Labels @("Backport-7.4.x-Consider")
```

### Scenario 3: Backport No Longer Needed

```
# MCP Tool Call (not a PowerShell command)
mcp_powershell_ba_Remove_PRLabel -PRNumber 26193 -Labels @("Backport-7.4.x-Consider")
```

### Scenario 4: Checking Backport Status

```powershell
# MCP Tool Call (not a regular PowerShell command)
$prInfo = mcp_powershell_ba_Get_PRBackportInfo -PRNumber 26193
$prInfo.BackportLabels

# Output example:
# Backport-7.4.x-Done
# Backport-7.5.x-Migrated
# Backport-7.3.x-Consider
```

## Related Resources

- Backport process: `.github/instructions/backports/backport-process.instructions.md`
- GitHub CLI usage: `.github/instructions/backports/gh-cli-usage.instructions.md`
- Release tools: `tools/releaseTools.psm1`
