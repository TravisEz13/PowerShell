---
applyTo:
  - "tools/releaseTools.psm1"
  - ".github/prompts/backport-pr-to-release-branch.prompt.md"
  - ".github/agents/backport-agent.md"
---

# PowerShell Backport Process Instructions

## Overview

Backporting in the PowerShell repository involves applying changes from a merged PR on the main branch to a release branch (e.g., `release/v7.4`, `release/v7.5`). This ensures critical fixes and approved features reach released versions.

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

## Handling Merge Conflicts

### Conflict Resolution Approach

1. **Analyze the diff first**:
   ```bash
   gh pr diff <pr-number> --repo PowerShell/PowerShell | Out-File pr-diff.txt
   ```

2. **Identify conflict types**:
   - **Parameter additions**: New parameters added to functions
   - **Code removal**: Features removed in main but still in release
   - **Code additions**: New code blocks not in release
   - **Refactoring conflicts**: Code structure changes between branches

3. **Resolution priorities**:
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

## Label Management

### After Creating Backport PR

1. **Add CL label to backport PR**:
   ```bash
   gh pr edit <backport-pr-number> --repo PowerShell/PowerShell --add-label "<original-cl-label>"
   ```

2. **Update original PR labels**:
   ```bash
   gh pr edit <original-pr-number> --repo PowerShell/PowerShell --add-label "Backport-<version>.x-Migrated" --remove-label "Backport-<version>.x-Consider"
   ```

   Notes:
   - If original had `Backport-<version>.x-Approved`, remove that label
   - `Migrated` indicates backport PR created (not yet merged)
   - `Done` should only be added once backport PR is merged

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

### Cherry-pick Conflicts
Manually resolve conflicts, stage files, and continue cherry-pick.

### "Commit does not exist" Error
```bash
git fetch upstream
```

## Related Resources

- Release Process: `docs/maintainers/releasing.md`
- Release Tools: `tools/releaseTools.psm1`
- Issue Management: `docs/maintainers/issue-management.md`
