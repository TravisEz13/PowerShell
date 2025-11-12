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
  "BackportLabels": ["BackPort-7.6.x-Consider"],
  "ChangelogLabels": ["CL-BuildPackaging"],
  "LinkedPRs": []
}
```

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

### 2. Custom Instructions Updates

The interactive backport custom instructions should be updated to include:

1. **Add MCP server usage to STEP 1**:
   - Replace GitHub CLI PR fetching with MCP server call
   - Use MCP response for all PR validation
   - Fallback to GitHub CLI if MCP unavailable

2. **Update the workflow flow**:
   ```markdown
   ## STEP 1: PR Discovery and Validation

   ### Use MCP server for comprehensive PR information:

   ```powershell
   mcp_powershell_ba_Get_PRBackportInfo -PRNumber {pr-number}
   ```

   ### Validate the MCP response:
   - ✅ State must be "MERGED"
   - ✅ Extract BackportLabels for target version status
   - ✅ Check LinkedPRs for dependencies
   - ✅ Note ChangelogLabels for later use
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

Use MCP server data for label operations:

```markdown
### Extract CL label from MCP response:
```powershell
$mcpResponse = mcp_powershell_ba_Get_PRBackportInfo -PRNumber 26404
$clLabel = $mcpResponse.ChangelogLabels | Select-Object -First 1

# Add to backport PR
gh pr edit $backportPrNumber --add-label $clLabel --repo PowerShell/PowerShell
```
```

## Advantages of MCP Integration

1. **Single Source of Truth**: One call gets all required information
2. **Comprehensive Status**: All backport labels across all versions
3. **Dependency Detection**: LinkedPRs field shows PR dependencies
4. **Consistency**: Reduces variation in manual GitHub CLI usage
5. **Reliability**: Authoritative data from PowerShell repository systems
6. **Performance**: Single MCP call vs multiple GitHub CLI calls

## Implementation Priority

### Phase 1: PR Validation (High Priority)
- Update STEP 1 in custom instructions to use MCP server
- Fallback to GitHub CLI when MCP unavailable
- Test with multiple PR scenarios

### Phase 2: Enhanced Dependency Detection (Medium Priority)
- Use LinkedPRs field to identify prerequisite PRs
- Automatically warn about missing prerequisites
- Guide users through correct backport ordering

### Phase 3: Full Integration (Low Priority)
- Replace all GitHub CLI calls where possible
- Enhanced error handling and validation
- Automated status reporting

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
