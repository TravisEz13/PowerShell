````instructions
---
applyTo:
  - "tools/releaseTools.psm1"
  - ".github/prompts/backport-pr-to-release-branch*.prompt.md"
  - ".github/agents/backport-agent.md"
---

# GitHub CLI Fallback for Backport Operations

## Overview

This document provides GitHub CLI commands as a fallback when the PowerShell Backport MCP server is unavailable.

**IMPORTANT**: The MCP server is the preferred method. Use these GitHub CLI commands only when:
- MCP server is not configured
- MCP server is experiencing issues
- Working in an environment without MCP server access

For MCP server usage, see:
- `.github/instructions/backports/backport-process.instructions.md`
- `.github/instructions/backports/label-system.instructions.md`
- `.github/instructions/backports/mcp-integration.instructions.md`

## Prerequisites

### Install GitHub CLI

- **Version required**: 2.17 or later
- **Download**: https://cli.github.com/
- **Verify installation**:
  ```powershell
  gh --version
  ```

### Authenticate

```powershell
gh auth login
```

Follow prompts to authenticate with GitHub.

### Verify Authentication

```powershell
gh auth status
```

## Label Management Commands

### Adding Labels

```powershell
# Add single label
gh pr edit 26193 --add-label "Backport-7.4.x-Migrated" --repo PowerShell/PowerShell

# Add multiple labels
gh pr edit 26193 `
    --add-label "Backport-7.4.x-Migrated" `
    --add-label "CL-BuildPackaging" `
    --repo PowerShell/PowerShell
```

### Removing Labels

```powershell
# Remove single label
gh pr edit 26193 --remove-label "Backport-7.4.x-Consider" --repo PowerShell/PowerShell

# Remove multiple labels
gh pr edit 26193 `
    --remove-label "Backport-7.4.x-Consider" `
    --remove-label "Backport-7.4.x-Approved" `
    --repo PowerShell/PowerShell
```

### Add and Remove in Single Command

```powershell
# Transition from Consider to Migrated
gh pr edit 26193 `
    --add-label "Backport-7.4.x-Migrated" `
    --remove-label "Backport-7.4.x-Consider" `
    --repo PowerShell/PowerShell

# Mark as done after backport merges
gh pr edit 26193 `
    --add-label "Backport-7.4.x-Done" `
    --remove-label "Backport-7.4.x-Migrated" `
    --repo PowerShell/PowerShell
```

## Getting PR Information

### View PR Details

```powershell
# Get basic PR information
gh pr view 26193 --repo PowerShell/PowerShell

# Get PR information as JSON
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,title,state,mergeCommit,author,labels | ConvertFrom-Json

# Access specific fields
$pr.number
$pr.title
$pr.state
$pr.mergeCommit.oid
$pr.author.login
```

### Extract Specific Labels

```powershell
# Get all backport labels
$pr = gh pr view 26193 --repo PowerShell/PowerShell --json labels | ConvertFrom-Json
$backportLabels = $pr.labels | Where-Object { $_.name -like "Backport-*" } | Select-Object -ExpandProperty name

# Get CL label
$clLabel = $pr.labels | Where-Object { $_.name -like "CL-*" } | Select-Object -First 1 -ExpandProperty name
```

### Check PR State

```powershell
# Verify PR is merged
$pr = gh pr view 26193 --repo PowerShell/PowerShell --json state | ConvertFrom-Json
if ($pr.state -ne "MERGED") {
    throw "PR #26193 is not merged (state: $($pr.state))"
}
```

## Finding PRs to Backport

### List PRs with Backport Labels

```powershell
# List PRs needing backport to v7.4
gh pr list `
    --repo PowerShell/PowerShell `
    --label "Backport-7.4.x-Consider" `
    --state merged `
    --json number,title,mergedAt,url,labels `
    --limit 50

# Convert to PowerShell objects and sort
$prs = gh pr list `
    --repo PowerShell/PowerShell `
    --label "Backport-7.4.x-Consider" `
    --state merged `
    --json number,title,mergedAt,url,labels `
    --limit 50 | ConvertFrom-Json

$prs | Sort-Object mergedAt | Select-Object number, title, mergedAt
```

### Check for Existing Backport PRs

```powershell
# Search for existing backport PRs
gh pr list `
    --repo PowerShell/PowerShell `
    --search "in:title [release/v7.4]" `
    --state all `
    --json number,title,state,url

# Search for specific PR backport
$originalTitle = "GitHub Workflow cleanup"
gh pr list `
    --repo PowerShell/PowerShell `
    --search "in:title [release/v7.4] $originalTitle" `
    --state all
```

## Creating Backport PRs

**IMPORTANT**: The PowerShell Backport MCP Server provides `mcp_powershell_ba_New_BackportPR` for creating backport PRs with proper formatting. Use that as the primary method. This section is for fallback when MCP server is unavailable.

See `mcp-integration.instructions.md` and `backport-process.instructions.md` for MCP server usage.

### Basic PR Creation (Fallback)

**CRITICAL**: Always specify `--base` when creating a backport PR to ensure it targets the correct release branch.

```powershell
# Prepare PR body (use here-string for multi-line)
# See pr-template.instructions.md for full template
$prBody = @"
Backport of #26193 to release/v7.4

Triggered by @username on behalf of @originalauthor
Original CL Label: CL-BuildPackaging
/cc @PowerShell/powershell-maintainers

