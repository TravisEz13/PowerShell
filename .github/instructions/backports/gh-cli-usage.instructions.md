---
applyTo:
  - "tools/releaseTools.psm1"
  - ".github/prompts/backport-pr-to-release-branch*.prompt.md"
  - ".github/agents/backport-agent.md"
---

# GitHub CLI for Backport PR Creation

## Overview

**Note**: For branch naming conventions, see `.github/instructions/backports/branch-naming.instructions.md`. Examples in this document use `<backport-branch-name>` as a generic placeholder.

Guidelines for using GitHub CLI (`gh`) to create and manage backport PRs.

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

### Check for Existing Backports

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

## Getting PR Information

For detailed examples of using `gh pr view` to retrieve PR information, see: `.github/instructions/backports/gh-pr-view-examples.instructions.md`

### Quick Reference

```powershell
# Get comprehensive PR information
$pr = gh pr view <pr-number> `
    --repo PowerShell/PowerShell `
    --json number,title,state,mergeCommit,author,labels,url `
    | ConvertFrom-Json

# Get PR diff
gh pr diff <pr-number> --repo PowerShell/PowerShell | Out-File pr-diff.txt
```

## Creating Backport PRs

### Basic PR Creation

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
# Note: Use the branch name from branch-naming.instructions.md
gh pr create `
    --title "[release/v7.4] GitHub Workflow cleanup" `
    --body $prBody `
    --base release/v7.4 `
    --repo PowerShell/PowerShell `
    --head myusername:<backport-branch-name>
```

### Create PR and Capture Response

```powershell
# Capture PR number/URL from creation
# ALWAYS include --base to target the correct release branch
$prUrl = gh pr create `
    --title "[release/v7.4] GitHub Workflow cleanup" `
    --body $prBody `
    --base release/v7.4 `
    --repo PowerShell/PowerShell `
    --head myusername:<backport-branch-name>

# Extract PR number from URL
$prNumber = $prUrl -replace '.*/', ''

# Or use JSON output
$newPr = gh pr create `
    --title "[release/v7.4] GitHub Workflow cleanup" `
    --body $prBody `
    --base release/v7.4 `
    --repo PowerShell/PowerShell `
    --head myusername:<backport-branch-name> `
    --json number,url | ConvertFrom-Json

$newPr.number  # New PR number
$newPr.url     # New PR URL
```

## Updating PR Base Branch

### Setting Base Branch During Creation (Preferred Method)

**BEST PRACTICE**: Always use `--base` parameter when creating a backport PR to directly target the release branch. This avoids the need for a separate edit step.

```powershell
# Preferred: Set base during creation
gh pr create `
    --title "[release/v7.4] GitHub Workflow cleanup" `
    --body $prBody `
    --base release/v7.4 `
    --repo PowerShell/PowerShell `
    --head myusername:<backport-branch-name>
```

### Fallback: Update Base After Creation

If you forgot to set `--base` during creation, you can update it afterwards:

```powershell
# Update base branch after creation (only if you forgot --base)
gh pr edit 26389 `
    --base release/v7.4 `
    --repo PowerShell/PowerShell
```

### Verify Base Branch

```powershell
# Check PR details including base
$pr = gh pr view 26389 `
    --repo PowerShell/PowerShell `
    --json number,title,baseRefName,headRefName | ConvertFrom-Json

$pr.baseRefName  # Should be: release/v7.4
$pr.headRefName  # Your branch name
```

## Managing PR Labels

### Add Labels

```powershell
# Add single label
gh pr edit 26389 `
    --add-label "CL-BuildPackaging" `
    --repo PowerShell/PowerShell

# Add multiple labels
gh pr edit 26389 `
    --add-label "CL-BuildPackaging" `
    --add-label "Review - Committee" `
    --repo PowerShell/PowerShell
```

### Remove Labels

```powershell
# Remove single label
gh pr edit 26193 `
    --remove-label "Backport-7.4.x-Consider" `
    --repo PowerShell/PowerShell

# Remove multiple labels
gh pr edit 26193 `
    --remove-label "Backport-7.4.x-Consider" `
    --remove-label "Backport-7.4.x-Approved" `
    --repo PowerShell/PowerShell
```

### Add and Remove in Single Command

```powershell
# Update backport status labels
gh pr edit 26193 `
    --add-label "Backport-7.4.x-Migrated" `
    --remove-label "Backport-7.4.x-Consider" `
    --repo PowerShell/PowerShell
```

## Complete Workflow Example

### For Standard Manual Backport

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

# 5. Build PR body
# See pr-template.instructions.md for complete template format
$version = "7.4"
$prBody = @"
Backport of #$($pr.number) to release/v$version

Triggered by @$currentUser on behalf of @$($pr.author.login)
Original CL Label: $clLabel
/cc @PowerShell/powershell-maintainers

[Add Impact, Regression, Testing, and Risk sections - see pr-template.instructions.md]
"@

# 6. Create PR with --base to target release branch (assumes you're on backport branch and pushed)
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

### For Agent-Based Backport

```powershell
# Agent workflow - assumes branch is already prepared
$pr = gh pr view 26193 --repo PowerShell/PowerShell --json number,title,mergeCommit,author,labels | ConvertFrom-Json
$clLabel = $pr.labels | Where-Object { $_.name -like "CL-*" } | Select-Object -First 1 -ExpandProperty name
$currentUser = gh api user --jq .login

# Create PR body (see pr-template.instructions.md for complete format)
$prBody = @"
Backport of #$($pr.number) to release/v7.4

Triggered by @$currentUser on behalf of @$($pr.author.login)
Original CL Label: $clLabel
/cc @PowerShell/powershell-maintainers

[Add Impact, Regression, Testing, and Risk sections]
"@

# Create PR with --base to target release/v7.4 directly
$newPr = gh pr create --title "[release/v7.4] $($pr.title)" --body $prBody --base release/v7.4 --repo PowerShell/PowerShell --json number | ConvertFrom-Json

# Add labels
gh pr edit $newPr.number --add-label $clLabel --repo PowerShell/PowerShell
gh pr edit $pr.number --add-label "Backport-7.4.x-Migrated" --remove-label "Backport-7.4.x-Consider" --repo PowerShell/PowerShell
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

## Best Practices

1. **Always specify `--base` when creating PRs**: Set the target release branch during creation, not as a separate edit step
2. **Always convert to PowerShell objects**: Use `| ConvertFrom-Json` for easier manipulation
3. **Use `--repo` explicitly**: Don't rely on default repository detection
4. **Capture PR creation output**: Store new PR number for subsequent operations
5. **Use here-strings for PR body**: Makes multi-line content easier to manage
6. **Verify operations**: Check PR state after edits with `gh pr view`
