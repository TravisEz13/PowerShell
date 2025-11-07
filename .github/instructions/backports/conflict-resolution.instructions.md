---
applyTo:
  - "tools/releaseTools.psm1"
  - ".github/prompts/backport-pr-to-release-branch*.prompt.md"
  - ".github/agents/backport-agent.md"
---

# Merge Conflict Resolution for Backports

## Overview

When backporting PRs, merge conflicts are common because release branches diverge from the main branch. This guide covers strategies for resolving these conflicts while preserving the intent of the original fix.

## Key Principle

**Apply the *change* from the PR, not make the code identical to main.**

The release branch may have different code than main. Your goal is to backport the specific fix or feature, not all the differences between branches.

## Conflict Resolution Process

### Step 1: Analyze the Original Change

Before resolving conflicts, understand what the original PR changed:

```powershell
# Fetch the original PR diff
gh pr diff <pr-number> --repo PowerShell/PowerShell | Out-File pr-<pr-number>.diff

# Review the diff
Get-Content pr-<pr-number>.diff | more
```

**Identify**:
- What was the bug or issue being fixed?
- What code changed to fix it?
- What's the scope of the change?

### Step 2: Identify Conflict Type

Common conflict types:

#### 1. Parameter Additions

**Scenario**: Main branch added new parameters to a function, but release branch doesn't have them.

```csharp
// Main branch
public void MyMethod(string param1, string param2, bool newFeatureFlag)

// Release branch
public void MyMethod(string param1, string param2)
```

**Resolution**:
- If the fix doesn't require the new parameter, keep release branch signature
- If the fix requires the new parameter, consider if it's appropriate for the release

#### 2. Code Removal

**Scenario**: Main branch removed code that's still in the release branch.

```csharp
// Main removed a deprecated feature
// Release branch still has it
```

**Resolution**:
- Keep release branch code unless the fix specifically requires its removal
- Apply the fix logic without removing unrelated features

#### 3. Refactoring Conflicts

**Scenario**: Code structure differs due to refactoring.

```csharp
// Main branch refactored into helper methods
// Release branch has inline code
```

**Resolution**:
- Apply the fix using the release branch's code structure
- Don't backport refactoring unless it's part of the fix

#### 4. Dependency Changes

**Scenario**: Main branch updated/removed dependencies.

```csharp
// Main branch uses new API
// Release branch uses old API
```

**Resolution**:
- Adapt the fix to work with release branch dependencies
- Don't backport dependency upgrades unless required for the fix

### Step 3: Resolve the Conflict

```powershell
# Check which files have conflicts
git status

# For each conflicting file:
# 1. Open in editor
# 2. Find conflict markers (<<<<<<<, =======, >>>>>>>)
# 3. Understand both versions
# 4. Apply the fix using release branch code patterns

**Resolution strategies**:

1. **Keep release code + apply fix logic**:
   ```csharp
   // Take release branch structure
   // Add only the fix from main branch
   ```

2. **Adapt main branch fix to release context**:
   ```csharp
   // Translate the fix to work with release branch patterns
   ```

3. **Manual merge**:
   ```csharp
   // Combine elements from both versions
   ```

### Step 4: Verify Resolution

```powershell
# Build the code
./build.ps1 -Clean

# Run relevant tests
./build.ps1 -Test

# Manual verification if needed
```

### Step 5: Document Resolution

Create a summary for the PR description:

```markdown
## Merge Conflicts

The following files had conflicts during cherry-pick:

### `src/System.Management.Automation/engine/CommandDiscovery.cs`
- **Conflict Type**: Parameter list differences
- **Cause**: Release branch lacks v7.5 parameter additions
- **Resolution**: Kept release branch signature, applied null-check logic only
- **Manual Changes**: Adapted test case to use available parameters

### `test/powershell/Modules/Get-Command.Tests.ps1`
- **Conflict Type**: Test helper method differences
- **Cause**: Test framework refactored in main
- **Resolution**: Rewrote test using release branch test helpers
- **Manual Changes**: Modified assertions to match release branch patterns
```

### Step 6: Continue Cherry-Pick

```powershell
# Stage resolved files
git add <resolved-files>

