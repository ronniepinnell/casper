---
name: project-init
origin: authored
public: true
description: Bootstrap any repo with a full AI-ready scaffold. Runs as /project-init (full interview), /project-init --bootstrap (fast 5-question path), /project-init sync (drift check), /project-init update <section> (targeted refresh), or /project-init setup <service> (walk through setting up Supabase, Doppler, Vercel, GitHub App, Linear, Railway, etc.)
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
coupling_exempt: bootstrap skill — names every service it configures (doppler/Linear/Supabase) and emits the canonical project-context.md defaults; service names are its catalog, not coupling
---

# Project Init

**Modes:**

| Invocation | What it does |
|------------|--------------|
| `/project-init` | Full first-time scaffold — interview + generate all files |
| `/project-init --bootstrap` | Fast-path — 5 questions, sensible defaults, all files generated |
| `/project-init sync` | Diff all AI context files vs AGENTS.md, offer to re-sync |
| `/project-init update <section>` | Re-run one section. Sections: `vision`, `stack`, `benchmarks`, `rules`, `workflow`, `github`, `ai-files` |
| `/project-init migrate` | Upgrade an existing `project-context.md` to the current schema (adds storage/factory/agents/paths with inferred defaults) + coupling audit |
| `/project-init setup <service>` | Walk through setting up a service. See Service Setup section below. |
| `CLAUDE_AUTO=1` | Non-interactive — reads `project-setup.json`, writes all files, commits |

---

## Mode: `--bootstrap`

Fast-path for new projects. 5 questions, all files generated, commit ready.

**Questions:**

```
AskUserQuestion([
  { question: "Project name and one-line description?", header: "Project" },
  { question: "Primary language(s) and framework(s)?", header: "Stack",
    options: ["Next.js + TypeScript", "Python + FastAPI", "Next.js + Python (full-stack)", "Other"] },
  { question: "Task manager?", header: "Tasks",
    options: ["Linear", "GitHub Issues", "None"] },
  { question: "Does this project have a UI?", header: "Has UI",
    options: ["Yes — Next.js", "Yes — other", "No"] },
  { question: "Database?", header: "Database",
    options: ["Supabase (new project)", "Supabase (existing)", "Postgres (other)", "None"] }
])
```

After answers: skip to Phase 4 (generate all files) using bootstrap defaults. Print manifest, confirm, write, commit.

**After the commit, offer the shared-config link** (only if `~/.claude/agents` resolves
into a shared-config checkout — otherwise skip silently):
> "Link this repo's `.claude/agents` + `.claude/hooks` to your shared shared-config
> (shared-config pattern)? [Y/n]"
If yes, run `setup shared-config` (agents + hooks) and amend/extend the commit.

Bootstrap commit message:
```
chore: /project-init bootstrap — AI scaffold

Generated: CLAUDE.md, AGENTS.md, GEMINI.md, Cursor rules, Copilot instructions,
rules/BASE.md, CONTRIBUTING.md, SECURITY.md, .github/ templates, project-context.md

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

---

## Mode: `setup` — Service Walkthroughs

`/project-init setup <service>` walks through setting up a service for this project.
Detects what is already configured and skips completed steps.

### Available services

| Command | What it sets up |
|---------|----------------|
| `/project-init setup supabase` | New Supabase project, env vars, client scaffold |
| `/project-init setup doppler` | Doppler project + config, seeds env vars, wires dev script |
| `/project-init setup vercel` | vercel.json, Vercel login, project link, env var sync |
| `/project-init setup github-app` | GitHub App manifest, webhook handler, auth flow scaffold |
| `/project-init setup linear` | Linear project/team, ticket prefix, project-context.md update |
| `/project-init setup storage` | Factory-memory backend (supabase/sqlite/none), `storage_dsn_env`, project-context.md update |
| `/project-init setup railway` | railway.json, service scaffold, env var wiring |
| `/project-init setup sentry` | Sentry project, SDK install, error boundary scaffold |
| `/project-init setup posthog` | PostHog project, SDK install, analytics scaffold |
| `/project-init setup shared-config` | Symlink `.claude/agents` + `.claude/hooks` to shared shared-config (shared-config pattern) |
| `/project-init setup all` | Runs each setup in logical order, skipping already-configured |

---

### `setup supabase`

**Step 1: Detect existing config**
```bash
grep -r "SUPABASE" .env.local.example 2>/dev/null
ls src/lib/supabase/ 2>/dev/null
```

If already configured: "Supabase client found. Run `/project-init sync` to check for drift."

**Step 2: Ask**
```
AskUserQuestion([
  { question: "Supabase setup:", header: "Supabase",
    options: [
      "New project — I'll create it now on supabase.com",
      "Existing project — I have the URL and keys",
      "Same org as another project — reuse org, new project"
    ]
  },
  { question: "Same account as other Supabase projects? (keeps billing unified)", header: "Org",
    options: ["Yes — same org", "No — new org (separate billing)"] }
])
```

**Step 3: Print manual steps**
```
ACTION REQUIRED — Create Supabase project:

1. Go to https://supabase.com/dashboard
2. Click "New project", choose org
3. Name: {project_slug}, generate a strong DB password
4. Click "Create new project" — takes ~2 min
5. Go to: Project Settings → API

Grab:
  Project URL          → NEXT_PUBLIC_SUPABASE_URL
  anon (public) key    → NEXT_PUBLIC_SUPABASE_ANON_KEY
  service_role key     → SUPABASE_SERVICE_ROLE_KEY (keep secret)

