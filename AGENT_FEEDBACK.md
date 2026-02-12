# Suggested Improvements to backport-agent.md

Based on this backport experience, here are suggested improvements to `.github/agents/backport-agent.md`:

## 1. Clarify PR Description Generation Requirement

**Issue**: The agent workflow shows how to prepare a PR body in Step 4, but doesn't explicitly state that this should be saved and used by report_progress.

**Current state** (Step 4):
```powershell
# Save PR body to file for report-progress action
$prBody | Out-File -FilePath "pr-body.txt" -Encoding utf8
```

**Suggested improvement**: Add explicit instruction that the PR description must be included in the `prDescription` parameter of `report_progress`:

```markdown
### Step 4: Prepare PR Description

**IMPORTANT**: The PR description must be passed to the `report_progress` tool using the `prDescription` parameter. The report-progress action will use this as the PR body.

1. Build the PR body following the template from `pr-template.instructions.md`
2. When calling `report_progress`, include the full PR body in the `prDescription` parameter
3. Do NOT just save to a file - the tool needs the content directly

Example:
```powershell
# Build PR body (see pr-template.instructions.md for details)
$prBody = @"
Backport of #$($pr.number) to release/v$version
...
"@

# Use report_progress with the PR body
report_progress(
    commitMessage: "Backport PR #$prNumber to release/v$version",
    prDescription: $prBody
)
```
```

## 2. Add PR Template Validation Checklist

**Issue**: The agent instructions reference the PR template but don't include a checklist to verify all required sections are present.

**Suggested addition** to Step 4, after the template example:

```markdown
### PR Description Checklist

Before calling `report_progress`, verify your PR description includes:

- [ ] First line: `Backport of #<number> to <target-branch>`
- [ ] Auto-generated comment with `$$$originalprnumber:<number>$$$`
- [ ] "Triggered by" line with current user and original author
- [ ] Original CL label reference
- [ ] CC to @PowerShell/powershell-maintainers
- [ ] **Impact section** (Tooling or Customer, with description)
- [ ] **Regression section** (Yes/No with explanation)
- [ ] **Testing section** (How verified, tests added)
- [ ] **Risk section** (High/Medium/Low with justification)
- [ ] **Agent Feedback Request section** (for continuous improvement)
- [ ] **Merge Conflicts section** (if conflicts occurred)

Missing any section will result in an incomplete PR that doesn't follow the repository's backport standards.
```

## 3. Improve Branch Name Verification Error Message

**Issue**: Step 1 verifies branch name but the error handling could be more specific about what's expected.

**Current state**:
```powershell
if ($currentBranch -notmatch "7[.-]5") {
    Write-Error "CRITICAL: Branch name '$currentBranch' does not indicate target version 7.5"
    throw "Branch name mismatch"
}
```

**Suggested improvement**:
```powershell
if ($currentBranch -notmatch "7[.-]5") {
    Write-Error @"
CRITICAL: Branch name mismatch!

Current branch: $currentBranch
Target version: 7.5

The branch name must contain '7.5' or '7-5' to indicate the target release.
Expected patterns:
  - copilot/backport-*-7-5
  - backport-*-release-7.5
  - release-7.5-*

The report-progress action infers the PR base branch from your branch name.
If this verification fails, the PR will target the wrong release branch.
"@
    throw "Branch name verification failed"
}
```

## 4. Clarify How to Find Default Branch for Reading Instructions

**Issue**: The agent instructions assume the default branch is "master" when reading instruction files, but this may not always be correct. The agent should determine the default branch dynamically.

**Current state** (in "Required Reading" section):
```powershell
# Read instruction files from default branch
git show upstream/master:.github/instructions/backports/pr-template.instructions.md
```

**Problem**: 
- Assumes default branch is named "master" 
- Assumes upstream remote exists and is named "upstream"
- Instructions may not exist on master if they're in a different branch

**Suggested improvement**: Add a section that explains how to find the correct branch for reading instructions:

```markdown
## Reading Instruction Files

**IMPORTANT**: Instruction files must be read from the branch where they exist, which may not be the default branch (master/main).

### Step 1: Determine where instruction files exist

First, check if the instruction files exist in various branches:

