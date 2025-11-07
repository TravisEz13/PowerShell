---
applyTo:
  - "tools/releaseTools.psm1"
  - ".github/prompts/backport-pr-to-release-branch*.prompt.md"
  - ".github/agents/backport-agent.md"
---

# Backport PR Template and Format

## PR Title Format

```
[<target-release-branch>] <original-pr-title>
```

**Examples**:
- `[release/v7.4] GitHub Workflow cleanup`
- `[release/v7.5] Fix null reference in PSReadLine integration`
- `[release/v7.4.1] Update dependencies for security patch`

## PR Body Template

```markdown
Backport of #<original-pr-number> to <target-release-branch>

<!--
DO NOT MODIFY THIS COMMENT. IT IS AUTO-GENERATED.
$$$originalprnumber:<original-pr-number>$$$
-->

Triggered by @<current-user> on behalf of @<original-author>

Original CL Label: <original-cl-label>

/cc @PowerShell/powershell-maintainers

## Impact

Choose either tooling or Customer impact.

### Tooling Impact

- [ ] Required tooling change
- [ ] Optional tooling change (include reasoning)

### Customer Impact

- [ ] Customer reported
- [ ] Found internally

[Select one or both of the boxes. Describe how this issue impacts customers, citing the expected and actual behaviors and scope of the issue. If customer-reported, provide the issue number.]

## Regression

- [ ] Yes
- [ ] No

[If yes, specify when the regression was introduced. Provide the PR or commit if known.]

## Testing

[How was the fix verified? How was the issue missed previously? What tests were added?]

## Risk

- [ ] High
- [ ] Medium
- [ ] Low

[High/Medium/Low. Justify the indication by mentioning how risks were measured and addressed.]
```

## Filling Out Each Section

### Impact Section

**Tooling Impact**:
- Select when PR changes: build systems, CI/CD pipelines, packaging, developer tooling
- Mark as "Required" if release process depends on it
- Mark as "Optional" and explain if it's an improvement

**Customer Impact**:
- Select when PR affects: user-facing features, cmdlets, runtime behavior, performance
- Mark "Customer reported" if there's a related issue
- Mark "Found internally" if discovered during testing/development
- **Always describe**: Expected vs actual behavior, scope of impact

**Examples**:
```markdown
### Tooling Impact
- [x] Required tooling change

This backports the GitHub Actions workflow fix that prevents builds from failing on release branches.

### Customer Impact
- [x] Customer reported

Fixes #12345 where `Get-Command` would throw null reference exception when module path contains special characters. Expected: Command returns without error. Actual: NullReferenceException thrown. Affects users with non-standard module paths.
```

### Regression Section

Mark "Yes" only if:
- The original PR fixed a regression (not just a bug)
- A previously working feature broke in a recent release

**Include**:
- Which version/PR introduced the regression
- When it was discovered

**Examples**:
```markdown
## Regression
- [x] Yes

Regression introduced in v7.4.0 by PR #26000. Users reported the issue after upgrading from v7.3.
```

```markdown
## Regression
- [ ] No

This is a longstanding bug present since v6.0.
```

### Testing Section

**Include**:
- How the original fix was verified
- What tests were added (unit, integration, manual)
- How the backport was verified
- Why the issue wasn't caught earlier (if applicable)

**Examples**:
```markdown
## Testing

Original PR added unit tests in `test/powershell/Modules/Microsoft.PowerShell.Utility/Get-Command.Tests.ps1`.
Backport verified by:
1. Running added unit tests on release/v7.4 branch
2. Manual testing with special character module paths
3. Verified CI passes on backport branch

Issue was missed originally because test coverage didn't include edge cases with special characters.
```

### Risk Section

**Risk Levels**:

**High**:
- Changes to core engine functionality
- Security-related fixes
- Package/installer modifications
- Build system changes that affect all platforms
- Breaking changes (should be rare in backports)

**Medium**:
- Changes to non-critical cmdlets
- New functionality being backported
- Refactoring with broad impact
- Performance optimizations

**Low**:
- Documentation-only changes
- Test-only additions
- Narrow bug fixes with limited scope
- Minor refactoring in isolated areas

**Justify your assessment**:
```markdown
## Risk
- [ ] High
- [x] Medium
- [ ] Low

Medium risk: Changes a widely-used cmdlet (Get-Command) but only affects edge case (special characters in paths). Fix is well-tested and scoped to specific code path. Unlikely to affect normal usage.
```

### Special Note: CI/CD Changes

For CI/CD and infrastructure changes:
```markdown
## Risk
- [x] High
- [ ] Medium
- [ ] Low

High risk due to changes in build pipeline, but necessary to maintain build health on release branch. 
Not taking this change creates technical debt and makes future pipeline updates difficult to backport.
The change has been validated in master for 2 weeks without issues.
```

## Additional Sections

### If Merge Conflicts Occurred

Add after the Risk section:

```markdown
## Merge Conflicts

The following files had conflicts during cherry-pick:

- `src/System.Management.Automation/engine/CommandDiscovery.cs`
  - **Conflict**: Parameter list differences between branches
  - **Resolution**: Kept release branch parameters, applied only the null-check logic from the fix

- `test/powershell/Modules/Microsoft.PowerShell.Utility/Get-Command.Tests.ps1`
  - **Conflict**: Test helper methods differ between branches  
  - **Resolution**: Adapted test to use release branch helper methods

All conflicts resolved by preserving backport intent while respecting release branch code structure.
```

## Metadata Requirements

### Auto-Generated Comment

The comment block with `$$$originalprnumber:` is used by automation. Never modify it:

```markdown
<!--
DO NOT MODIFY THIS COMMENT. IT IS AUTO-GENERATED.
$$$originalprnumber:26193$$$
-->
```

### Attribution

Always include:
- Who triggered the backport
- Original PR author

```markdown
Triggered by @johndoe on behalf of @originalauthor
```

### CL Label

Include the changelog label from the original PR:

```markdown
Original CL Label: CL-BuildPackaging
```

If no CL label on original PR, omit this line.

### Maintainer CC

Always include:

```markdown
/cc @PowerShell/powershell-maintainers
```

## Complete Example

```markdown
Backport of #26193 to release/v7.4

<!--
DO NOT MODIFY THIS COMMENT. IT IS AUTO-GENERATED.
$$$originalprnumber:26193$$$
-->

Triggered by @SteveL-MSFT on behalf of @TravisEz13

Original CL Label: CL-BuildPackaging

/cc @PowerShell/powershell-maintainers

## Impact

### Tooling Impact

- [x] Required tooling change

Fixes GitHub Actions workflow failures on release/v7.4 by updating deprecated actions and fixing template dependencies.

## Regression

- [ ] No

This is an infrastructure improvement, not fixing a regression.

## Testing

Verified by:
1. Running affected workflows in fork
2. Confirming builds complete successfully
3. Checking artifact uploads work correctly

## Risk

- [x] High
- [ ] Medium
- [ ] Low

High risk as it modifies build infrastructure, but necessary to prevent build failures. Not taking this change creates technical debt for future CI updates. Changes validated in master branch for 3 weeks.
```