Press enter when ready.
```

**Step 4: Scaffold client files**

Install `@supabase/supabase-js` and `@supabase/ssr` if not present.

Write `src/lib/supabase/client.ts`:
```typescript
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
```

Write `src/lib/supabase/server.ts`:
```typescript
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (cookiesToSet) => {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            );
          } catch {}
        },
      },
    }
  );
}

export function createServiceClient() {
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { cookies: { getAll: () => [], setAll: () => {} } }
  );
}
```

Add vars to `.env.local.example`. If Doppler configured, seed vars:
```bash
doppler secrets set NEXT_PUBLIC_SUPABASE_URL="" NEXT_PUBLIC_SUPABASE_ANON_KEY="" SUPABASE_SERVICE_ROLE_KEY=""
```

Print summary + next steps.

---

### `setup doppler`

**Step 1: Detect**
```bash
which doppler && doppler whoami 2>/dev/null
cat .doppler.yaml 2>/dev/null
```

If not installed: "Install: `brew install dopplerhq/cli/doppler` then `doppler login`"
If not logged in: "Run `! doppler login`"

**Step 2: Ask**
```
AskUserQuestion([
  { question: "Doppler setup:", header: "Doppler",
    options: ["New project — create it now", "Existing project — just link it"] }
])
```

**Step 3: Create + link**
```bash
doppler projects create {project_slug}
doppler setup --project {project_slug} --config dev --no-interactive
```

**Step 4: Seed vars from .env.local.example**

Read all var names, seed as empty strings:
```bash
doppler secrets set VAR1="" VAR2="" ...
```

**Step 5: Wire dev script**

If `package.json` dev script not prefixed with `doppler run --`:
```json
"dev": "doppler run -- next dev"
```

**Step 6: Update .gitignore** — add `.env.local`.

Print:
```
✓ Doppler project "{project_slug}" created + linked (config: dev)
  {N} vars seeded — fill values at: https://dashboard.doppler.com

  dev script updated: npm run dev now injects secrets automatically.

Next: /project-init setup vercel — sync Doppler → Vercel
```

---

### `setup vercel`

**Step 1: Detect**
```bash
which vercel && vercel whoami 2>/dev/null && ls vercel.json 2>/dev/null
```

If not installed: "`npm i -g vercel`"
If not logged in: "Run `! vercel login`"

**Step 2: Write vercel.json** (if not present)
```json
{
  "framework": "nextjs",
  "buildCommand": "next build",
  "devCommand": "next dev",
  "installCommand": "npm install"
}
```

**Step 3: Link**
```bash
vercel link --yes
```

**Step 4: Doppler → Vercel env sync**

```
ACTION REQUIRED — Sync env vars to Vercel:

Option A — Doppler integration (recommended):
  1. https://dashboard.doppler.com/workplace/integrations/vercel
  2. Connect Vercel account
  3. Project: {project_slug}
  4. Map: dev config → Vercel Preview + Development
  5. Map: prd config → Vercel Production

Option B — manual:
  vercel env add NEXT_PUBLIC_SUPABASE_URL
  ... (repeat for each var)
```

**Step 5: Deploy (ask)**
If yes: `vercel --yes` and print preview URL.

---

### `setup github-app`

**Step 1: Detect**
```bash
ls github-app-manifest.json 2>/dev/null
grep "GITHUB_APP_ID" .env.local.example 2>/dev/null
```

**Step 2: Ask permissions + visibility**

**Step 3: Write `github-app-manifest.json`** with selected permissions.

**Step 4: Write webhook handler** — `src/app/api/webhooks/github/route.ts`
- Signature verification (`x-hub-signature-256`)
- Event routing: `push`, `pull_request`, `installation`, `check_run`
- TODOs for each handler

**Step 5: Write OAuth callback** — `src/app/api/github/callback/route.ts`

**Step 6: Print manual steps**
```
ACTION REQUIRED — Register GitHub App:

1. https://github.com/settings/apps/new
2. Paste contents of github-app-manifest.json
3. Click "Create GitHub App"
4. Grab:
   App ID             → GITHUB_APP_ID
   Generate private key → GITHUB_APP_PRIVATE_KEY
   Webhook secret     → GITHUB_WEBHOOK_SECRET
   Client ID          → GITHUB_CLIENT_ID
   Client Secret      → GITHUB_CLIENT_SECRET
5. Webhook URL: {NEXT_PUBLIC_APP_URL}/api/webhooks/github

Add to Doppler (or .env.local).
```

---

### `setup linear`

> **WORKSPACE LOCK — non-negotiable.** Many accounts have MULTIPLE Linear orgs
> connected (e.g. a global claude.ai Linear integration OAuth'd to a *different*
> org). Writing to the wrong org is the #1 Linear failure. This setup MUST pin the
> project to exactly one org/team and BLOCK every other Linear connection.

**Step 1: Detect**
```bash
grep "LINEAR" .env.local.example 2>/dev/null
grep task_manager .claude/project-context.md 2>/dev/null
```

**Step 2: Ask** — new team / new project / already set up + ticket prefix.

**Step 3: Print manual steps**
```
ACTION REQUIRED — Set up Linear:

