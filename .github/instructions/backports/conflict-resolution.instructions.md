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

### Step 0: Check for Missing Prerequisites FIRST

**CRITICAL**: Always fetch upstream before creating backport branches to avoid prerequisite-related conflicts:

```powershell
# ALWAYS do this before creating any backport branch
git fetch upstream
git fetch upstream release/v7.4  # Replace with your target version
```

**Why this prevents conflicts**:
- Gets recently backported prerequisite PRs that your local branch might be missing
- Prevents conflicts caused by missing template references, code sections, or dependencies
- Avoids the need to abort and restart backports due to outdated local branches

**If you're already in a conflict situation**, this may be the cause. See "Step 0b: Handle Missing Prerequisites Due to Outdated Local Branch" below.

**BEFORE attempting to resolve any conflicts**, determine if the conflict is due to a missing prerequisite PR.

**Red flags that indicate a missing prerequisite**:
- Conflict involves entire code blocks/sections that don't exist in release branch
- The PR is modifying code structures (classes, methods, property groups) not present in the target
- The conflict spans many lines with completely different context

If you suspect a missing prerequisite:
1. **STOP** - Do not attempt manual resolution
2. Follow the "Checking for Prerequisite PRs" section in `backport-process.instructions.md`
3. Identify the prerequisite PR number
4. **Notify maintainer** - Comment on the current PR requesting the prerequisite be marked for backport
5. Abort this backport attempt: `git cherry-pick --abort`
6. Delete the backport branch: `git branch -D backport/release/v7.X/XXXXX`
7. Wait for the prerequisite PR to be labeled and backported first
8. Start over after the prerequisite is backported

### Step 0b: Handle Missing Prerequisites Due to Outdated Local Branch

**Common Scenario**: Your local release branch is missing recently backported prerequisite PRs.

**Symptoms**:
- Conflicts involving template references that "should exist" but don't
- Missing entire code sections that were recently added
- Cherry-pick fails on changes to code that seems like it should be there

**Solution**:
1. **Abort the current cherry-pick**:
   ```powershell
   git cherry-pick --abort
   ```

2. **Fetch latest upstream changes**:
   ```powershell
   git fetch upstream release/v7.4  # Replace with your target version
   ```

3. **Check if upstream has recent backports you're missing**:
   ```powershell
   git log --oneline HEAD..upstream/release/v7.4
   ```

4. **Reset your branch to latest upstream**:
   ```powershell
   git reset --hard upstream/release/v7.4
   ```

5. **Retry the cherry-pick**:
   ```powershell
   git cherry-pick MERGE-COMMIT-SHA
   ```

This often resolves "missing prerequisite" conflicts that are actually just due to outdated local branches.

### Step 1: Analyze the Original Change and Check for Missing Files

Before resolving conflicts, understand what the original PR changed and check for missing dependencies:

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
- **Does the PR reference any new files that might not exist in the target branch?**

**Conceptual Goal: Detect When PRs Depend on Other Unbackported PRs**

PRs often build on work from other recent PRs. When backporting, if a **prerequisite PR hasn't been backported to the target release branch yet**, you'll see conflicts that cannot be resolved because the foundational code/files are missing.

**Key insight**: When a PR modifies or references files/code structures that were introduced by another recent PR, and that other PR isn't in the target branch, the backport will fail. Rather than trying to manually resolve these conflicts (which is impossible), you need to **identify the prerequisite PR, ensure it gets backported first, then retry**.

**How to detect this**: Look for conflicts where the PR is trying to use/modify something that doesn't exist in the target branch at all.

**Check for missing file references** (key indicator of prerequisite PRs):

Look for patterns in the diff that reference other files:
- Workflow files: `uses: ./.github/workflows/new-workflow.yml`
- Templates: `template: path/to/template.yml`
- Module imports: `Import-Module ./path/to/module.psm1`
- Relative file paths in code
- Property groups or configurations that were added recently
- Functions/classes/methods being called or modified

If you find file references, **verify they exist in the target branch**:

```powershell
# Example: PR references a reusable workflow
$referencedFile = ".github/workflows/xunit-tests.yml"

# Check if it exists in target branch
git ls-tree upstream/release/v7.6 $referencedFile

# If empty result, the file doesn't exist
# This is a strong indicator of a missing prerequisite PR
```

**If referenced files are missing from target branch**:
1. Find when the file was added:
   ```powershell
   git log --all --diff-filter=A --format="%H %s" -1 -- $referencedFile
   ```
2. Extract the PR number from the commit message
3. This is likely your prerequisite PR
4. **STOP and follow the prerequisite handling process** (Step 0)

**It's okay to abort a backport** when you discover missing prerequisites. Better to abort early than struggle with unresolvable conflicts.

### Step 2: Identify Conflict Type

Common conflict types:

#### 0. Missing Prerequisite PR (Critical)

**Scenario**: The PR being backported modifies code sections that don't exist in the release branch because a prerequisite PR was never backported.

**Signs of this issue**:
- Conflict involves entire code blocks that are completely missing from the release branch
- The PR diff shows modifications to code structures (property groups, classes, methods) that don't exist
- Git conflict shows the incoming change trying to modify non-existent context

**Example**:
```xml
<!-- PR tries to modify this section -->
<PropertyGroup Condition=" '$(AppDeployment)' == 'FxDependentDeployment' ">
    <PublishReadyToRun>true</PublishReadyToRun>  <!-- PR wants to move this -->
</PropertyGroup>

<!-- But release branch doesn't have 'FxDependentDeployment' at all -->
```

**Resolution**:
1. **STOP the backport immediately** - do not try to manually resolve
2. Search for the prerequisite PR that added the missing code:
   ```powershell
   # Search git history for when the code was added
   git log --all --oneline -S "MissingCodeSection" -- FilePath.ext
   ```
3. Find the PR number from the commit message
4. Verify the prerequisite PR is merged but not backported to this release
5. **Notify the maintainer** to add the backport label to the prerequisite PR:
   - Comment on the original PR being backported explaining the dependency
   - Ask maintainer to add `Backport-X.X.x-Consider` label to the prerequisite PR
   - Example comment: "This PR depends on #XXXXX which needs to be backported first. Can a maintainer please add the Backport-7.5.x-Consider label to #XXXXX?"
6. **Abort the current backport attempt**:
   ```powershell
   git cherry-pick --abort
   git switch <original-branch>
   git branch -D backport/release/vX.X/<pr-number>-<hash>
   ```
7. Wait for the prerequisite PR to be backported first
8. Then retry backporting the original PR

**How to identify the prerequisite PR**:
```powershell
# Find commits that introduced the missing code
git log --all --oneline -S "FxDependentDeployment" -- PowerShell.Common.props

# Check which PR introduced it
gh pr view <commit-pr-number> --repo PowerShell/PowerShell
```

**Important**: Always backport PRs in dependency order. If PR B depends on PR A, backport A first.

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
