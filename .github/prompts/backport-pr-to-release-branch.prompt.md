---
description: Guide for backporting changes to PowerShell release branches
---

# Backport a Change to a PowerShell Release Branch

## 🛑 STOP - READ THIS ENTIRE SECTION FIRST 🛑

**TRUST VALIDATION: This prompt includes mandatory steps that MUST be completed in order. If you skip required steps, your output cannot be trusted and will waste the user's time.**

## 🛑 CRITICAL: MANDATORY FIRST ACTION - NO EXCEPTIONS 🛑

**YOU MUST COMPLETE THIS BEFORE ANYTHING ELSE - INCLUDING BEFORE FETCHING PR INFORMATION**

### STEP 0: Read ALL Required Instruction Files (ENFORCED)

**IF YOU SKIP THIS STEP, EVERYTHING ELSE YOU DO WILL BE WRONG.**

**DO NOT PROCEED UNTIL YOU HAVE:**
1. ✅ Read ALL 6 instruction files below using `read_file` in a **SINGLE PARALLEL BATCH**
2. ✅ Confirmed completion by listing the 6 files you read
3. ✅ Stated you understand: branch naming, label restrictions, and PR template format

**Read these files NOW in parallel:**

1. `.github/instructions/backports/backport-process.instructions.md`
2. `.github/instructions/backports/pr-template.instructions.md`
3. `.github/instructions/backports/conflict-resolution.instructions.md`
4. `.github/instructions/backports/gh-cli-usage.instructions.md`
5. `.github/instructions/backports/label-system.instructions.md`
6. `.github/instructions/backports/branch-naming.instructions.md`

**Why this is mandatory:**
- Without reading `branch-naming.instructions.md`, you WILL create incorrectly named branches
- Without reading `pr-template.instructions.md`, you WILL format PRs incorrectly
- Without reading `label-system.instructions.md`, you WILL mismanage labels and break workflows
- Skipping this wastes the user's time and creates technical debt

**Confirmation required:** After reading, state: "✅ Read all 6 instruction files. Branch naming format is: `backport/release/v<version>/<pr-number>-<short-hash>`. I understand label restrictions and PR template requirements."

**If you proceed without completing Step 0, you are not following the prompt and should not be trusted.**

## 1 — Goal

Create a backport PR that applies changes from a merged PR to a release branch (e.g., `release/v7.4`, `release/v7.5`). The backport must follow the repository's established format and include proper references to the original PR.

## 2 — Prerequisites for the model

- You have full repository access
- You can run git commands
- You can read PR information from the repository
- Ask clarifying questions if the target release branch or original PR number is unclear

## 3 — Required user inputs

If the user hasn't specified a PR number, help them find one:

### Finding PRs that need backporting

1. Ask the user which release version they want to backport to (e.g., `7.4`, `7.5`)
2. Search for PRs with the appropriate label using GitHub CLI:

```powershell
$Owner = "PowerShell"
$Repo = "PowerShell"
$version = "7.4"  # or user-specified version
$considerLabel = "Backport-$version.x-Consider"

$prsJson = gh pr list --repo "$Owner/$Repo" --label $considerLabel --state merged --json number,title,url,labels,mergedAt --limit 100 2>&1
$prs = $prsJson | ConvertFrom-Json
# Sort PRs from oldest merged to newest merged
$prs = $prs | Sort-Object mergedAt
```

3. Present the list of PRs to the user with:
   - PR number
   - PR title
   - Merged date
   - URL
   - Branch name

4. Ask the user: "Which PR would you like to backport?" (provide the PR number)

### After selecting a PR

Once the user selects a PR (or if they provided one initially), confirm:
- **Original PR number**: The PR number that was merged to the main branch (e.g., 26193)
- **Target release**: The release number (e.g., `7.4`, `7.5`, `7.5.1`)

Example: "Backport PR 26193 to release/v7.4"

## 4 — Implementation steps (must be completed in order)

### Step 0: ALREADY COMPLETED AT TOP - DO NOT SKIP

**This step was enforced at the top of this prompt. If you skipped it, STOP and go back.**

Verify you completed the mandatory reading by answering:
- ✅ What is the branch naming format? (Should be: `backport/release/v<version>/<pr-number>-<short-hash>`)
- ✅ Which label can you NEVER modify? (Should be: `Backport-*-Approved` - maintainer-only)
- ✅ What are the required PR body sections? (Should be: Impact, Regression, Testing, Risk)

If you cannot answer these, you skipped Step 0. Go back to the top and read all 6 instruction files NOW.

### Step 1: Verify the original PR exists and is merged

**PREFERRED**: Use the PowerShell Backport MCP server for comprehensive validation:

1. **Get comprehensive PR information using MCP server**:
   ```powershell
   mcp_powershell_ba_Get_PRBackportInfo -PRNumber <pr-number>
   ```

   This single call provides:
   - PR number, title, state, author, URL
   - All backport labels for all versions
   - Changelog labels (CL-*)
   - LinkedPRs (dependency information)

2. **Validate the response**:
   - Confirm `State` is `"MERGED"`
   - Extract merge commit SHA (will need separate `gh pr view` call if needed)
   - Note all `BackportLabels` for the target version
   - Note any `LinkedPRs` indicating dependencies
   - Extract `ChangelogLabels` for PR labeling

3. **Check for existing backport PRs**:
   ```powershell
   gh pr list --repo PowerShell/PowerShell --search "in:title [release/v<version>] <original-title>" --state all
   ```

4. **Interpret backport status from labels**:
   - `BackPort-<version>.x-Migrated`: Previous backport attempt (may have failed)
   - `BackPort-<version>.x-Done`: Already backported successfully  
   - `BackPort-<version>.x-Approved`: Ready for backporting
   - `BackPort-<version>.x-Consider`: Under consideration for backporting

   **If status is "Done"**: Inform user that backport may already be complete.
   **If LinkedPRs exist**: Check if prerequisite PRs need backporting first.

**FALLBACK**: If MCP server unavailable, use manual GitHub CLI:
   ```powershell
   gh pr view <pr-number> --repo PowerShell/PowerShell --json number,title,state,mergeCommit,author,labels,url
   ```

### Step 2: Create the backport branch

1. Identify the correct remote to fetch from:
   ```bash
   git remote -v
   ```

   Look for the remote that points to `https://github.com/PowerShell/PowerShell` (typically named `upstream` or `origin`). Use this remote name in subsequent commands.

2. Ensure you have the latest changes from the target release branch:
   ```bash
   git fetch <remote-name> <target-release-branch>
   ```

   Example: `git fetch upstream release/v7.4`

**Important:** When you switch branches, backport instructions will be out of date or non-existent. Copy the the instructions and prompt folder to a temporary location before switching branches. In PowerShell 7 you can use `(resolve-path temp:).providerpath` to get the root to the temp folder path.

3. **Create the backport branch following the naming convention in `.github/instructions/backports/branch-naming.instructions.md`**

   **⚠️ CRITICAL: Read and follow `.github/instructions/backports/branch-naming.instructions.md` for the exact branch naming format. Do NOT make up your own branch name.**



### Step 3: Cherry-pick the merge commit

1. Cherry-pick the merge commit from the original PR:
   ```bash
   git cherry-pick <merge-commit-sha>
   ```

2. If conflicts occur:

   **See `.github/instructions/backports/conflict-resolution.instructions.md` for detailed conflict resolution strategies.**

   - Inform the user about the conflicts
   - List the conflicting files
   - Fetch the original PR diff: `gh pr diff <pr-number> --repo PowerShell/PowerShell | Out-File pr-diff.txt`
   - Follow the conflict resolution guidance in `conflict-resolution.instructions.md`
   - Create a summary of the conflict resolution
   - Ask the user to review your conflict resolution summary before continuing
   - After conflicts are resolved: `git add <resolved-files>` then `git cherry-pick --continue`

### Step 4: Push the backport branch

Push to your fork (typically the remote that you have write access to):

```bash
git push <your-fork-remote> backport/release/v<version>/<pr-number>-<short-hash>
```

Example: `git push origin backport/release/v7.4/26398-e7bf5621b`

Note: If you're pushing to the official PowerShell repository and have permissions, you may push to `upstream` or the appropriate remote.

### Step 5: Create the backport PR

**See `.github/instructions/backports/pr-template.instructions.md` for the complete PR template format and guidelines.**

Create a new PR with:

**Title:** `[<target-release-branch>] <original-pr-title>`

**Body:** Use the template from `pr-template.instructions.md`, which includes:
- Backport reference with original PR number
- Auto-generated metadata comment
- Attribution (triggered by / on behalf of)
- Original CL label
- CC to maintainers
- Impact section (Tooling vs Customer)
- Regression section
- Testing section
- Risk section (High/Medium/Low with justification)
- Merge conflicts section (if applicable)

**Base branch:** `<target-release-branch>` (e.g., `release/v7.4`)

**Head branch:** `backport/release/v<version>/<pr-number>-<short-hash>` (e.g., `backport/release/v7.4/26398-e7bf5621b`)

### Step 6: Add the CL label to the backport PR

**See `.github/instructions/backports/label-system.instructions.md` for complete label management details.**

Add the same changelog label (CL-*) from the original PR to the backport PR:

```bash
gh pr edit <backport-pr-number> --repo PowerShell/PowerShell --add-label "<original-cl-label>"
```

### Step 7: Update the original PR's backport labels

Update the original PR to reflect that it has been backported:

```bash
gh pr edit <original-pr-number> --repo PowerShell/PowerShell --add-label "Backport-<version>.x-Migrated" --remove-label "Backport-<version>.x-Consider"
```

**Important**: If the original PR had `Backport-<version>.x-Approved`, remove that label as well. See `label-system.instructions.md` for the complete label lifecycle.

### Step 8: Clean up temporary files

After successful PR creation and labeling, clean up any temporary files created during the process:

```powershell
Remove-Item pr*.diff -ErrorAction SilentlyContinue
```

## 5 — Definition of Done (MANDATORY VERIFICATION)

**STOP BEFORE MARKING COMPLETE:** Verify each item is truly done.

### Phase 0: Prerequisites (IF YOU SKIPPED THIS, START OVER)
- [ ] ✅ **MANDATORY: Read ALL 6 instruction files in parallel at the start**
  - [ ] `backport-process.instructions.md`
  - [ ] `pr-template.instructions.md`
  - [ ] `conflict-resolution.instructions.md`
  - [ ] `gh-cli-usage.instructions.md`
  - [ ] `label-system.instructions.md`
  - [ ] `branch-naming.instructions.md`
- [ ] ✅ **Confirmed understanding by stating branch naming format and label restrictions**

### Phase 1: Verification
- [ ] Original PR is verified as merged (state = "MERGED")
- [ ] Checked for existing backport PRs (no duplicates)
- [ ] Reviewed backport labels to understand status

### Phase 2: Branch Creation
- [ ] Backport branch created with EXACT format: `backport/release/v<version>/<pr-number>-<short-hash>`
- [ ] Branch is based on correct release branch (e.g., `release/v7.4`)
- [ ] ⚠️ **CRITICAL**: Branch name matches instruction file convention (NOT made up)

### Phase 3: Code Changes
- [ ] Merge commit cherry-picked successfully (or conflicts resolved)
- [ ] If conflicts occurred, provided resolution summary to user
- [ ] Branch pushed to appropriate remote

### Phase 4: PR Creation
- [ ] PR created with correct title format: `[<release-branch>] <original-title>`
- [ ] Base branch set to target release branch (e.g., `release/v7.4`)
- [ ] No unrelated changes included

### Phase 5: PR Body Content (VERIFY EACH SECTION)
- [ ] ✅ Backport reference: `Backport of #<pr-number> to <release-branch>`
- [ ] ✅ Auto-generated comment with `$$$originalprnumber:<number>$$$`
- [ ] ✅ Triggered by and original author attribution
- [ ] ✅ Original CL label (if available)
- [ ] ✅ CC to @PowerShell/powershell-maintainers
- [ ] ✅ Impact section (Tooling OR Customer with description)
- [ ] ✅ Regression section (Yes/No with context)
- [ ] ✅ Testing section (How verified? Tests added?)
- [ ] ✅ Risk section (High/Medium/Low with justification)
- [ ] ✅ Merge conflicts section (if applicable)