1. https://linear.app → create team/project: {project_name}
2. Settings → API → Personal API Keys → LINEAR_API_KEY
3. Ticket prefix: {prefix} (e.g. {prefix}-001)
```

**Step 4: Capture + VERIFY the workspace (do not skip).**
With the new `LINEAR_API_KEY`, query the API and record the canonical identifiers:
```bash
node -e '
const k=process.env.LINEAR_API_KEY;
fetch("https://api.linear.app/graphql",{method:"POST",
  headers:{Authorization:k,"Content-Type":"application/json"},
  body:JSON.stringify({query:"{ organization { urlKey name } teams { nodes { id key name } } }"})
}).then(r=>r.json()).then(d=>console.log(JSON.stringify(d.data,null,2)))'
```
Record `organization.urlKey`, and the target team's `id` + `key`. These are the lock values.

**Step 5: Pin the workspace in config (ALWAYS write all three).**

a) `.mcp.json` — project-scoped Linear MCP using the project key:
```json
{ "mcpServers": { "linear-{urlKey}": { "type": "http", "url": "https://mcp.linear.app/mcp",
  "headers": { "Authorization": "Bearer ${LINEAR_API_KEY}" } } } }
```

b) `.claude/settings.local.json` — add the key to `env` AND **deny the global claude.ai
Linear MCP write tools** so the wrong org can't be written to:
```json
{ "env": { "LINEAR_API_KEY": "<key>" },
  "permissions": { "deny": [
    "mcp__claude_ai_Linear__save_issue", "mcp__claude_ai_Linear__save_milestone",
    "mcp__claude_ai_Linear__save_project", "mcp__claude_ai_Linear__save_document",
    "mcp__claude_ai_Linear__save_comment", "mcp__claude_ai_Linear__save_initiative",
    "mcp__claude_ai_Linear__save_status_update", "mcp__claude_ai_Linear__create_issue_label"
  ] } }
```

c) `CLAUDE.md` — add a HARD RULE block under `## Linear`:
```
**WORKSPACE — HARD RULE.** Linear lives in org `{urlKey}`, team `{KEY}` (team id `{teamId}`).
- Use the project LINEAR_API_KEY against https://api.linear.app/graphql, or the linear-{urlKey} MCP.
- NEVER use mcp__claude_ai_Linear__* (denied in settings — wrong org).
- Before ANY Linear write, verify `organization { urlKey }` == "{urlKey}".
```

**Step 6: Update `.claude/project-context.md`** — task_manager, task_prefix,
task_team_id, task_org_urlkey.

**Step 7: Self-check** — confirm `.mcp.json`, the `deny` list, and the CLAUDE.md
hard rule all exist and reference the SAME `{urlKey}`/`{teamId}`. If any agent later
needs to write to Linear, it must verify org urlKey first (per the hard rule).

---

### `setup storage`

Sets the **factory-memory** backend — where lifecycle skills persist decisions, outcomes,
session logs, gates, and budget (see `skills/_shared/storage/INTERFACE.md`). Separate from
the app's own `db`, though they often share one database.

**Step 1: Detect / default**
```bash
grep -E '^(db|storage_backend):' .claude/project-context.md 2>/dev/null
```
Default `storage_backend` from `db`: supabase/postgres→`supabase`, sqlite→`sqlite`, none→`none`.
Confirm or override with the Operator.

**Step 2: Per-backend wiring**
- `supabase` — ensure `storage_dsn_env` names an env var (e.g. `DATABASE_URL`); the
  `intel`/`qa` schemas must exist (they ship with the reference DB). NEVER store the DSN value.
- `sqlite` — no service needed; the backend auto-creates `.claude/factory-memory.db` on first
  write. Add `.claude/factory-memory.db` to `.gitignore`.
- `none` — nothing to wire; memory ops become no-ops. Lifecycle skills still run.

**Step 3: Update `.claude/project-context.md`** — `storage_backend`, `storage_dsn_env`,
`storage_schema_intel`, `storage_schema_qa`.

**Step 4: Self-check** — confirm the chosen backend's adapter file exists at
`skills/_shared/storage/{storage_backend}.md` and that no DSN value leaked into project-context.md.

---

### `setup railway`

**Step 1: Ask** — service type: Python worker / FastAPI / Postgres / Redis / Other.

**Step 2: Scaffold** — `railway.json`, `Dockerfile` or `Procfile`, add `RAILWAY_*` vars.

**Step 3: Print manual steps**
```
ACTION REQUIRED — Create Railway project:

1. https://railway.app/new
2. Connect GitHub repo: {repo}
3. Add service: {type}
4. Set env vars from Doppler or manually
```

---

### `setup sentry`

**Step 1: Ask** — new project / existing.

**Step 2: Install**
```bash
npm install @sentry/nextjs
```

**Step 3: Scaffold** — `sentry.client.config.ts`, `sentry.server.config.ts`, error boundary.

**Step 4: Add vars** — `SENTRY_DSN`, `SENTRY_AUTH_TOKEN`.

**Step 5: Print manual steps** — create project at sentry.io, grab DSN.

---

### `setup posthog`

**Step 1: Ask** — new project / existing.

**Step 2: Install**
```bash
npm install posthog-js posthog-node
```

**Step 3: Scaffold** — `src/lib/posthog.ts`, PostHog provider wrapper, pageview tracking.

**Step 4: Add vars** — `NEXT_PUBLIC_POSTHOG_KEY`, `NEXT_PUBLIC_POSTHOG_HOST`.

---

### `setup shared-config`

Wires this repo to the shared **shared-config** so it uses the same agents and hooks
as everything else (the "shared-config pattern"). The global `~/.claude/{agents,hooks}`
already symlink into shared-config; this makes them discoverable *project-scoped* too.

