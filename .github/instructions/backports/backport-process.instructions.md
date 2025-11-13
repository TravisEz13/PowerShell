---
applyTo:
  - "tools/releaseTools.psm1"
  - ".github/agents/backport-agent.md"
---

# PowerShell Backport Process Instructions

## Overview

Backporting in the PowerShell repository involves applying changes from a merged PR on the main branch to a release branch (e.g., `release/v7.4`, `release/v7.5`). This ensures critical fixes and approved features reach released versions.

## Prerequisites

### CRITICAL: Verify MCP Server Availability First

**BEFORE STARTING ANY BACKPORT**, ensure the PowerShell Backport MCP server is available and activated:

1. **Test MCP server connectivity**:
   ```powershell
   # Try a simple MCP call to verify it's working
   mcp_powershell_ba_Get_PRBackportInfo -PRNumber 26233
   ```

2. **If MCP server is disabled or unavailable**:
   - Check VS Code's MCP settings (`mcp.json`)
   - Verify the MCP server process is running
   - Restart the MCP server if needed
   - Wait for confirmation that tools are available before proceeding

3. **Why this matters**:
   - MCP server creates PRs with properly formatted metadata
   - Without it, you'll need to manually create PRs using GitHub CLI
   - MCP server ensures upstream tracking is set on branches
   - Prevents workflow interruptions mid-backport

**DO NOT PROCEED** with backport workflow until MCP server responds successfully.

## PowerShell Backport MCP Server

**PREFERRED METHOD**: Use the PowerShell Backport MCP server for comprehensive PR information and backport status validation.

### Get PR Backport Information

```powershell
# Get comprehensive backport information for a PR
mcp_powershell_ba_Get_PRBackportInfo -PRNumber <pr-number>
```

**Returns**:
- PR number, title, state, author, URL
- Merge commit SHA (needed for cherry-picking)
- All backport labels (e.g., `BackPort-7.6.x-Consider`)
- Changelog labels (e.g., `CL-BuildPackaging`)
- Linked/dependent PRs

**Example**:
```json
{
  "PRNumber": 26404,
  "Title": "Update PSResourceGet package version to preview4",
  "State": "MERGED",
  "Author": "adityapatwardhan",
  "Url": "https://github.com/PowerShell/PowerShell/pull/26404",
  "MergeCommit": "e5d40dc06de24cf3fe6d6316414673af8aba5d2e",
  "BackportLabels": ["BackPort-7.6.x-Consider"],
  "ChangelogLabels": ["CL-BuildPackaging"],
  "LinkedPRs": []
}
```

### Create Backport Branch

```powershell
# Get PR information first
$prInfo = mcp_powershell_ba_Get_PRBackportInfo -PRNumber <pr-number>

# Create backport branch and cherry-pick commit
$result = mcp_powershell_ba_New_BackportBranch `
    -RepoFullPath $PWD `
    -PRNumber <pr-number> `
    -MergeCommitSHA $prInfo.MergeCommit `
    -TargetBranch "release/v<version>"
```

**What This Tool Does Automatically**:
- ✅ **Fetches latest upstream changes** for the target release branch
- ✅ **Creates properly named branch** following convention: `backport/release/v<version>/<pr-number>-<short-hash>`
- ✅ **Sets up upstream tracking** to the release branch
- ✅ **Cherry-picks the merge commit** from the original PR
- ✅ **Detects merge conflicts** and reports affected files

**Returns**:
```powershell
@{
    BranchName = "backport/release/v7.6/26282-e5d40dc06"
    Success = $true  # or $false if conflicts
    ConflictFiles = @()  # Array of files with conflicts (if any)
    Message = "Successfully created backport branch and cherry-picked commit"
}
```

**If conflicts occur**: The tool will report which files have conflicts. You'll need to:
1. Resolve conflicts manually
2. Stage resolved files: `git add <files>`
3. Continue cherry-pick: `git cherry-pick --continue`
4. See "Handling Merge Conflicts" section below for detailed guidance

### Advantages of MCP Server

