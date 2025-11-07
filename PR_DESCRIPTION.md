Backport of #26219 to release/v7.5

<!--
DO NOT MODIFY THIS COMMENT. IT IS AUTO-GENERATED.
$$$originalprnumber:26219$$$
-->

Triggered by @TravisEz13 on behalf of @TravisEz13

Original CL Label: CL-Build

/cc @PowerShell/powershell-maintainers

## Impact

### Tooling Impact

- [x] Required tooling change

This backports the markdown link verification GitHub Action to the release/v7.5 branch. This ensures that documentation quality checks are consistent across all active release branches, preventing broken links from being merged into release branches.

## Regression

- [ ] No

This is a new feature addition, not a regression fix.

## Testing

Original PR added:
- GitHub Actions workflow that runs on markdown file changes
- PowerShell scripts to parse and verify links using Markdig
- Configurable timeout and retry parameters

Backport verified by:
1. Clean cherry-pick with no conflicts
2. All 6 files added successfully (916 lines)
3. Workflow YAML validated for syntax correctness
4. Scripts follow PowerShell parameter naming conventions per `.github/instructions/powershell-parameter-naming.instructions.md`

The workflow will be tested automatically when it runs on the release branch after merge.

## Risk

- [ ] High
- [x] Medium
- [ ] Low

Medium risk: This is infrastructure tooling that adds a new GitHub Actions workflow. While it doesn't affect PowerShell runtime or customer-facing features, CI/CD changes can impact the development workflow. However:

- The change has been validated in master (merged Oct 21, 2025)
- Clean cherry-pick indicates compatibility with release/v7.5
- Workflow only runs on markdown file changes, limiting scope
- Adds quality checks without modifying existing processes
- Can be easily disabled if issues arise

The benefit of maintaining documentation quality on the release branch outweighs the risk of adding this tooling.

---

## 🤖 Agent Feedback Request

This backport was performed by the backport-agent running in a report-progress action environment.

**@copilot** Please review the agent instruction files and suggest 1-2 improvements, focusing on:

1. **Environment-specific limitations**: Are there constraints or limitations of the report-progress action environment that should be better documented in the agent instructions?
2. **Workflow clarity**: Were there any steps that could have been clearer or more explicit about what the agent can/cannot do?

Relevant instruction files:
- `.github/agents/backport-agent.md` - Main agent workflow
- `.github/instructions/backports/pr-template.instructions.md` - PR formatting
- `.github/instructions/backports/conflict-resolution.instructions.md` - Conflict handling

Focus on actionable improvements that would help future backport operations succeed on the first attempt.