# Continue the cherry-pick
git cherry-pick --continue
```

## Common Scenarios and Solutions

### Scenario 1: Function Parameter Mismatch

**Original PR**: Adds null check in a function
**Conflict**: Function has different parameters in release branch

**Solution**:
```csharp
// Main branch (has extra parameter)
public void Process(string input, bool newFlag)
{
    if (input == null) throw new ArgumentNullException(); // The fix
    // ... rest
}

// Release branch adaptation
public void Process(string input)
{
    if (input == null) throw new ArgumentNullException(); // Apply same fix
    // ... rest (keep release branch logic)
}
```

### Scenario 2: Dependency API Changed

**Original PR**: Uses new API method
**Conflict**: Old API in release branch

**Solution**:
```csharp
// Main branch fix
var result = NewApi.GetValue(param);

// Release branch adaptation
var result = OldApi.RetrieveValue(param); // Same effect, old API
```

### Scenario 3: Code Moved/Refactored

**Original PR**: Fixes bug in helper method
**Conflict**: No helper method in release (code is inline)

**Solution**:
```csharp
// Main branch fix (in helper method)
private void Helper() {
    // Bug fix here
}

// Release branch adaptation (apply fix inline)
public void MainMethod() {
    // ... existing code ...
    // Apply fix logic here inline
    // ... rest of existing code ...
}
```

### Scenario 4: Feature Not Present in Release

**Original PR**: Fixes bug in a feature added after the release branch

**Decision**: This PR should likely NOT be backported. Inform the user.

## Context-Aware Resolution Guidelines

### 1. Preserve Release Branch Stability

- Don't introduce new features while fixing bugs
- Minimize changes beyond the specific fix
- Keep release branch code patterns

### 2. Maintain Fix Intent

- Ensure the bug is actually fixed
- Don't lose the fix logic in adaptation
- Test that the issue is resolved

### 3. Consider Release Constraints

- Don't backport breaking changes
- Avoid dependency upgrades unless critical
- Keep API compatibility

### 4. When in Doubt

- Favor smaller, safer changes
- Consult the original PR author or maintainers
- Document your decision-making process

## Conflict Resolution Checklist

- [ ] Fetched and reviewed original PR diff
- [ ] Identified conflict type(s)
- [ ] Understood the intent of the original fix
- [ ] Resolved conflicts preserving release branch patterns
- [ ] Applied the fix logic appropriately
- [ ] Built the code successfully
- [ ] Ran relevant tests
- [ ] Documented conflict resolution in PR description
- [ ] Presented resolution summary to user for review

## Warning Signs

Stop and consult if you encounter:

- **Extensive conflicts** across many files → May indicate PR not suitable for backport
- **API incompatibilities** → May require alternative approach
- **Missing dependencies** → Cannot backport without them
- **Feature dependencies** → Fix depends on features not in release

## Example Resolution Summary

```markdown
## Merge Conflicts Resolution

### Summary
3 files had conflicts during cherry-pick. All conflicts were due to parameter differences between branches.

### Detailed Resolutions

**File**: `src/System.Management.Automation/engine/CommandDiscovery.cs`
- **Lines**: 245-260
- **Conflict**: Main branch added `CommandOrigin origin` parameter; release branch doesn't have it
- **Resolution**: Kept release branch signature without new parameter. Applied the null reference fix (the actual bug fix) to the existing code path.
- **Rationale**: The null reference fix is independent of the new parameter which was added for v7.5 telemetry

**File**: `src/System.Management.Automation/engine/SessionState.cs`
- **Lines**: 890-895
- **Conflict**: Variable naming difference (`cmdInfo` vs `commandInfo`)
- **Resolution**: Used release branch variable name, applied the fix logic
- **Rationale**: Naming convention change was part of refactoring, not the fix

**File**: `test/powershell/Modules/Microsoft.PowerShell.Utility/Get-Command.Tests.ps1`
- **Lines**: 120-135
- **Conflict**: Test helper method `New-TestModule` has different signature
- **Resolution**: Adapted test to use release branch helper signature, maintained test coverage
- **Rationale**: Test framework differences between branches, adapted test maintains same coverage

All resolutions verified by:
- Building successfully on release/v7.4
- Running full test suite for CommandDiscovery
- Manual testing of the null reference scenario
```
