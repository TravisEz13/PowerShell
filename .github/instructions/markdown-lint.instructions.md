---
applyTo: "**/*.md"
---

# Markdown Lint Rules

All markdown files in this repository must follow the linting rules defined in `.markdownlint.json` at the repository root.

## Configuration

Before making recommendations about markdown formatting, **always read the `.markdownlint.json` file** from the repository root to understand the current rules and their configurations.

Key configuration file location:
- `.markdownlint.json` (repository root)

## Common Markdown Best Practices

When reviewing markdown files, check for:

1. **List indentation** - Verify the configured indent level for nested lists (check MD007 setting)
1. **Line length** - Ensure lines don't exceed the configured maximum (check MD013 setting)
1. **Ordered list numbering** - Check if the repository uses consistent or sequential numbering (check MD029 setting)
1. **Spacing around elements** - Verify blank lines around code blocks, lists, and headings (check MD031, MD032, MD022)

## VS Code Extension

This repository uses the markdownlint VS Code extension for real-time linting. The extension automatically reads the `.markdownlint.json` configuration file.

Extension ID: `DavidAnson.vscode-markdownlint`

If the extension is not installed, you can install it using:

```powershell
code --install-extension DavidAnson.vscode-markdownlint
```

The extension will automatically show warnings and errors in markdown files as you edit them.

## How to Use This

1. Read `.markdownlint.json` to see which rules are enabled/disabled and their specific configurations
1. Apply those rules when reviewing or generating markdown content
1. If a rule is disabled (set to `false`), don't enforce it
1. If a rule has specific configuration (like an object with settings), follow those settings exactly
