---
name: "readme-refresher"
description: "Automatically refreshes README files after code modifications. Invoke when code changes require updating documentation or when user wants to ensure README is synchronized with code."
---

# README Refresher

This skill helps maintain up-to-date README files by automatically refreshing them after code modifications. It ensures that documentation remains synchronized with the actual codebase.

## When to Use

Invoke this skill:
- After completing code modifications that affect functionality described in README
- When adding new features that need documentation updates
- Before committing changes to ensure README is current
- When refactoring code that changes how features work

## How It Works

1. Detects changes in code files
2. Analyzes what parts of the README might need updates
3. Suggests or automatically applies changes to keep documentation in sync
4. Verifies that README accurately reflects current code functionality

## Usage Example

After modifying code that changes the CLI interface:

1. Run the README refresher skill
2. It will detect changes in CLI-related code
3. Update README sections that document CLI commands and options
4. Provide a summary of changes made

## Benefits

- Ensures documentation accuracy
- Saves time on manual README updates
- Prevents documentation drift from code changes
- Maintains consistency between code and documentation
- Improves project maintainability