**Step 1: Detect**
```bash
ls -la .claude/agents .claude/hooks 2>/dev/null     # already linked?
readlink ~/.claude/agents ~/.claude/hooks 2>/dev/null # confirm global links exist
```
If `.claude/agents` and `.claude/hooks` are already symlinks → "Already wired to
shared-config. Nothing to do." and stop.

If `~/.claude/agents` / `~/.claude/hooks` do **not** resolve into a shared-config
checkout, warn and stop — there is nothing to link to:
```
! ~/.claude/agents does not point into shared-config.
  Set up the global links first, then re-run.
```

**Step 2: Ask what to link**
```
AskUserQuestion([
  { question: "Which shared resources should this repo link to shared-config?",
    header: "Link", multiSelect: true,
    options: [
      "agents  (.claude/agents → ~/.claude/agents)",
      "hooks   (.claude/hooks → ~/.claude/hooks)",
      "prompts (.claude/prompts → ~/.claude/prompts)",
      "skills  (.claude/skills → ~/.claude/skills)"
    ] }
])
```
Default (and the reference baseline) is **agents + hooks**. Link `skills`/`prompts`
only if asked — many repos keep project-local skills/prompts instead.

**Step 3: Create the symlinks** (only for selected, skipping any that already exist)
```bash
mkdir -p .claude
for name in agents hooks; do            # plus prompts/skills if selected
  if [ -e ".claude/$name" ] || [ -L ".claude/$name" ]; then
    echo "skip .claude/$name (exists)"
  else
    ln -s "$HOME/.claude/$name" ".claude/$name"
    echo "linked .claude/$name → ~/.claude/$name"
  fi
done
```

**Step 4: Verify resolution** (the link must reach a real shared-config dir)
```bash
for name in agents hooks; do
  tgt="$(readlink -f ".claude/$name" 2>/dev/null)"
  echo ".claude/$name → $tgt"
  [ -d "$tgt" ] || echo "  ! WARNING: does not resolve to a directory"
done
ls .claude/agents/ | head -3   # sanity: agents visible
```

**Step 5: Git tracking decision**
These symlinks point at absolute `~/.claude/...` paths (machine-specific). The reference project
**commits** them (git stores mode `120000` symlinks). Match that by default:
```bash
git add .claude/agents .claude/hooks   # plus any others linked
git ls-files -s .claude/agents         # expect mode 120000 = symlink, not 100644
```
If the user prefers portability across machines, instead add them to `.gitignore`:
```
.claude/agents
.claude/hooks
```
Ask once: "Commit the symlinks (shared-config pattern) or gitignore them (portable)?"
Default = commit.

**Step 6: Summary**
```
✓ .claude/agents → shared-config/agents
✓ .claude/hooks  → shared-config/hooks
  This repo now uses the shared agents + hooks.
```

> Note: `setup all` runs this **first** (before service setups) so shared agents/hooks
> are available for the rest of the run.

---

## Phase 1: Pre-flight

```bash
mkdir -p .claude
```

Check for non-interactive mode:
```bash
[ "$CLAUDE_AUTO" = "1" ] && [ -f project-setup.json ] && echo "AUTO MODE"
```

If auto mode: read `project-setup.json`, skip all interview phases, proceed to Phase 4.

---

## Phase 2: Auto-Scan

Detect silently — never ask about things you can discover.

| What | How |
|------|-----|
| Languages | `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod` |
| Frameworks | package.json deps, requirements.txt imports |
| Database | `supabase/`, `migrations/`, `prisma/`, `drizzle.config.*` |
| Task manager | `.linear`, `linear.json`, `.github/` |
| Deploy target | `vercel.json`, `Dockerfile`, `fly.toml`, `railway.json` |
| Has UI | react/vue/svelte in deps, `app/`, `ui/` directories |
| Has CI | `.github/workflows/`, `.circleci/` |
| Has tests | `tests/`, `__tests__/`, `*.test.*` |
| Secret manager | `.doppler.yaml`, `.env`, `.env.vault` |
| Existing AI files | CLAUDE.md, AGENTS.md, GEMINI.md, .cursorrules |
| Git remote | `git remote get-url origin 2>/dev/null` |

Print 6-line scan summary.

---

## Phase 3: Vision Interview

**Batch V1**
- **QV1** — "What problem does this solve? Two sentences: who has the pain, what's the fix."
- **QV2** — "Who is the primary user?" → Developer / End consumer / Internal / Enterprise
- **QV3** — "What stage?" → Idea / Prototype / MVP / Growth / Mature

**Batch V2**
- **QV4** — "Success in 6 months? One metric."
- **QV5** — "Hard constraints?"
- **QV6** — "What capability do you wish you had right now?"

---

## Phase 3b: Stack Advisory

### Greenfield — recommend a stack

| Building | Recommend | Reason |
|----------|-----------|--------|
| B2C SaaS + auth | Next.js + Supabase | Auth, DB, real-time in one ecosystem |
| Internal analytics | Next.js + DuckDB | Analytical queries without a server |
| Public API | FastAPI + Postgres | Async-native, battle-tested |
| CLI tool | Python/Typer or Go | Typer for Python devs, Go for single binary |
| AI-powered product | Next.js + Supabase + Vercel AI SDK | Streaming, edge, built-in AI patterns |
| GitHub App + dashboard | Next.js + Supabase + Doppler | Webhooks, DB, secrets |

