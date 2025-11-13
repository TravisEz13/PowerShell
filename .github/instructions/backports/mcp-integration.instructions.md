---
applyTo:
  - ".github/prompts/backport-pr-to-release-branch*.prompt.md"
  - ".github/agents/backport-agent.md"
---

# PowerShell Backport MCP Server Integration

## Overview

This document describes integration of the PowerShell Backport MCP server into the backport process for enhanced PR validation and status checking.

## MCP Server Configuration

The PowerShell Backport MCP server should be configured in VS Code's MCP settings (`mcp.json`):

```json
{
  "servers": {
    "PowerShell Backport": {
      "type": "stdio",
      "command": "pwsh",
      "args": [
        "-noprofile",
        "-c",
        "import-module",
        "Q:\\src\\git\\MCPAsPowerShellModule\\out\\MyFirstMCP\\;MyFirstMCP\\Start-MyMcp",
        "-module",
        "Q:\\src\\git\\Infrastructure\\tools\\BackportMcp\\"
      ]
    }
  }
}
```

## Available MCP Tools

### Get PR Backport Information

**Tool**: `mcp_powershell_ba_Get_PRBackportInfo`

**Parameters**:
- `PRNumber` (integer): The PR number to query
- `Owner` (string, optional): Repository owner (default: "PowerShell")
- `Repo` (string, optional): Repository name (default: "PowerShell")

**Returns**: JSON object with comprehensive backport information:

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

**Tool**: `mcp_powershell_ba_New_BackportBranch`

**Purpose**: Automates the git operations needed to create a backport branch and cherry-pick the commit. This tool:
- Fetches the latest upstream changes for the target release branch
- Creates a properly named backport branch following PowerShell conventions
- Sets up upstream tracking to the release branch
- Cherry-picks the merge commit from the original PR
- Detects and reports any merge conflicts

**Prerequisites**:
- Git repository must have an `upstream` remote pointing to PowerShell/PowerShell
- Working directory must be clean (no uncommitted changes)
- User must have necessary git permissions

**Parameters**:
- `RepoFullPath` (string, required): The full path to the root of the local git repository
- `PRNumber` (integer, required): The original PR number being backported
- `MergeCommitSHA` (string, required): The full merge commit SHA from the original PR
- `TargetBranch` (string, required): Target release branch (e.g., "release/v7.4", "release/v7.6")
- `UpstreamRemote` (string, optional): Name of the upstream remote (default: "upstream")

**Returns**: Hashtable with backport branch creation results:

```powershell
@{
    BranchName = "backport/release/v7.6/26282-e5d40dc06"
    Success = $true  # or $false if conflicts occurred
    ConflictFiles = @()  # Array of file paths with conflicts (if any)
    Message = "Successfully created backport branch and cherry-picked commit"
}
```

**Example Usage**:

```powershell
# Get PR information first
$prInfo = mcp_powershell_ba_Get_PRBackportInfo -PRNumber 26282

# Create backport branch and cherry-pick
$result = mcp_powershell_ba_New_BackportBranch `
    -RepoFullPath "Q:\src\git\powershell" `
    -PRNumber 26282 `
    -MergeCommitSHA $prInfo.MergeCommit `
    -TargetBranch "release/v7.6"

# Check result
if ($result.Success) {
    Write-Output "Branch created successfully: $($result.BranchName)"
} else {
    Write-Warning "Conflicts detected in: $($result.ConflictFiles -join ', ')"
    # Resolve conflicts manually, stage files, then git cherry-pick --continue
}
```

**Notes**:
- Branch naming follows convention: `backport/release/v<version>/<pr-number>-<short-hash>`
- Automatically extracts short hash (first 9 characters) from merge commit
- If conflicts occur, the branch is created and cherry-pick is started, but left in conflict state
- User must resolve conflicts, stage files, and continue cherry-pick manually
- See "Handling Merge Conflicts" section in `backport-process.instructions.md` for conflict resolution guidance

### Create Backport PR

**Tool**: `mcp_powershell_ba_New_BackportPR`

**Purpose**: Creates a backport PR with properly formatted title, body, and metadata following PowerShell repository standards. This tool automatically:
- Pushes the backport branch to the `origin` remote
- Applies the CL label from `OriginalCLLabel` to the new PR
- Sets up proper upstream tracking for the branch

**Prerequisites**:
- The backport branch must exist locally
- The `origin` remote must be configured and accessible
- The branch will be pushed to `origin` before creating the PR

