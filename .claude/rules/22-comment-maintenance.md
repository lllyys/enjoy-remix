# 22 - Comment Maintenance

When modifying code in files that carry AI-maintenance doc-comments, keep the comments in sync with the code in the same change.

## What Counts as a Documented File

Files with a `Purpose:` line in their header block, or TSDoc (`/** ... */`) module/file-level docs at the top.

## When to Update Comments

| Change Type | Action Required |
|-------------|-----------------|
| Change function/method behavior | Update its TSDoc (`/** */`) |
| Add/remove/rename exports | Add/remove/update their TSDoc |
| Add/rename/remove an IPC channel or `__ENJOY_APP__` method | Update the channel's TSDoc and any `@coordinates-with` lines on both preload and handler |
| Change what a file coordinates with | Update `@coordinates-with` lines |
| Change data flow or pipeline | Update `Pipeline:` in the header |
| Change a design decision | Update `Key decisions:` in the header |
| Fix a known limitation | Remove it from `Known limitations:` |
| Add a new edge case handler | Add `@edge-case` inline comment |
| Rename a file | Update the `@module` path and any `@coordinates-with` references in other files |
| Change a Sequelize model column or a migration's effect | Update the model's TSDoc and any header note describing the schema |

## When NOT to Update Comments

- Drive-by comment updates in files you didn't modify — don't touch unrelated files.
- Whitespace-only or import-order changes — no doc change needed.
- Test file changes — Playwright e2e and unit test files don't carry maintenance comments.

## Comment Rot Prevention

- Never write comments that reference line numbers, dates, or author names.
- Never leave `// TODO` without a concrete description of what needs doing.
- Keep the renderer `log.scope("<file>")` string in step with `@module` / the filename — both name the same file.
- If you notice a stale comment while editing, fix it in the same commit.

## Quick Check

Before committing, scan your changed files for `Purpose:` headers and top-of-file TSDoc, and verify they still accurately describe what the file does.