- **Single call** gets all required backport information
- **Automated branch creation** handles git operations with proper naming and tracking
- **Conflict detection** automatically identifies merge conflicts
- **Comprehensive status** including all backport labels across versions
- **Dependency detection** via LinkedPRs field
- **Authoritative source** from PowerShell repository data
- **Consistent format** for automation and validation

### Fallback Methods

If MCP server is unavailable, use manual GitHub CLI commands as documented in the rest of this guide.

## Backport Label System

Labels follow the pattern: `Backport-<version>.x-<state>`

**States:**
- `Consider` - Under review for backporting
- `Approved` - Approved and ready to be backported
- `Migrated` - Backport PR has been created
- `Done` - Backport PR has been merged

**Examples:** `Backport-7.4.x-Approved`, `Backport-7.5.x-Consider`, `Backport-7.3.x-Done`

## Branch Naming Conventions

### Standard Branch Format (Both Manual and Automated)
Format: `backport/release/v<version>/<pr-number>-<short-commit-hash>[-<postfix>]`

Examples:
- `backport/release/v7.4/26193-4aff02475`
- `backport/release/v7.5/26398-e7bf5621b`

## PR Format Requirements

For the complete backport PR template and detailed guidance on filling out each section, see: `.github/instructions/backports/pr-template.instructions.md`

### Quick Reference

**Title Format:**
```
[<target-release-branch>] <original-pr-title>
```

**Key Sections:**
- **Impact**: Tooling vs Customer impact, with descriptions
- **Regression**: Yes/No with context
- **Testing**: Verification approach and test coverage
- **Risk**: High/Medium/Low with justification

**Required Metadata:**
- Auto-generated comment with `$$$originalprnumber:` (never modify)
- Triggered by and original author attribution
- Original CL label
- CC to @PowerShell/powershell-maintainers

## Checking for Prerequisite PRs

**CRITICAL**: Before starting a backport, check if the PR has dependencies on other PRs that must be backported first.

### When to Check for Prerequisites

Check for prerequisite PRs if:
- The PR modifies code that was recently added or refactored
- The PR description mentions "depends on" or "builds on" another PR
- The PR is part of a series or multi-part change
- The merge date is close to other related PRs from the same author

### How to Identify Prerequisites

1. **Check PR description and comments** for mentions of related PRs
2. **Review the PR's base commit** to see what code existed when it was created
3. **If conflicts occur during cherry-pick**, check if missing code sections indicate a prerequisite:
   ```powershell
   # Find when the missing code was added
   git log --all --oneline -S "MissingCodeSection" -- FilePath.ext

   # Example: Finding when FxDependentDeployment was added
   git log --all --oneline -S "FxDependentDeployment" -- PowerShell.Common.props
   ```

### Example: PR Dependency Chain

If PR #26290 modifies code added by PR #25837:
1. Identify that PR #25837 is the prerequisite
2. **Notify maintainer** to add backport label to PR #25837:
   - Comment on PR #26290: "This backport depends on #25837 being backported first. Can a maintainer please add the Backport-7.5.x-Consider label to #25837?"
3. Wait for PR #25837 to be labeled and backported
4. Then backport PR #26290

**Warning**: Attempting to backport dependent PRs out of order will result in conflicts that cannot be properly resolved.

## Handling Merge Conflicts

### Conflict Resolution Approach

1. **Analyze the diff first**:
   ```bash
   gh pr diff <pr-number> --repo PowerShell/PowerShell | Out-File pr-diff.txt
   ```

2. **Check for missing prerequisite PRs FIRST**:
   - If the conflict involves entire missing code sections, STOP
   - Search for the prerequisite PR that added that code
   - Backport prerequisites first, then retry
   - See "Checking for Prerequisite PRs" section above

3. **Identify conflict types**:
   - **Missing prerequisite PR**: Code sections don't exist (STOP and backport prerequisite first)
   - **Parameter additions**: New parameters added to functions
   - **Code removal**: Features removed in main but still in release
   - **Code additions**: New code blocks not in release
   - **Refactoring conflicts**: Code structure changes between branches

4. **Resolution priorities**:
   - Preserve the intent of the backported change
   - Keep release branch-specific code that doesn't conflict
   - When in doubt, favor the incoming change from the backport
   - Document significant manual changes in PR description