[Add Impact, Regression, Testing, and Risk sections - see pr-template.instructions.md]
"@

# Create PR with --base to target the release branch directly
gh pr create `
    --title "[release/v7.4] GitHub Workflow cleanup" `
    --body $prBody `
    --base release/v7.4 `
    --repo PowerShell/PowerShell `
    --head myusername:backport-branch-name
```

### Create PR and Capture Response

```powershell
# Capture PR number/URL from creation
$prUrl = gh pr create `
    --title "[release/v7.4] GitHub Workflow cleanup" `
    --body $prBody `
    --base release/v7.4 `
    --repo PowerShell/PowerShell `
    --head myusername:backport-branch-name

# Extract PR number from URL
$prNumber = $prUrl -replace '.*/', ''

# Or use JSON output
$newPr = gh pr create `
    --title "[release/v7.4] GitHub Workflow cleanup" `
    --body $prBody `
    --base release/v7.4 `
    --repo PowerShell/PowerShell `
    --head myusername:backport-branch-name `
    --json number,url | ConvertFrom-Json

$newPr.number  # New PR number
$newPr.url     # New PR URL
```

## Complete Workflow Example

```powershell
# 1. Get original PR details
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,title,state,mergeCommit,author,labels | ConvertFrom-Json

# 2. Verify it's merged
if ($pr.state -ne "MERGED") {
    throw "PR #$($pr.number) is not merged"
}

# 3. Extract CL label
$clLabel = $pr.labels |
    Where-Object { $_.name -like "CL-*" } |
    Select-Object -First 1 -ExpandProperty name

# 4. Get current GitHub user
$currentUser = gh api user --jq .login

# 5. Build PR body (see pr-template.instructions.md for complete format)
$version = "7.4"
$prBody = @"
Backport of #$($pr.number) to release/v$version

Triggered by @$currentUser on behalf of @$($pr.author.login)
Original CL Label: $clLabel
/cc @PowerShell/powershell-maintainers

[Add Impact, Regression, Testing, and Risk sections - see pr-template.instructions.md]
"@

# 6. Create PR with --base to target release branch (assumes backport branch is ready)
$newPr = gh pr create `
    --title "[release/v$version] $($pr.title)" `
    --body $prBody `
    --base "release/v$version" `
    --repo PowerShell/PowerShell `
    --json number,url | ConvertFrom-Json

Write-Output "Created PR #$($newPr.number): $($newPr.url)"

# 7. Add CL label to new PR
if ($clLabel) {
    gh pr edit $newPr.number `
        --add-label $clLabel `
        --repo PowerShell/PowerShell
}

# 8. Update original PR labels
gh pr edit $pr.number `
    --add-label "Backport-$version.x-Migrated" `
    --remove-label "Backport-$version.x-Consider" `
    --repo PowerShell/PowerShell

Write-Output "Backport complete! PR #$($newPr.number) ready for review"
```

## Common Scenarios Using GitHub CLI

### Scenario 1: Transition Consider to Migrated

```powershell
gh pr edit 26193 `
    --add-label "Backport-7.4.x-Migrated" `
    --remove-label "Backport-7.4.x-Consider" `
    --repo PowerShell/PowerShell
```

### Scenario 2: Mark Backport as Done

```powershell
gh pr edit 26193 `
    --add-label "Backport-7.4.x-Done" `
    --remove-label "Backport-7.4.x-Migrated" `
    --repo PowerShell/PowerShell
```

### Scenario 3: Add CL Label to Backport PR

```powershell
# Get CL label from original PR
$originalPr = gh pr view 26193 --repo PowerShell/PowerShell --json labels | ConvertFrom-Json
$clLabel = $originalPr.labels | Where-Object { $_.name -like "CL-*" } | Select-Object -First 1 -ExpandProperty name

# Add to backport PR
gh pr edit 26389 --add-label $clLabel --repo PowerShell/PowerShell
```

### Scenario 4: Backport Failed - Revert to Consider

```powershell
gh pr edit 26193 `
    --add-label "Backport-7.4.x-Consider" `
    --remove-label "Backport-7.4.x-Migrated" `
    --repo PowerShell/PowerShell
```

## Troubleshooting

### "gh: command not found"
Install GitHub CLI from https://cli.github.com/

### "Not authenticated"
Run `gh auth login` and follow prompts

### "Could not resolve to a Repository"
Ensure you're using correct repository format: `PowerShell/PowerShell`

### "Resource not accessible by integration"
Verify you have necessary permissions for the repository

### "Error creating pull request"
- Check that head branch exists and is pushed
- Verify you're not creating a duplicate PR
- Ensure title and body are properly formatted

## When to Use MCP Server Instead

Consider switching to the MCP server when:
- You're performing frequent backport operations
- You need to check backport status across multiple PRs
- You want to reduce the number of GitHub API calls
- You need comprehensive PR information in one call
- The MCP server becomes available in your environment

See `.github/instructions/backports/mcp-integration.instructions.md` for setup instructions.

## Related Resources

- MCP Server Integration: `.github/instructions/backports/mcp-integration.instructions.md`
- Backport Process: `.github/instructions/backports/backport-process.instructions.md`
- Label System: `.github/instructions/backports/label-system.instructions.md`
- GitHub CLI Full Usage: `.github/instructions/backports/gh-cli-usage.instructions.md`

````
