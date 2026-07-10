---
name: trigger-agents
origin: authored
public: true
description: AI agent patterns with Trigger.dev — orchestration, parallelization, routing, evaluator-optimizer, and human-in-the-loop. Use when building LLM-powered factory tasks that need parallel workers, approval gates, tool calling, or multi-step agent workflows.
---

# AI Agent Patterns with Trigger.dev

Build production-ready AI agents using Trigger.dev's durable execution.

## Pattern Selection

```
Need to...                              → Use
─────────────────────────────────────────────────────
Process items in parallel               → Parallelization
Route to different models/handlers      → Routing
Chain steps with validation gates       → Prompt Chaining
Coordinate multiple specialized tasks   → Orchestrator-Workers
Self-improve until quality threshold    → Evaluator-Optimizer
Pause for human approval                → Human-in-the-Loop (waitpoints)
```

## Core Patterns

### 1. Prompt Chaining (Sequential with Gates)

```typescript
export const translateCopy = task({
  id: "translate-copy",
  run: async ({ text, targetLanguage, maxWords }) => {
    const draft = await generateText({ model: openai("gpt-4o"), prompt: `Write about: ${text}` });

    // Gate: validate before continuing
    if (draft.text.split(/\s+/).length > maxWords) throw new Error("Draft too long");

    const translated = await generateText({
      model: openai("gpt-4o"),
      prompt: `Translate to ${targetLanguage}: ${draft.text}`,
    });
    return { draft: draft.text, translated: translated.text };
  },
});
```

### 2. Parallelization (Fan-out)

```typescript
export const analyzeContent = task({
  id: "analyze-content",
  run: async ({ text }) => {
    const { runs: [sentiment, summary, moderation] } = await batch.triggerByTaskAndWait([
      { task: analyzeSentiment, payload: { text } },
      { task: summarizeText, payload: { text } },
      { task: moderateContent, payload: { text } },
    ]);
    return {
      sentiment: sentiment.ok ? sentiment.output : null,
      summary: summary.ok ? summary.output : null,
    };
  },
});
```

### 3. Orchestrator-Workers (Fan-out/Fan-in)

```typescript
export const factChecker = task({
  id: "fact-checker",
  run: async ({ article }) => {
    // Extract claims first
    const { runs: [extractResult] } = await batch.triggerByTaskAndWait([
      { task: extractClaims, payload: { article } },
    ]);
    if (!extractResult.ok) throw new Error("Failed to extract claims");

    // Verify all claims in parallel
    const { runs } = await batch.triggerByTaskAndWait(
      extractResult.output.map(claim => ({ task: verifyClaim, payload: claim }))
    );
    return { verifications: runs.filter(r => r.ok).map(r => r.output) };
  },
});
```

### 4. Evaluator-Optimizer (Self-Refining)

```typescript
export const refineTranslation = task({
  id: "refine-translation",
  run: async ({ text, targetLanguage, feedback, attempt = 0 }) => {
    if (attempt >= 5) return { text, status: "MAX_ATTEMPTS" };

    const translation = await generateText({ model: openai("gpt-4o"), prompt: feedback
      ? `Improve based on feedback: ${feedback}\n\nOriginal: ${text}`
      : `Translate to ${targetLanguage}: ${text}` });

    const evaluation = await generateText({
      model: openai("gpt-4o"),
      prompt: `Evaluate translation quality. Reply APPROVED or provide specific feedback:\n${translation.text}`,
    });

    if (evaluation.text.includes("APPROVED")) return { text: translation.text, status: "APPROVED" };

    return refineTranslation.triggerAndWait({
      text, targetLanguage, feedback: evaluation.text, attempt: attempt + 1,
    }).unwrap();
  },
});
```

## Error Handling

```typescript
const { runs } = await batch.triggerByTaskAndWait([...]);
for (const run of runs) {
  if (run.ok) console.log(run.output);
  else console.error(run.error, run.taskIdentifier);
}
```

## Quick Reference

```typescript
// Trigger and wait
const result = await myTask.triggerAndWait(payload);
if (result.ok) console.log(result.output);

// Batch different tasks (typed)
const { runs } = await batch.triggerByTaskAndWait([
  { task: taskA, payload: { foo: 1 } },
  { task: taskB, payload: { bar: "x" } },
]);

// Self-recursion
return myTask.triggerAndWait(newPayload).unwrap();
```