4. **Context-aware resolution**:
   - Apply the *change* from the PR, not make code identical to main
   - Release branch may have different code than main
   - Focus on backporting the specific fix, not new features

### Common Conflict Scenarios

1. **Function parameters differ**: Keep release branch parameters unless new parameters are part of the fix
2. **Dependencies removed in main**: Keep release branch dependencies if backport is unrelated
3. **New features in main**: Focus on backporting only the specific fix

### Conflict Resolution Summary

After resolving conflicts, create a summary including:
- Which files had conflicts
- Nature of each conflict
- How you resolved it
- Whether manual adjustments were needed beyond accepting one side

Add this summary to the PR description after the Risk section.

## Creating Backport PRs

### Using PowerShell Backport MCP Server (Preferred)

**PREFERRED METHOD**: Use the PowerShell Backport MCP server for the complete backport workflow.

**Step 1: Get PR Information**
```powershell
# Get original PR information including merge commit
$prInfo = mcp_powershell_ba_Get_PRBackportInfo -PRNumber <original-pr-number>
```

**Step 2: Create Backport Branch and Cherry-Pick**
```powershell
# Create branch and cherry-pick commit
$branchResult = mcp_powershell_ba_New_BackportBranch `
    -RepoFullPath $PWD `
    -PRNumber <original-pr-number> `
    -MergeCommitSHA $prInfo.MergeCommit `
    -TargetBranch "release/v<version>"

# Check if successful
if (-not $branchResult.Success) {
    Write-Warning "Cherry-pick resulted in conflicts in: $($branchResult.ConflictFiles -join ', ')"
    # Resolve conflicts manually, then continue
    # See "Handling Merge Conflicts" section
}
```

**Step 3: Create Backport PR**
```powershell
# Create backport PR with proper formatting
$backportUrl = mcp_powershell_ba_New_BackportPR `
    -RepoFullPath $PWD `
    -OriginalPRNumber <original-pr-number> `
    -TargetBranch "release/v<version>" `
    -HeadBranch "backport/release/v<version>/<pr-number>-<short-hash>" `
    -OriginalTitle $prInfo.Title `
    -OriginalAuthor $prInfo.Author `
    -CurrentUser "<your-github-username>" `
    -OriginalCLLabel ($prInfo.ChangelogLabels | Select-Object -First 1) `
    -TestingDescription "How the fix was verified and what tests were added" `
    -Risk "Medium" `
    -RiskJustification "Justification for the risk level" `
    -ToolingImpact "Required" `
    -ToolingDescription "Description of how this impacts build/tooling"