```bash
# Check if instructions exist in upstream master
git ls-tree -r --name-only upstream/master .github/instructions/backports/ 2>/dev/null

# Check if instructions exist in upstream main
git ls-tree -r --name-only upstream/main .github/instructions/backports/ 2>/dev/null

# Check in origin branches if upstream doesn't have them
git ls-tree -r --name-only origin/travisez13-main .github/instructions/backports/ 2>/dev/null
git ls-tree -r --name-only origin/master .github/instructions/backports/ 2>/dev/null
git ls-tree -r --name-only origin/main .github/instructions/backports/ 2>/dev/null
```

### Step 2: Read from the branch that has them

Once you've identified which branch contains the instruction files, use that branch:

```bash
# Example: If instructions are in origin/travisez13-main
git show origin/travisez13-main:.github/instructions/backports/pr-template.instructions.md

# Example: If instructions are in upstream/main
git show upstream/main:.github/instructions/backports/pr-template.instructions.md
```

### Step 3: Similarly for agent instructions

```bash
# Check where agent file exists
git ls-tree -r --name-only origin/travisez13-main .github/agents/ 2>/dev/null
git ls-tree -r --name-only upstream/master .github/agents/ 2>/dev/null

# Read from the correct location
git show origin/travisez13-main:.github/agents/backport-agent.md
```

### Why this matters

Instruction files and agent prompts may be:
- In a feature/development branch before being merged to default branch
- In a fork's main branch (like `origin/travisez13-main`)
- Have different content between default branch and development branches
- Not exist at all in older release branches

**Don't assume**:
- Default branch is named "master" (could be "main")
- Instructions exist in the default branch
- Remote is named "upstream" (might be "origin")

**Always verify** where the files exist before trying to read them.
```

## 5. Add Workflow Adaptation Guidance for Release Branches

**Issue**: When backporting GitHub Actions workflows to release branches, workflow branch filters and event handling may need adaptation.

**Problem encountered in this backport**: 
- The original workflow only triggered on `main, master` branches
- Release branches use the `release/**` pattern
- Workflow also defined `schedule` and `workflow_dispatch` events but action code didn't handle them
- Required manual fixes after cherry-pick

**Suggested improvement**: Add a new section to backport-agent instructions:

```markdown
## Special Considerations for GitHub Actions Workflows

When backporting changes to `.github/workflows/` or `.github/actions/`, verify:

### 1. Branch Filters Match Target Branch

**Check**: `on.push.branches` and `on.pull_request.branches` in workflow files

**Issue**: Original workflows may only target `main` or `master`, but release branches need `release/**`

**How to verify**:
```bash
# Compare branch patterns with existing release branch workflows
git show origin/release/v7.5:.github/workflows/linux-ci.yml | grep -A5 "branches:"

# Expected pattern for release branches:
# branches:
#   - master
#   - release/**
```

**Action**: Update branch filters in backported workflow to match patterns used by existing release branch workflows.

### 2. Event Types Are Fully Supported

**Check**: All event types defined in workflow `on:` trigger are handled by action code

**Issue**: Workflows may define `schedule`, `workflow_dispatch`, or other events that action code doesn't handle

**How to verify**:
```bash
# List events in workflow
grep -A20 "^on:" .github/workflows/verify-markdown-links.yml

# Check if action handles all these events
grep -A30 "eventName ===" .github/actions/infrastructure/markdownlinks/action.yml
```

**Action**: Ensure action code has logic for all event types defined in workflow, or remove unsupported events from workflow.

### 3. Test Workflow Syntax

**Validate YAML**:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/verify-markdown-links.yml'))"
python3 -c "import yaml; yaml.safe_load(open('.github/actions/infrastructure/markdownlinks/action.yml'))"
```

### Why This Matters

Workflows that don't trigger on release branches won't provide value to the release, and workflows with unsupported events will fail when triggered. These issues aren't caught by simple cherry-pick and require verification.
```

## Summary

These improvements focus on:

1. **Explicit PR description handling**: Making it clear that the PR body must be passed to `report_progress`, not just saved to a file
2. **Template validation**: Adding a checklist to ensure all required sections are included
3. **Better error messages**: Providing clearer guidance when branch name verification fails
4. **Dynamic branch discovery**: Teaching the agent to find instruction files rather than assuming they're in "upstream/master"
5. **Workflow adaptation for release branches**: Verifying and updating GitHub Actions workflows when backporting to release branches

These changes would help ensure backport PRs follow the correct template on the first attempt and reduce confusion about how to properly format and submit the PR description, while also making the agent more robust when instruction files are in non-standard locations and when backporting CI/CD infrastructure.
