# Docs & Context

Keep documentation, AI-context files, and structured project records honest and in sync.

[← Back to the collection index](../../README.md)

### Skills (3)

| Unit | What it does | When to call | Install |
|---|---|---|---|
| `sred-project-organizer` | Take a list of projects and their related documentation, and organize them into the SRED format for submission | — | `./install.sh --only sred-project-organizer` |
| `sred-work-summary` | Go back through the previous year of work and create a Notion doc that groups relevant links into projects that can then be documented as SRED projec… | — | `./install.sh --only sred-work-summary` |
| `sync-ai-context` | Diff and re-sync all AI context files (GEMINI.md, Cursor rules, Copilot instructions, rules/BASE.md) against AGENTS.md | — | `./install.sh --only sync-ai-context` |

### Agents (1)

| Unit | What it does | When to call | Install |
|---|---|---|---|
| `doc-cleanup` | Comprehensive documentation cleanup, reorganization, and consolidation | Use when docs are scattered, outdated, or need restructuring. Extracts valuable content from old docs into active plans before archiving | `./install.sh --only doc-cleanup` |

Install the whole category at once: `./install.sh --category docs-and-context`