# Extract PR number from URL
$backportPrNumber = $backportUrl -replace '.*/', ''
Write-Output "Created backport PR #$backportPrNumber : $backportUrl"
```

**What This Tool Does Automatically**:
- ✅ **Pushes the branch to `origin` remote** (no manual `git push` needed)
- ✅ **Applies the CL label** specified in `OriginalCLLabel` to the new PR
- ✅ Sets up upstream tracking for the branch
- ✅ Creates PR with properly formatted title and body

**Required Parameters**:
- At least one of `CustomerImpact`/`CustomerDescription` or `ToolingImpact`/`ToolingDescription` must be provided
- `Risk` must be "High", "Medium", or "Low"
- The `origin` remote must be configured and accessible
- See `mcp-integration.instructions.md` for complete parameter documentation

**Optional Parameters for Special Cases**:
- `IsRegression` and `RegressionDetails` - If fixing a regression
- `MergeConflicts` - If conflicts were resolved during cherry-pick
- `Draft` - Set to `$true` to create draft PR

### Fallback: GitHub CLI Commands

**If MCP server unavailable**, see: `.github/instructions/backports/gh-cli-fallback.instructions.md`

Quick reference:
```powershell
gh pr create --title "[release/v<version>] <title>" --body "<body>" --base release/v<version> --repo PowerShell/PowerShell
```

## Label Management

### Using PowerShell Backport MCP Server (Preferred)

**PREFERRED METHOD**: Use the PowerShell Backport MCP server for label management.

#### After Creating Backport PR

**Note**: If you used `mcp_powershell_ba_New_BackportPR` to create the backport PR, the CL label was **automatically applied** - skip step 1 below.

1. **Add CL label to backport PR** (only needed if PR was created manually):
   ```powershell
   # Get CL label from original PR using MCP server
   $prInfo = mcp_powershell_ba_Get_PRBackportInfo -PRNumber <original-pr-number>
   $clLabel = $prInfo.ChangelogLabels | Select-Object -First 1

   # Add CL label to backport PR
   mcp_powershell_ba_Add_PRLabel -PRNumber <backport-pr-number> -Labels @($clLabel)
   ```

2. **Update original PR labels**:
   ```powershell
   # Transition from Consider to Migrated
   mcp_powershell_ba_Set_PRBackportMigrated -PRNumber <original-pr-number> -Version "<version>"
   ```

   Notes:
   - `Set_PRBackportMigrated` automatically removes `Backport-<version>.x-Consider` and adds `Backport-<version>.x-Migrated`
   - If original had `Backport-<version>.x-Approved`, only maintainers should transition it
   - `Migrated` indicates backport PR created (not yet merged)
   - `Done` should only be added once backport PR is merged

#### When Backport is Already Merged (No PR Needed)

If the commit is already in the target release branch:

```powershell
# Add Done label and remove Consider label
mcp_powershell_ba_Add_PRLabel -PRNumber <original-pr-number> -Labels @("BackPort-<version>.x-Done")
mcp_powershell_ba_Remove_PRLabel -PRNumber <original-pr-number> -Labels @("BackPort-<version>.x-Consider")
```

### Fallback: GitHub CLI Commands

**If MCP server unavailable**, see: `.github/instructions/backports/gh-cli-fallback.instructions.md`

## Using PowerShell Tools

The repository includes `Invoke-PRBackport` in `tools/releaseTools.psm1` for manual backports.

### Prerequisites

1. **GitHub CLI** (version 2.17+): https://cli.github.com/
   - Authenticate with `gh auth login`

2. **Upstream remote** pointing to `PowerShell/PowerShell`:
   ```bash
   git remote add upstream https://github.com/PowerShell/PowerShell.git
   ```

### Basic Usage

```powershell
Import-Module ./tools/releaseTools.psm1

# Backport a single PR
Invoke-PRBackport -PrNumber 26193 -Target release/v7.4.1

# With custom branch postfix
Invoke-PRBackport -PrNumber 26193 -Target release/v7.4.1 -BranchPostFix "retry"

# Overwrite existing local branch
Invoke-PRBackport -PrNumber 26193 -Target release/v7.4.1 -Overwrite
```

### Bulk Operations

```powershell
# Backport all approved PRs for a version
Invoke-PRBackportApproved -Version 7.2.12

# View backport reports
Get-PRBackportReport -Version 7.4 -TriageState Approved
Get-PRBackportReport -Version 7.4 -TriageState Approved -Web
```

## Best Practices

1. **Verify PR is merged** before attempting backport
2. **Test backports** in the target release context
3. **Check for conflicts early** - larger PRs more likely to conflict
4. **Use appropriate labels** - apply correct version and triage state
5. **Document special cases** in PR description if manual changes needed
6. **Follow up on CI failures** - backports must pass all CI checks

## Troubleshooting

### "PR is not merged" Error
Wait for the PR to be merged to the main branch first.

### "Please create an upstream remote" Error
```bash
git remote add upstream https://github.com/PowerShell/PowerShell.git
git fetch upstream
```

### "GitHub CLI is not installed" Error
Install from https://cli.github.com/ and restart terminal.



### Cherry-pick Conflicts (General)
Manually resolve conflicts, stage files, and continue cherry-pick.

### "Commit does not exist" Error
```bash
git fetch upstream
```

### Local Branch Behind Upstream
If your local release branch is behind upstream and missing recent backports:
```bash
# Check if upstream has newer commits
git log --oneline release/v7.4..upstream/release/v7.4

# If yes, update your local branch
git fetch upstream release/v7.4
git reset --hard upstream/release/v7.4
```

## Related Resources

- Release Process: `docs/maintainers/releasing.md`
- Release Tools: `tools/releaseTools.psm1`
- Issue Management: `docs/maintainers/issue-management.md`
