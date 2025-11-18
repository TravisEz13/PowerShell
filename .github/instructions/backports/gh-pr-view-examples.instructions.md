````instructions
---
applyTo:
  - "tools/releaseTools.psm1"
  - ".github/prompts/backport-pr-to-release-branch*.prompt.md"
  - ".github/agents/backport-agent.md"
---

# GitHub CLI PR View Examples

## Overview

Examples and patterns for using `gh pr view` to retrieve PR information for backport operations.

## Getting PR Information

### Using PowerShell Backport MCP Server (PREFERRED)

```powershell
# MCP Tool Call (not a regular PowerShell command)
$prInfo = mcp_powershell_ba_Get_PRBackportInfo -PRNumber 26193

# Standard PowerShell for accessing fields
$prInfo.PRNumber        # PR number
$prInfo.Title           # PR title  
$prInfo.State           # MERGED, OPEN, CLOSED
$prInfo.Author          # Author username
$prInfo.Url             # PR URL
$prInfo.BackportLabels  # All backport labels (e.g., ["BackPort-7.6.x-Consider"])
$prInfo.ChangelogLabels # CL labels (e.g., ["CL-BuildPackaging"])
$prInfo.LinkedPRs       # Dependent PR numbers (e.g., [25837])
```

### Using GitHub CLI (FALLBACK)

```powershell
# Get comprehensive PR information
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,title,state,mergeCommit,author,labels,body,url `
    | ConvertFrom-Json

# Access specific fields
$pr.number          # PR number
$pr.title           # PR title
$pr.state           # OPEN, CLOSED, MERGED
$pr.mergeCommit.oid # Merge commit SHA
$pr.author.login    # Author username
$pr.labels          # Array of labels
$pr.body            # PR description
$pr.url             # PR URL
```

### Extract CL Label

```powershell
# Get changelog label from PR
$clLabel = $pr.labels |
    Where-Object { $_.name -like "CL-*" } |
    Select-Object -First 1 -ExpandProperty name

# Common CL labels:
# - CL-BuildPackaging
# - CL-Engine
# - CL-General
# - CL-Cmdlets-Utility
```

### Get PR Diff

```powershell
# Save PR diff to file for analysis
gh pr diff 26193 --repo PowerShell/PowerShell | Out-File pr-26193.diff

# View diff directly
gh pr diff 26193 --repo PowerShell/PowerShell | more
```

## Field Selection Examples

### Minimal PR Info

```powershell
# Get only essential fields
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,title,state `
    | ConvertFrom-Json
```

### PR with Merge Commit

```powershell
# Get PR with merge commit SHA
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,title,mergeCommit `
    | ConvertFrom-Json

# Extract full and short commit hash
$fullHash = $pr.mergeCommit.oid
$shortHash = $fullHash.Substring(0, 9)
```

### PR with Author Info

```powershell
# Get PR with author details
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,title,author `
    | ConvertFrom-Json

# Access author fields
$pr.author.login    # Username
$pr.author.name     # Display name
$pr.author.is_bot   # Boolean - is this a bot account?
```

### PR with Labels

```powershell
# Get PR with all labels
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,labels `
    | ConvertFrom-Json

# Filter for specific label types
$backportLabels = $pr.labels | Where-Object { $_.name -like "Backport-*" }
$clLabels = $pr.labels | Where-Object { $_.name -like "CL-*" }
```

### PR with Base and Head Branches

```powershell
# Get PR with branch information
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,baseRefName,headRefName `
    | ConvertFrom-Json

$pr.baseRefName  # Target branch (e.g., "master", "release/v7.4")
$pr.headRefName  # Source branch
```

## Verification Examples

### Verify PR is Merged

```powershell
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json state `
    | ConvertFrom-Json

if ($pr.state -ne "MERGED") {
    Write-Error "PR #26193 is not merged (current state: $($pr.state))"
    return
}
```

### Check for Specific Label

```powershell
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json labels `
    | ConvertFrom-Json

$hasBackportLabel = $pr.labels | 
    Where-Object { $_.name -eq "Backport-7.4.x-Consider" } |
    Measure-Object |
    Select-Object -ExpandProperty Count -eq 1

if ($hasBackportLabel) {
    Write-Output "PR is marked for backport consideration"
}
```

### Verify Base Branch

```powershell
# Verify backport PR is targeting correct release branch
$pr = gh pr view 26389 `
    --repo PowerShell/PowerShell `
    --json baseRefName `
    | ConvertFrom-Json

if ($pr.baseRefName -ne "release/v7.4") {
    Write-Warning "PR base branch is $($pr.baseRefName), expected release/v7.4"
}
```

## Complete Workflow Examples

### Extract All Backport Information

```powershell
# Get all information needed for backport
$pr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,title,state,mergeCommit,author,labels,url `
    | ConvertFrom-Json

# Validate state
if ($pr.state -ne "MERGED") {
    throw "PR #$($pr.number) is not merged"
}

# Extract commit hashes
$fullHash = $pr.mergeCommit.oid
$shortHash = $fullHash.Substring(0, 9)

# Extract CL label
$clLabel = $pr.labels |
    Where-Object { $_.name -like "CL-*" } |
    Select-Object -First 1 -ExpandProperty name

# Extract backport labels
$backportLabels = $pr.labels |
    Where-Object { $_.name -like "Backport-*" } |
    Select-Object -ExpandProperty name

# Display summary
Write-Output @"
PR #$($pr.number): $($pr.title)
Author: $($pr.author.login)
State: $($pr.state)
Merge Commit: $shortHash (full: $fullHash)
CL Label: $clLabel
Backport Labels: $($backportLabels -join ', ')
URL: $($pr.url)
"@
```

### Check for Existing Backport PR

```powershell
# Get original PR title
$originalPr = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json title `
    | ConvertFrom-Json

# Search for existing backport
$searchTitle = "[release/v7.4] $($originalPr.title)"
$existingBackports = gh pr list `
    --repo PowerShell/PowerShell `
    --search "in:title `"$searchTitle`"" `
    --state all `
    --json number,title,state,url `
    | ConvertFrom-Json

if ($existingBackports.Count -gt 0) {
    Write-Warning "Found existing backport PR(s):"
    $existingBackports | ForEach-Object {
        Write-Output "  PR #$($_.number) ($($_.state)): $($_.url)"
    }
}
```

## Error Handling

### PR Not Found

```powershell
try {
    $pr = gh pr view 99999999 `
        --repo PowerShell/PowerShell `
        --json number `
        2>&1 | ConvertFrom-Json
} catch {
    Write-Error "PR not found or access denied: $_"
}
```

### Invalid JSON Response

```powershell
$prJson = gh pr view 26193 `
    --repo PowerShell/PowerShell `
    --json number,title

try {
    $pr = $prJson | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse PR JSON: $_"
    Write-Output "Raw response: $prJson"
}
```

## Best Practices

1. **Always specify `--repo`**: Don't rely on default repository detection
2. **Always convert to PowerShell objects**: Use `| ConvertFrom-Json` for easier manipulation
3. **Request only needed fields**: Use `--json` with specific field list to reduce response size
4. **Handle errors gracefully**: Check for null/empty responses and state validation
5. **Use MCP server when available**: Provides comprehensive information in a single call
6. **Cache PR info**: Store in variable to avoid repeated API calls

## Related Resources

- GitHub CLI usage: `.github/instructions/backports/gh-cli-usage.instructions.md`
- Label system: `.github/instructions/backports/label-system.instructions.md`
- Backport process: `.github/instructions/backports/backport-process.instructions.md`

````