**Parameters**:
- `RepoFullPath` (string, required): The full path to the root of the local git repository (e.g., "Q:\src\git\powershell")
- `OriginalPRNumber` (integer, required): The original PR number being backported
- `TargetBranch` (string, required): Target release branch (e.g., "release/v7.4", "release/v7.5")
- `HeadBranch` (string, required): The head branch containing backport changes (e.g., "backport/release/v7.4/26193-4aff02475")
- `OriginalTitle` (string, required): Title of the original PR
- `OriginalAuthor` (string, required): GitHub username of original PR author
- `CurrentUser` (string, required): GitHub username of person triggering the backport
- `OriginalCLLabel` (string, required): Changelog label from original PR (e.g., "CL-BuildPackaging"), will tag the new PR with this label
- `TestingDescription` (string, required): How the fix was verified and what tests were added
- `Risk` (string, required): "High", "Medium", or "Low"
- `RiskJustification` (string, required): Justification for the risk level
- `CustomerImpact` (string, recommended): "CustomerReported" or "FoundInternally" (empty if not applicable)
- `CustomerDescription` (string, optional): Description of customer impact (required if CustomerImpact is set)
- `ToolingImpact` (string, optional): "Required" or "Optional" (empty if not applicable)
- `ToolingDescription` (string, optional): Description of tooling impact (required if ToolingImpact is set)
- `IsRegression` (boolean, recommended): Whether this fixes a regression (default: false)
- `RegressionDetails` (string, optional): When regression was introduced (required if IsRegression is true)
- `MergeConflicts` (string, recommended): Description of merge conflicts and resolution
- `Draft` (boolean, optional): Whether to create as draft PR (default: false)
- `Owner` (string, optional): Repository owner (default: "PowerShell")
- `Repo` (string, optional): Repository name (default: "PowerShell")

**Returns**: URL of the created backport PR

**Example Usage**:

```powershell
# Get original PR information
$prInfo = mcp_powershell_ba_Get_PRBackportInfo -PRNumber 26193

# Create backport PR
$backportUrl = mcp_powershell_ba_New_BackportPR `
    -RepoFullPath "Q:\src\git\powershell" `
    -OriginalPRNumber 26193 `
    -TargetBranch "release/v7.4" `
    -HeadBranch "backport/release/v7.4/26193-4aff02475" `
    -OriginalTitle $prInfo.Title `
    -OriginalAuthor $prInfo.Author `
    -CurrentUser "travisez13" `
    -OriginalCLLabel "CL-BuildPackaging" `
    -TestingDescription "Verified by running affected workflows in fork. Confirmed builds complete successfully." `
    -Risk "High" `
    -RiskJustification "High risk as it modifies build infrastructure, but necessary to prevent build failures." `
    -ToolingImpact "Required" `
    -ToolingDescription "Fixes GitHub Actions workflow failures on release/v7.4 by updating deprecated actions."

Write-Output "Backport PR created: $backportUrl"
```

**Notes**:
- Automatically formats PR title as `[<target-branch>] <original-title>`
- Generates PR body following complete template from `pr-template.instructions.md`
- Includes auto-generated metadata comment with `$$$originalprnumber:` marker
- Sets base branch to target release branch
- **Automatically pushes the branch to `origin` remote** before creating the PR
- **Automatically applies the `OriginalCLLabel` to the new backport PR** (no manual labeling needed)
- At least one of `CustomerImpact` or `ToolingImpact` must be provided
- If conflicts occurred, include description in `MergeConflicts` parameter

## Integration Points

### 1. PR Discovery and Validation (STEP 1)

**PREFERRED METHOD**: Use MCP server for initial PR validation:

```markdown
### Step 1: Verify the original PR exists and is merged

**PREFERRED**: Use the PowerShell Backport MCP server for comprehensive validation:

1. **Get comprehensive PR information using MCP server**:
   ```powershell
   mcp_powershell_ba_Get_PRBackportInfo -PRNumber <pr-number>
   ```

2. **Validate the response**:
   - Confirm `State` is `"MERGED"`
   - Note all `BackportLabels` for the target version
   - Note any `LinkedPRs` indicating dependencies
   - Extract `ChangelogLabels` for PR labeling

3. **Check for existing backport PRs** (still use GitHub CLI):
   ```powershell
   gh pr list --repo PowerShell/PowerShell --search "in:title [release/v<version>] <original-title>" --state all
   ```

**FALLBACK**: If MCP server unavailable, use manual GitHub CLI
```

### 2. Branch Creation and Cherry-Pick (STEP 2)

**PREFERRED METHOD**: Use MCP server for automated branch creation and cherry-pick:

```markdown
### Step 2: Create Backport Branch

**PREFERRED**: Use the PowerShell Backport MCP server to automate git operations:

1. **Get PR information** (if not already done):
   ```powershell
   $prInfo = mcp_powershell_ba_Get_PRBackportInfo -PRNumber <pr-number>
   ```

2. **Create branch and cherry-pick commit**:
   ```powershell
   $result = mcp_powershell_ba_New_BackportBranch `
       -RepoFullPath $PWD `
       -PRNumber <pr-number> `
       -MergeCommitSHA $prInfo.MergeCommit `
       -TargetBranch "release/v<version>"
   ```

3. **Check for conflicts**:
   ```powershell
   if ($result.Success) {
       Write-Output "✅ Branch created: $($result.BranchName)"
   } else {
       Write-Warning "⚠️ Conflicts detected in: $($result.ConflictFiles -join ', ')"
       # Proceed to conflict resolution
   }
   ```

### 3. Custom Instructions Updates

The interactive backport custom instructions should be updated to include:

1. **Add MCP server usage to STEP 1**:
   - Replace GitHub CLI PR fetching with MCP server call
   - Use MCP response for all PR validation
   - Fallback to GitHub CLI if MCP unavailable

2. **Add MCP server usage to STEP 2**:
   - Replace manual git commands with `New_BackportBranch` call
   - Use MCP response to detect conflicts early

3. **Update the workflow flow**:
   ```markdown
   ## STEP 1: PR Discovery and Validation

   ### Use MCP server for comprehensive PR information:

   ```powershell
   $prInfo = mcp_powershell_ba_Get_PRBackportInfo -PRNumber {pr-number}
   ```

   ### Validate the MCP response:
   - ✅ State must be "MERGED"
   - ✅ Extract BackportLabels for target version status
   - ✅ Check LinkedPRs for dependencies
   - ✅ Note ChangelogLabels and MergeCommit for later use

   ## STEP 2: Create Backport Branch

   ### Use MCP server for automated branch creation:

   ```powershell
   $result = mcp_powershell_ba_New_BackportBranch `
       -RepoFullPath $PWD `
       -PRNumber {pr-number} `
       -MergeCommitSHA $prInfo.MergeCommit `
       -TargetBranch "release/v{version}"
   ```

   ### Check result and handle conflicts if needed:
   - ✅ If Success = true, proceed to create PR
   - ⚠️ If Success = false, resolve conflicts in ConflictFiles
   ```

### 3. Prerequisite Detection Enhancement

The MCP server's `LinkedPRs` field provides dependency information:

```markdown
**If LinkedPRs exist**: Check if prerequisite PRs need backporting first.

Example MCP response with dependencies:
```json
{
  "PRNumber": 26290,
  "LinkedPRs": [25837]
}
```

This indicates PR #26290 depends on PR #25837 and cannot be backported until #25837 is backported first.
```

### 4. Label Management Integration

**CL Label Application**: The `New_BackportPR` tool automatically applies the CL label specified in the `OriginalCLLabel` parameter to the newly created backport PR. No manual label addition is needed.

**Example workflow**:
```powershell
# Get original PR information including CL labels
$mcpResponse = mcp_powershell_ba_Get_PRBackportInfo -PRNumber 26404
$clLabel = $mcpResponse.ChangelogLabels | Select-Object -First 1

# Pass CL label to New_BackportPR - it will be automatically applied
$backportUrl = mcp_powershell_ba_New_BackportPR `
    -OriginalPRNumber 26404 `
    -OriginalCLLabel $clLabel `
    # ... other parameters ...

# CL label is already applied - no manual step needed!
```

## Advantages of MCP Integration

1. **Single Source of Truth**: One call gets all required information
2. **Automated Git Operations**: Branch creation and cherry-pick handled automatically
3. **Conflict Detection**: Early detection of merge conflicts with file-level detail
4. **Comprehensive Status**: All backport labels across all versions
5. **Dependency Detection**: LinkedPRs field shows PR dependencies
6. **Consistency**: Reduces variation in manual git and GitHub CLI usage
7. **Reliability**: Authoritative data from PowerShell repository systems
8. **Performance**: Single MCP call vs multiple git/GitHub CLI commands
9. **Error Prevention**: Proper branch naming and upstream tracking guaranteed

## Implementation Priority

### Phase 1: Complete Automation (High Priority) ✅
- ✅ PR validation using MCP server
- ✅ Automated branch creation with `New_BackportBranch`
- ✅ Automated PR creation with `New_BackportPR`
- ✅ Automated label management
- Fallback to manual commands when MCP unavailable

### Phase 2: Enhanced Dependency Detection (Medium Priority)
- Use LinkedPRs field to identify prerequisite PRs
- Automatically warn about missing prerequisites
- Guide users through correct backport ordering

### Phase 3: Advanced Conflict Resolution (Low Priority)
- Enhanced conflict analysis and suggestions
- Automated conflict resolution for common scenarios
- Integration with code review tools

## Migration Strategy

1. **Update instruction files** to document MCP server usage
2. **Update custom instructions** to use MCP server as primary method
3. **Maintain GitHub CLI fallback** for compatibility
4. **Test thoroughly** with various PR types and states
5. **Gather feedback** from backport process users

## Error Handling

```markdown
**If MCP server fails or unavailable**:
- Log the issue: "MCP server unavailable, falling back to GitHub CLI"
- Use existing GitHub CLI commands as documented
- Continue with normal backport process
- Consider reporting MCP server issues
```

## Related Files

- `.github/instructions/backports/backport-process.instructions.md`: Updated with MCP overview
- `.github/prompts/backport-pr-to-release-branch.prompt.md`: Updated STEP 1
- Custom instructions: Need manual update to use MCP server
- `mcp.json`: Server configuration example

## Testing Scenarios

Test MCP integration with:
- ✅ Simple PRs with no dependencies
- ✅ PRs with prerequisite dependencies
- ✅ PRs already backported (various label states)
- ✅ PRs with multiple backport labels (multi-version)
- ✅ PRs with various CL labels
- ✅ MCP server unavailable scenarios
