# Meta & Tooling

Scaffolding, session control, importing/syncing units, and integrations with common dev tools.

[← Back to the collection index](../../README.md)

### Skills (12)

| Unit | What it does | When to call | Install |
|---|---|---|---|
| `code` | Build/fix features with test-first development, review, and doc sync | — | `./install.sh --only code` |
| `continue` | Resume interrupted session. Loads context, companion findings, and git state | — | `./install.sh --only continue` |
| `done` | Checkpoint (pop current mode) OR full close-out with /done session | — | `./install.sh --only done` |
| `export-public` | Drive the public export layer — the machinery that turns this private repo into the downstream public repos (casper, refute-action, the awesome-sty… | Use when asked to "export public skills", "publish my skills", "check public export drift", "sync the public repos", "make the free repo", or "update… | `./install.sh --only export-public` |
| `intake` | Import external skills and agents into shared-config from a git URL or local path | Use when asked to "intake", "import a skill", "add this agent", "pull in skills from <repo>", or "ingest these skills" | `./install.sh --only intake` |
| `iterate-pr` | Iterate on a PR until CI passes | Use when you need to fix CI failures, address CodeRabbit feedback, or continuously push fixes until all checks are green. Automates the feedback-fix-… | `./install.sh --only iterate-pr` |
| `langfuse` | Interact with Langfuse and access its documentation | Use when needing to (1) query or modify Langfuse data programmatically via the CLI — traces, prompts, datasets, scores, sessions, and any other API r… | `./install.sh --only langfuse` |
| `pr-review-loop` | Poll a PR for CodeRabbit review, apply fixes (up to 3 rounds), then merge | — | `./install.sh --only pr-review-loop` |
| `project-init` | Bootstrap any repo with a full AI-ready scaffold | — | `./install.sh --only project-init` |
| `sync-skills` | Push or pull changes to the shared shared-config repo | — | `./install.sh --only sync-skills` |
| `trigger-agents` | AI agent patterns with Trigger.dev — orchestration, parallelization, routing, evaluator-optimizer, and human-in-the-loop | Use when building LLM-powered factory tasks that need parallel workers, approval gates, tool calling, or multi-step agent workflows | `./install.sh --only trigger-agents` |
| `trigger-tasks` | Build AI agents, workflows and durable background tasks with Trigger.dev | Use when creating tasks, triggering jobs, handling retries, scheduling cron jobs, or implementing queues and concurrency control in the factory | `./install.sh --only trigger-tasks` |

### Agents (1)

| Unit | What it does | When to call | Install |
|---|---|---|---|
| `question-router` | Route questions to the right specialist agent based on topic | — | `./install.sh --only question-router` |

Install the whole category at once: `./install.sh --category meta-and-tooling`