Ask: "Here's what I'd suggest: {recommendation}. Does this fit?"

### Existing stack — review it

Flag: mismatches, missing pieces, over/under-engineering. Ask if any changes needed.

---

## Phase 3b2: Product Advisor

After Vision + stack. Conversational — build on what you heard.

- **QP1** — Monetization (skip if internal)
- **QP2** — Competitors / comps (**propose first, then confirm** — see below)
- **QP3** — Team size
- **QP4** — "Biggest risk right now?" (freeform)
- **QP5** — "How are you getting first 100 users?" (B2C only)
- **QP6** — North Star Benchmarks (**propose first, then confirm** — see below)
- **QP7** — "What's out of scope on purpose?" (idea/prototype only)

Synthesize into 3–5 bullets. Confirm before proceeding.

### QP2 — Competitors (propose-then-confirm)

Don't ask cold. From the QV1 problem statement + project type, **derive 3–5 likely
comps first** (use what you know; if a remote/web tool is available, a quick search
sharpens it — never block on it). Present them, then let the Operator correct:

```
Based on "{problem in one line}", your closest comps look like:
  • {Comp A} — {what overlaps}
  • {Comp B} — {what overlaps}
  • {Comp C} — {what overlaps}

Right? Add, remove, or tell me who I'm missing.
```

Capture the confirmed list → `competition` (primary alternative) + `competitors[]`
(full list) in project-context.md. These are who users pick *instead of* you.

### QP6 — North Star Benchmarks (propose-then-confirm)

Distinct from comps: these are the **best-in-class bar you measure against**, often
from *other* industries (Stripe for trust, Google for scale). Modeled on a production project's
"North Star Benchmarks" rubric.

Propose a default mapping from the standard quality dimensions, picking an exemplar
that fits this product's domain. Skip a dimension only if clearly irrelevant.

| Dimension | Ask "best-in-class here = ?" — default exemplar |
|-----------|--------------------------------------------------|
| Scale & engineering | Google / AWS |
| Trust, payments & security | Stripe |
| Data & analytics depth | (domain-specific — e.g. the category leader) |
| UI/UX & polish | Linear / Stripe / Vercel |
| Customization & flexibility | Notion / Retool / Tableau |
| Developer experience (if a dev tool) | Stripe / Vercel |

```
Who should we think like? Here's a starting rubric — every audit, review, and
architecture call gets judged against these, not "good enough":
  • Scale & engineering  → {exemplar}
  • Trust & security     → Stripe
  • {domain depth}       → {exemplar}
  • UI/UX                → {exemplar}
  • Flexibility          → {exemplar}

Edit any line, or add a dimension that matters for {project_name}.
```

Capture → `north_star_benchmarks` (dimension → exemplar map) in project-context.md.
For `idea`/`prototype` stage, keep it to 3 dimensions; offer to skip entirely.

---

## Phase 3c: Core Interview

Skip anything answered by auto-scan or Vision.

- **QC1** — Project identity (if not clear)
- **QC2** — Task manager → follow-up for team ID, prefix
- **QC3** — Milestone naming
- **QC4** — Critical rules: "Things that must NEVER happen?"
- **QC5** — Key commands (auto-populate, user confirms)
- **QC6** — "Mistakes that have burned you before?"

---

## Phase 3d: Workflow & Context

**Batch W:** PR merge gates, project checklist, code ownership, CI scaffold.
**Batch C:** Other AI tools, design system, decisions log, honesty rules.

---

## Phase 4: Generate project-context.md

Security check: if any value matches token patterns — STOP.

> **Org layer:** if `~/.claude/orgs/{org_slug}/context.md` exists, omit keys the org
> already defaults (task_manager, storage_backend, secrets_manager, deploy_target, …);
> the resolution order is project > org > global (see `_shared/CONFIG_LAYERS.md`).

> **Canonical schema:** the full field list, annotations, and a worked
> profile live in `skills/_shared/project-context.template.md`. The block below is the
> generated instance — keep its sections in sync with that template; do not add fields
> here that the template doesn't define. Skills resolve every coupling (prefix, team,
> task manager, storage backend, paths, agents) through this file.

