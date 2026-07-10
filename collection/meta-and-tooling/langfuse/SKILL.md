---
name: langfuse
origin: authored
public: true
description: Interact with Langfuse and access its documentation. Use when needing to (1) query or modify Langfuse data programmatically via the CLI — traces, prompts, datasets, scores, sessions, and any other API resource, (2) look up Langfuse documentation, concepts, integration guides, or SDK usage, or (3) understand how any Langfuse feature works. This skill covers CLI-based API access (via npx) and multiple documentation retrieval methods.
allowed-tools: Bash, Read, Grep
triggers:
  - langfuse
  - llm observability
  - llm tracing
  - tracedllmclient
  - langfuse.flush
  - observability tracing
---

> **Factory mode:** If `CLAUDE_AUTO` is set in the environment, skip these instructions and instead run `{scripts_dir}/skills/langfuse.sh "$@"` via Bash — the shell script handles autonomous dispatch.

# /langfuse — LLM Observability

Use when adding LLM tracing to factory tasks or agent workflows.

## {project_name} Langfuse Context

- **SDK:** `langfuse>=4.0.0` (in `requirements.txt`)
- **Existing infrastructure:**
  - `src/pipeline/langfuse_tracer.py` — ETL pipeline tracer
  - `api/middleware/langfuse_tracer.py` — FastAPI middleware
  - `src/llm/traced_client.py` — traced LLM client wrapper
- **Credentials:** `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST` ({secret_manager})

**Always use existing traced infrastructure before adding new Langfuse calls.**

---

## Using the Existing Traced Client

```python
# Preferred — use the existing traced client
from src.llm.traced_client import TracedLLMClient

client = TracedLLMClient(session_id="factory-run-{run_id}")
response = client.generate(
    prompt="Analyze this game data...",
    model="claude-sonnet-4-6",
    metadata={"task": "game_analysis", "game_id": game_id},
)
```

---

## Adding Tracing to New LLM Calls

When the traced client doesn't cover your use case, add spans manually:

```python
from langfuse import Langfuse
from langfuse.decorators import observe, langfuse_context

langfuse = Langfuse()

@observe()
def analyze_factory_output(prompt: str, context: dict) -> str:
    """Traced factory analysis call."""
    langfuse_context.update_current_observation(
        name="factory_analysis",
        input={"prompt": prompt, "context": context},
        metadata={"model": "claude-sonnet-4-6"},
        tags=["factory", "analysis"],
    )

    result = call_llm(prompt)  # your LLM call here

    langfuse_context.update_current_observation(
        output=result,
        usage={"input": token_count_in, "output": token_count_out},
    )
    return result
```

---

## Tracing Patterns by Use Case

### Factory task (Trigger.dev)

```python
from langfuse import Langfuse

langfuse = Langfuse()

def run_factory_task(task_id: str, prompt: str) -> str:
    trace = langfuse.trace(
        name="factory_task",
        user_id="factory",
        session_id=task_id,
        tags=["factory", "autonomous"],
        metadata={"task_id": task_id},
    )
    span = trace.span(name="llm_call", input={"prompt": prompt})
    try:
        result = call_llm(prompt)
        span.end(output=result)
        trace.update(output=result)
        return result
    except Exception as e:
        span.end(level="ERROR", status_message=str(e))
        raise
    finally:
        langfuse.flush()  # CRITICAL in serverless/task environments
```

### OpenAI drop-in tracing

```python
from langfuse.openai import openai  # drop-in replacement

response = openai.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": prompt}],
    # Langfuse picks this up automatically
)
```

---

## Always Set These Fields

| Field | Why |
|-------|-----|
| `user_id` | Required for per-user cost tracking and debugging |
| `session_id` | Groups related traces (e.g. one factory run = one session) |
| `name` | Makes Langfuse dashboard readable |
| `tags` | Filter by `["factory"]`, `["etl"]`, `["api"]`, etc. |

---

## Critical Rules

1. **Always call `langfuse.flush()`** in factory tasks and Trigger.dev handlers — tasks exit before batch upload completes and traces are lost
2. **Don't over-trace** — trace LLM calls and important decisions, not every function call
3. **Never include PII** in trace input/output — no player emails, user IDs beyond `org_id`
4. **Use existing `TracedLLMClient`** for standard factory calls — don't reinvent the wheel
5. **Session ID = factory run ID** — keep it consistent across all traces in one run

## Anti-Patterns

```python
# WRONG — no flush in a task context (traces are lost)
def factory_task():
    trace = langfuse.trace(name="task")
    do_work()
    # Missing: langfuse.flush()

# WRONG — tracing every internal function (noise)
@observe()
def format_string(s: str) -> str:  # Not an LLM call, don't trace this
    return s.upper()

# WRONG — PII in trace
trace = langfuse.trace(input={"player_email": user.email})  # Never

# RIGHT
trace = langfuse.trace(input={"org_id": org_id, "game_uuid": game_uuid})
```