### Phase 6: Label Management
- [ ] CL label added to backport PR (matching original PR's CL label)
- [ ] Original PR: Added `Backport-<version>.x-Migrated`
- [ ] Original PR: Removed `Backport-<version>.x-Consider`
- [ ] ⚠️ **NEVER MODIFIED**: `Backport-*-Approved` labels (maintainer-only)

### Phase 7: Cleanup
- [ ] Temporary files cleaned up (pr*.diff)

**Final verification question:** If a user reviews this backport, will they trust it was done correctly?

## 6 — Branch naming convention

**See `.github/instructions/backports/branch-naming.instructions.md` for complete branch naming details.**

## 7 — Example backport PR

Reference PR 26334 as the canonical example of a correct backport:

**Original PR**: PR 26193 "GitHub Workflow cleanup"

**Backport PR**: PR 26334 "[release/v7.4] GitHub Workflow cleanup"
- **Title**: `[release/v7.4] GitHub Workflow cleanup`
- **Body**: Started with backport reference to original PR and release branch
- **Branch**: `backport/release/v7.4/26193-4aff02475`
- **Base**: `release/v7.4`
- **Includes**: Auto-generated metadata, impact assessment, regression info, testing details, and risk level

## 8 — Backport label system (for context)

**See `.github/instructions/backports/label-system.instructions.md` for complete label system details.**

Backport labels follow pattern: `Backport-<version>.x-<state>`

**Key states:** Consider → Approved → Migrated → Done

Note: The PowerShell repository has an automated bot (pwshBot) that creates backport PRs automatically. Manual backports follow the same format.

## Manual Backport Using PowerShell Tools

For situations where automated backports fail or manual intervention is needed, use the `Invoke-PRBackport` function from `tools/releaseTools.psm1`.

### Prerequisites

1. **GitHub CLI**: Install from https://cli.github.com/
   - Required version: 2.17 or later
   - Authenticate with `gh auth login`

2. **Upstream Remote**: Configure a Git remote named `upstream` pointing to `PowerShell/PowerShell`:
   ```powershell
   git remote add upstream https://github.com/PowerShell/PowerShell.git
   ```

### Using Invoke-PRBackport

```powershell
# Import the release tools module
Import-Module ./tools/releaseTools.psm1

# Backport a single PR
Invoke-PRBackport -PrNumber 26193 -Target release/v7.4.1

# Backport with custom branch postfix
Invoke-PRBackport -PrNumber 26193 -Target release/v7.4.1 -BranchPostFix "retry"

# Overwrite existing local branch if it exists
Invoke-PRBackport -PrNumber 26193 -Target release/v7.4.1 -Overwrite
```

### Parameters

- **PrNumber** (Required): The PR number to backport
- **Target** (Required): Target release branch (must match pattern `release/v\d+\.\d+(\.\d+)?`)
- **Overwrite**: Switch to overwrite local branch if it already exists
- **BranchPostFix**: Add a postfix to the branch name (e.g., for retry attempts)
- **UpstreamRemote**: Name of the upstream remote (default: `upstream`)

### How It Works

1. Verifies the PR is merged
2. Fetches the target release branch from upstream
3. Creates a new branch.  See `branch-naming.instructions.md` for naming conventions.
4. Cherry-picks the merge commit
5. If conflicts occur, prompts you to resolve them
6. Creates the backport PR using GitHub CLI

## Handling Merge Conflicts

**See `.github/instructions/backports/conflict-resolution.instructions.md` for detailed conflict resolution strategies and patterns.**

When cherry-picking fails due to conflicts:

1. The script will pause and prompt you to fix conflicts
2. Resolve conflicts following the guidance in `conflict-resolution.instructions.md`
3. Stage resolved files: `git add <resolved-files>`
4. Continue the cherry-pick: `git cherry-pick --continue`
5. Type 'Yes<enter>' when prompted to continue the script

## Bulk Backporting Approved PRs

To backport all PRs labeled as approved for a specific version:

```powershell
Import-Module ./tools/releaseTools.psm1

# Backport all approved PRs for version 7.2.12
Invoke-PRBackportApproved -Version 7.2.12
```

This function:
1. Queries all merged PRs with the `Backport-<version>.x-Approved` label
2. Attempts to backport each PR in order of merge date
3. Creates individual backport PRs for each

## Viewing Backport Reports

Get a list of PRs that need backporting:

```powershell
Import-Module ./tools/releaseTools.psm1

# List all approved backports for 7.4
Get-PRBackportReport -Version 7.4 -TriageState Approved

# Open all approved backports in browser
Get-PRBackportReport -Version 7.4 -TriageState Approved -Web

# Check which backports are done
Get-PRBackportReport -Version 7.4 -TriageState Done
```



## Best Practices

1. **Verify PR is merged**: Only backport merged PRs
2. **Test backports**: Ensure backported changes work in the target release context
3. **Check for conflicts early**: Large PRs are more likely to have conflicts
4. **Use appropriate labels**: Apply correct version and triage state labels
5. **Document special cases**: If manual changes were needed, note them in the PR description
6. **Follow up on CI failures**: Backports should pass all CI checks before merging

## Troubleshooting

### "PR is not merged" Error
**Cause**: Attempting to backport a PR that hasn't been merged yet
**Solution**: Wait for the PR to be merged to the main branch first

### "Please create an upstream remote" Error
**Cause**: No upstream remote configured
**Solution**:
```powershell
git remote add upstream https://github.com/PowerShell/PowerShell.git
git fetch upstream
```

### "GitHub CLI is not installed" Error
**Cause**: gh CLI not found in PATH
**Solution**: Install from https://cli.github.com/ and restart terminal

### Cherry-pick Conflicts
**Cause**: Changes conflict with the target branch
**Solution**: Manually resolve conflicts, stage files, and continue cherry-pick

### "Commit does not exist" Error
**Cause**: Local Git doesn't have the commit
**Solution**:
```powershell
git fetch upstream
```

## Related Resources

**Instruction Files:**
- `.github/instructions/backports/backport-process.instructions.md` - Complete backport workflow
- `.github/instructions/backports/pr-template.instructions.md` - PR format and templates
- `.github/instructions/backports/conflict-resolution.instructions.md` - Conflict resolution strategies
- `.github/instructions/backports/gh-cli-usage.instructions.md` - GitHub CLI commands
- `.github/instructions/backports/label-system.instructions.md` - Label management
- `.github/instructions/backports/branch-naming.instructions.md` - Branch naming conventions

**Other Resources:**
- **Release Process**: `docs/maintainers/releasing.md`
- **Release Tools**: `tools/releaseTools.psm1`
- **Issue Management**: `docs/maintainers/issue-management.md`