```markdown
# Project Context
# Generated by /project-init — safe to commit. NO secrets.

## Identity
project_name: {name}
project_type: web | api | etl | mobile | library | cli | other
project_stage: idea | prototype | mvp | growth | mature
project_user: developer | consumer | internal | enterprise
north_star: {from QV4}
monetization: subscription | usage-based | freemium | open-source | none | tbd
team_size: solo | small | medium | large
competition: {primary alternative from QP2}
competitors:            # full comp list from QP2
  - {Comp A}
  - {Comp B}

## North Star Benchmarks
# Best-in-class bar per dimension (from QP6) — the rubric for audits/reviews/architecture.
# Omit dimensions that don't apply. Exemplars may come from other industries.
north_star_benchmarks:
  scale: {exemplar}
  security: {exemplar}
  data_depth: {exemplar}
  ui_ux: {exemplar}
  flexibility: {exemplar}

## Task Management
task_manager: linear | github | jira | none
task_team_id: {slug}
task_prefix: {XXX}
milestone_noun: milestone | sprint | release | version

## Repository
owner_repo: {owner}/{repo}
main_branch: main | develop | master
branch_pattern: feature/{id}-{slug}

## Stack
languages: [typescript, python]
frameworks: [nextjs, fastapi]
deploy_target: vercel | railway | fly | docker | none
has_ui: true | false
has_tests: true | false

## Database
db: supabase | postgres | sqlite | none
db_schema: public
db_project_id: {id}

## Storage (factory memory — decisions, lifecycle, sessions, gates; see _shared/storage/INTERFACE.md)
# Defaults from `db` above: supabase→supabase, postgres→supabase, sqlite→sqlite, none→none.
storage_backend: supabase | sqlite | none
storage_dsn_env: DATABASE_URL        # env var NAME only (supabase/postgres). NEVER the value.
storage_schema_intel: intel          # decision + idea log namespace
storage_schema_qa: qa                # lifecycle/session/gate namespace

## Factory overlay (optional autonomous pipeline; absent/false → all factory steps no-op)
factory_enabled: false
honesty_mode: OFF                    # FULL | LITE | OFF
# per_milestone_overrides:           # glob → mode, resolved by resolve_honesty_mode()
#   - { glob: "FCT*", mode: FULL }
# machines:                          # pipeline epic-routing targets (factory only)
#   - { name: mothership, role: planning, model: claude-opus-4-8 }

## Agents (capability → concrete agent; skills fall back to generic + skip-if-absent)
agents:
  completion_audit: completion-audit                  # fallback: validate-completion
  spec_audit: spec-audit                        # fallback: general-purpose
  pragmatism_audit: pragmatism-audit # fallback: code-reviewer
  scalability_audit: future-self           # fallback: architect-reviewer
  code_review: code-reviewer
  doc_sync: documentation-engineer

## Paths (each has a built-in default; set only to override)
spec_dir: docs/specs
plan_file: docs/IMPLEMENTATION_PLAN.md
scripts_dir: scripts
roadmap_file: docs/MASTER_ROADMAP.md
# closed_epics_dir: .{project_slug}/closed-epics   # absent → skip epic-close artifact write

## Secret Manager
secret_manager: doppler | dotenv | none
required_env_vars:
  - DATABASE_URL

## Branding
# All branding flows through src/config.ts — never hardcode the product name elsewhere
config_file: src/config.ts

## Areas
# Each area maps to a code (used in milestone ids) and the source paths it touches.
areas:
  - code: {XXX}
    name: {Area Name}
    paths: [ {src/area/} ]
```

---

## Phase 5: Generate Files

> Author **AGENTS.md first** (canonical source), then derive CLAUDE.md and the rest from it.

### AGENTS.md (canonical source, max 200 lines)

Problem, Architecture, Commands table, NEVER rules (WRONG→CORRECT), DB Patterns, Code Standards, Git Workflow, NOT IN SCOPE, Key Entry Points, North Star Benchmarks (if QP6 answered).

**North Star Benchmarks block** lives here as the canonical copy — CLAUDE.md and every
derived file inherit from it. Include only if `north_star_benchmarks` is set; if unset,
add a one-line `Comps: {competitors}` under Problem instead. This is an *active rubric*,
not trivia — phrase it as a standard, mirroring the reference project:
```markdown
## North Star Benchmarks (evaluation rubric — MANDATORY for audits/reviews/architecture)

We measure against best-in-class, not "good enough for {domain}". Every feature, review,
audit, and architecture decision is judged against:

- **Scale & engineering** → {exemplar}
- **Trust & security** → {exemplar}
- **{domain depth}** → {exemplar}
- **UI/UX** → {exemplar}
- **Flexibility & customization** → {exemplar}

Score every audited surface on the relevant dimensions, 1–5 with evidence (no bare
verdicts). "It works" is never the bar — best-in-class, built for the eventual scale is.

Closest comps (who users pick instead): {competitors}.
```

### CLAUDE.md (max 150 lines, derived from AGENTS.md)

Overview, Commands, Architecture, Critical Rules, Coding Standards, Environment vars (names only), Key Entry Points, Branding note, North Star Benchmarks (block copied verbatim from AGENTS.md if set).

**Branding rule always included:**
> All branding references import from `src/config.ts`. Never hardcode the product name in code.

Surface the comp list in the Overview line even when QP6 is skipped.

### Other derived files (all from AGENTS.md)

Each inherits the North Star Benchmarks at its own altitude (skip if unset):

- **GEMINI.md** — standalone, includes Gemini CLI patterns; full benchmarks block verbatim
- `.cursor/rules/project.mdc` — `alwaysApply: true` frontmatter; benchmarks as a "Quality bar" bullet list
- `.cursorrules` — legacy fallback; same condensed bullet list
- `.github/copilot-instructions.md` — max 80 lines, imperative only; one line: "Hold work to: {dim→exemplar, …}. Comps: {competitors}."

### rules/BASE.md

Imperatives only. Never list + Always list. Injected into autonomous prompts.

### GitHub scaffolding

PR template, issue templates, CODEOWNERS, dependabot.yml, ci.yml (opt-in).

### CONTRIBUTING.md, SECURITY.md, DESIGN.md (if UI), DECISIONS_INDEX.md (if enabled)

Standard templates from interview answers.

### Phase 5b: Verification layer bootstrap (VER001A)

Only runs if `task_manager` is configured (project-context.md `## Task
Management`) and the project opts into the factory/planning workflow
(`/ccb`, `/plan-milestone` present in `.claude/skills/`). Skip silently
otherwise — no error, just no verification layer for repos that don't plan
via CCB.