# Langfuse

This skill helps you use Langfuse effectively across all common workflows: instrumenting applications, migrating prompts, debugging traces, and accessing data programmatically.

## Core Principles

Follow these principles for ALL Langfuse work:

1. **Documentation First**: NEVER implement based on memory. Always fetch current docs before writing code (Langfuse updates frequently) See the section below on how to access documentation.
2. **CLI for Data Access**: Use `langfuse-cli` when querying/modifying Langfuse data. See the section below on how to use the CLI. 
3. **Best Practices by Use Case**: Check the relevant reference file below for use-case-specific guidelines before implementing
4. **Use latest Langfuse versions**: Unless the user specified otherwise or there's a good reason, always use the latest version of Langfuse SDKs/APIs.


## Use case specific references

- instrumenting an existing function/application: references/instrumentation.md
- migrating prompts from a codebase into Langfuse: references/prompt-migration.md
- capturing user feedback (thumbs, ratings, implicit signals) as scores on traces: references/user-feedback.md
- further tips on using the Langfuse CLI: references/cli.md
- upgrading or migrating Langfuse SDKs to the latest version: references/sdk-upgrade.md
- submitting feedback about this skill: references/skill-feedback.md

## 1. Langfuse API via CLI

Use the `langfuse-cli` to interact with the full Langfuse REST API from the command line. Run via npx (no install required):

Start by discovering the schema and available arguments:

```bash
# Discover all available resources
npx langfuse-cli api __schema

# List actions for a resource
npx langfuse-cli api <resource> --help

# Show args/options for a specific action
npx langfuse-cli api <resource> <action> --help
```

### Credentials

Set environment variables before making calls:

```bash
export LANGFUSE_PUBLIC_KEY=pk-lf-...
export LANGFUSE_SECRET_KEY=sk-lf-...
export LANGFUSE_HOST=https://cloud.langfuse.com # example for EU cloud. For US cloud it's us.cloud.langfuse.com, and can also be a self-hosted URL. The server must always be specified in order to access Langfuse.
```

If not set, ask the user for their API keys (found in Langfuse UI → Settings → API Keys).

### Detailed CLI Reference

For common workflows, tips, and full usage patterns, see [references/cli.md](references/cli.md).

## 2. Langfuse Documentation

Three methods to access Langfuse docs, in order of preference. **Always prefer your application's native web fetch and search tools** (e.g., `WebFetch`, `WebSearch`, `mcp_fetch`, etc.) over `curl` when available. The URLs and patterns below work with any fetching method — the `curl` examples are just illustrative.

### 2a. Documentation Index (llms.txt)

Fetch the full index of all documentation pages:

```bash
curl -s https://langfuse.com/llms.txt
```

Returns a structured list of every doc page with titles and URLs. Use this to discover the right page for a topic, then fetch that page directly.

Alternatively, you can start on `https://langfuse.com/docs` and explore the site to find the page you need.

### 2b. Fetch Individual Pages as Markdown

Any page listed in llms.txt can be fetched as markdown by appending `.md` to its path or by using `Accept: text/markdown` in the request headers. Use this when you know which page contains the information needed. Returns clean markdown with code examples and configuration details.

```bash
curl -s "https://langfuse.com/docs/observability/overview.md"
curl -s "https://langfuse.com/docs/observability/overview" -H "Accept: text/markdown"
```

### 2c. Search Documentation

When you need to find information across all docs and github issues/discussions without knowing the specific page:

```bash
curl -s "https://langfuse.com/api/search-docs?query=<url-encoded-query>"
```

Example:

```bash
curl -s "https://langfuse.com/api/search-docs?query=How+do+I+trace+LangGraph+agents"
```

Returns a JSON response with:

- `query`: the original query
- `answer`: a JSON string containing an array of matching documents, each with:
  - `url`: link to the doc page
  - `title`: page title
  - `source.content`: array of relevant text excerpts from the page

Search is a great fallback if you cannot find the relevant pages or need more context. Especially useful when debugging issues as all GitHub Issues and Discussions are also indexed. Responses can be large — extract only the relevant portions.

### Documentation Workflow

1. Start with **llms.txt** to orient — scan for relevant page titles
2. **Fetch specific pages** when you identify the right one
3. Fall back to **search** when the topic is unclear and you want more context

## Skill Feedback

When the user expresses that something about this skill is not working as expected, gives incorrect guidance, is missing information, or could be improved — offer to submit feedback to the Langfuse skill maintainers. This includes when:

- The skill gave wrong or outdated instructions
- A workflow didn't produce the expected result
- The user wishes the skill covered something it doesn't
- The user explicitly says something like "this should work differently" or "this is wrong"

**Do NOT trigger this** for issues with Langfuse itself (the product) — only for issues with this skill's instructions and behavior.

When triggered, follow the process in [references/skill-feedback.md](references/skill-feedback.md).