1. **Create the master verification milestone.** Capability-named (never
   `Testing` or `QA` — follow the milestone-naming rule: describes what it
   PROVIDES, e.g. `Walkthrough-Backed Feature Verification Layer`). Give it
   an id following the project's area-code convention (e.g. `VER001A`).
   Body includes:
   - the honesty-stack block (same shape as any other milestone — see
     `## Honesty Stack` in project-context.md)
   - a roll-up section that will later list every walkthrough-twin child
     issue, grouped by source milestone
   - empty (but live, not draft) gate epics: `VERIFY`, `HARDEN`,
     `VERIFY-HUMAN` — created with zero tasks, ready to receive twins as
     `/ccb` Phase 3.26 and `/plan-milestone` Step 2b.1 spawn them.

2. **Write `master_verification_milestone` into project-context.md**, in a
   new `## Verification` section:

   ```yaml
   ## Verification (VER001A)
   # Points /plan-milestone, /ccb, and the walkthrough engine at the master
   # verification milestone — every feature epic's walkthrough twin + matrix
   # row lives under this milestone.
   master_verification_milestone: {milestone_code} ({milestone_uuid_or_id})
   ```

3. **Scaffold `config/test_coverage_matrix.json`** — empty rows array plus
   a `$schema_note` describing the row shape (matches the row `/ccb` Phase
   3.26 step 3 writes):

   ```json
   {
     "$schema_note": "One row per feature epic. Written by /ccb Phase 3.26 step 3 or /plan-milestone Step 2b.1 fallback. Fields: epic_id, milestone_id, walkthrough_issue, spec_clauses[], walkthrough (bool — has a human-walkable flow, vs machine-only), status (planned|in_progress|verified).",
     "rows": []
   }
   ```

4. **Install CI workflow templates** from shared-config
   (`~/.claude/hooks/templates/` or the equivalent in this repo's
   `.github/workflows/`), each opt-in per the QW4-style confirm prompt used
   for `ci.yml` in Phase 5:
   - `coverage-growth-gate.yml` — blocks a PR that adds an app-router
     surface / `CREATE VIEW public.v_*` / public RPC without a matching
     matrix row (mirrors the FAB001G coverage-growth gate pattern — see the
     project `CLAUDE.md` "Coverage growth gate").
   - `walkthrough-health.yml` (cron) — reconciler that walks
     `test_coverage_matrix.json` rows with `walkthrough_issue` pointing at
     a closed/missing issue, or `status: planned` older than N days with no
     activity, and files a Linear issue.
   - `r50-playwright-gate.yml` — blocking gate requiring a passing
     Playwright test on any dashboard/page/component/route PR (only for
     projects with a `dashboard` area).

5. **GROW-WITH-SPECS note.** Add a line to the reconciler's scope (in the
   `walkthrough-health.yml` template, or the H5 spec-sync hook's
   `config/doc_mappings.json` if this repo has one): any new file matching
   `docs/specs/**/*.md` with no epic row in `test_coverage_matrix.json`
   referencing it under `spec_clauses` gets flagged within one reconciler
   cycle (default: the cron's own interval — do not invent a stricter SLA).
   This is what keeps new specs from silently shipping without a
   walkthrough twin.

Report the manifest of what was created (milestone id, context key,
matrix file, workflow files) in the Phase 7 confirm step alongside the
other generated files.

---

## Phase 6: Gitignore

Add if not present: `.env.local`, `.claude/settings.local.json`, `.claude/memory/`

Never gitignore AI context files or project-context.md.

---

## Phase 7: Confirm + Commit

Print manifest, confirm, write, commit.

```
Files to generate:
  NEW  .claude/project-context.md
  NEW  CLAUDE.md
  NEW  AGENTS.md                         ← canonical source
  NEW  GEMINI.md
  NEW  .cursor/rules/project.mdc
  NEW  .cursorrules
  NEW  .github/copilot-instructions.md
  NEW  rules/BASE.md
  NEW  CONTRIBUTING.md
  NEW  SECURITY.md
  NEW  DESIGN.md                         (if has_ui)
  NEW  docs/specs/DECISIONS_INDEX.md     (if QC9 = docs/specs)
  NEW  .github/PULL_REQUEST_TEMPLATE.md
  NEW  .github/ISSUE_TEMPLATE/
  NEW  .github/dependabot.yml
  NEW  .github/workflows/ci.yml          (if QW4 = Yes)
  UPDATED  .gitignore
```

Print summary:
```
✓ {N} files written.

What to fill in next:
  → CLAUDE.md ## Project-Specific Rules
  → AGENTS.md ## Architecture
  → .claude/project-context.md task_team_id

Service setup (run any of these next):
  /project-init setup supabase
  /project-init setup doppler
  /project-init setup vercel
  /project-init setup github-app
  /project-init setup linear
  /project-init setup railway
  /project-init setup sentry
  /project-init setup posthog
  /project-init setup shared-config   # link shared agents + hooks (shared-config pattern)

Keep AI files in sync after changes:
  /project-init sync
  /project-init update rules
```

---

## Non-Interactive Mode (`CLAUDE_AUTO=1`)

When `CLAUDE_AUTO=1` and `project-setup.json` exists, skip all prompts.

### project-setup.json schema

```json
{
  "project_name": "My App",
  "project_type": "web|api|etl|mobile|library|cli|other",
  "project_description": "One sentence.",
  "task_manager": "linear|github|jira|none",
  "task_team_id": "team-slug",
  "task_prefix": "APP",
  "milestone_noun": "milestone|sprint|release|version",
  "main_branch": "main|develop|master",
  "branch_pattern": "feature/{id}-{slug}",
  "languages": ["typescript"],
  "frameworks": ["nextjs"],
  "deploy_target": "vercel|railway|fly|docker|none",
  "db": "supabase|postgres|sqlite|none",
  "has_ui": true,
  "secret_manager": "doppler|dotenv|none",
  "project_stage": "idea|prototype|mvp|growth|mature",
  "project_user": "developer|consumer|internal|enterprise",
  "north_star": "500 paying teams in 6 months",
  "monetization": "subscription|usage|freemium|open-source|none",
  "team_size": "solo|small|medium|large",
  "competition": "Closest alternative",
  "competitors": ["Comp A", "Comp B"],
  "north_star_benchmarks": {
    "scale": "Google",
    "security": "Stripe",
    "ui_ux": "Linear"
  },
  "hard_constraints": [],
  "not_in_scope": [],
  "critical_rules": [],
  "commands": {
    "dev": "npm run dev",
    "build": "npm run build",
    "test": "npm test",
    "lint": "npm run lint"
  },
  "pr_gates": ["CI green", "1 approval"],
  "design_system": "shadcn|tailwind|mui|none",
  "decisions_log": "docs/specs/DECISIONS_INDEX.md|none",
  "generate_ci": false,
  "required_env_vars": ["DATABASE_URL"]
}
```

All fields optional. Never put secret values in this file.

---

## Mode: `sync`

Diff all AI files against AGENTS.md. Report drift. Offer to re-sync.

| File | Sections to diff |
|------|-----------------|
| GEMINI.md | Overview, Critical Rules, Commands, North Star Benchmarks |
| .cursor/rules/project.mdc | Critical Rules, Architecture, Commands, North Star Benchmarks |
| .cursorrules | Same |
| .github/copilot-instructions.md | Critical Rules, Commands, North Star Benchmarks (one-liner) |
| rules/BASE.md | Never list, Always list |
| CLAUDE.md | Critical Rules, Commands, North Star Benchmarks (extras OK — flag contradictions only) |

Print drift table. Ask: "Re-sync? (yes / show diffs first / skip)"

---

## Mode: `update <section>`

| Section | Re-runs | Regenerates |
|---------|---------|-------------|
| `vision` | Vision interview | AGENTS.md overview, CLAUDE.md overview |
| `benchmarks` | QP2 + QP6 (comps + north stars) | CLAUDE.md North Star Benchmarks, project-context.md |
| `stack` | Stack advisory | project-context.md stack, architecture sections |
| `rules` | QC4+QC6+QC10 | Critical Rules in all AI files + rules/BASE.md |
| `workflow` | QW1–QW4 | PR template, CODEOWNERS, CI |
| `github` | None | Re-scaffolds .github/ from existing context |
| `ai-files` | None | Runs sync — re-derives all AI files from AGENTS.md |

---

## Mode: `migrate`

Bring an EXISTING repo's `.claude/project-context.md` up to the current canonical schema
(`skills/_shared/project-context.template.md`) so the repo-agnostic lifecycle skills resolve
cleanly. Idempotent — never overwrites values the Operator already set.

**Step 1 — Locate.** Read `.claude/project-context.md`. If absent → "No project context found.
Run `/project-init` (full) or `/project-init --bootstrap` first." and stop.

**Step 2 — Diff vs template.** Compare the file's sections against the canonical template.
For each section the file is MISSING, add it with **inferred defaults** (never clobber existing keys):
- `storage` → `storage_backend` inferred from existing `db` (supabase/postgres→`supabase`, sqlite→`sqlite`, else `none`); `storage_dsn_env` from existing env var; `intel`/`qa` schema defaults.
- `factory` → `factory_enabled: false`, `honesty_mode: OFF` (only factory-style repos flip these on).
- `agents` → the capability→name map with generic fallbacks.
- `paths` → defaults (`spec_dir`, `plan_file`, `scripts_dir`, `roadmap_file`).
Print a diff preview; apply only on confirmation (or immediately if `CLAUDE_AUTO=1`).

**Step 3 — Ensure shared layer reachable.** Confirm `.claude/skills/_shared/adapters/` and
`.claude/skills/_shared/storage/` exist (symlinked/copied from shared-config per `setup shared-config`).
If missing, offer to link them.

**Step 4 — Coupling audit.** Run the coupling lint over the repo's skills and report residual
hardcoding the migration can't fix automatically:
```bash
uv run .claude/skills/skill-scanner/scripts/lint_coupling.py .claude/skills
```

**Step 5 — Summary.** Print sections added, values inferred, and any lint warnings. Commit nothing
without confirmation. Suggest: "Review `.claude/project-context.md`, then your lifecycle skills are agnostic-ready."

> Multi-repo: to migrate every repo sharing this shared-config, run `migrate` in each (a thin
> wrapper over `sync-skills` can batch this once single-repo migrate is proven).

> **Verification-layer bootstrap note (2026-07-09):** the created master-verification tracker issue MUST embed the operator quickstart header defined in `skills/walkthrough/SKILL.md §EMBEDDED OPERATOR INSTRUCTIONS` (manual link + 5-line quickstart + mech-first run pattern).

## Judgment weave (see /judgment)

- **Interview:** stack, naming, and service picks are one-way doors — triage them with **`/door`** before scaffolding.
- **`sync` mode:** when the scaffold and the repo disagree about reality, escalate to **`/drift`** to decide which side is lying.
