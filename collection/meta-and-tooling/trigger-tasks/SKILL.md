---
name: trigger-tasks
origin: authored
public: true
description: Build AI agents, workflows and durable background tasks with Trigger.dev. Use when creating tasks, triggering jobs, handling retries, scheduling cron jobs, or implementing queues and concurrency control in the factory.
---

# Trigger.dev Tasks

Build durable background tasks that run reliably with automatic retries, queuing, and observability.

## When to Use

- Creating background jobs or async workflows in the factory
- Building AI agents that need long-running execution
- Scheduling recurring tasks (cron companions)
- Any factory work that shouldn't block the main application

## Critical Rules

1. **Always use `@trigger.dev/sdk`** — never use deprecated `client.defineJob`
2. **Check `result.ok`** before accessing `result.output` from `triggerAndWait()`
3. **Never use `Promise.all`** with `triggerAndWait()` or `wait.*` calls
4. **Export tasks** from files in your `trigger/` directory

## Basic Task

```ts
import { task } from "@trigger.dev/sdk";

export const processData = task({
  id: "process-data",
  retry: {
    maxAttempts: 10,
    factor: 1.8,
    minTimeoutInMs: 500,
    maxTimeoutInMs: 30_000,
  },
  run: async (payload: { userId: string; data: any[] }) => {
    console.log(`Processing ${payload.data.length} items`);
    return { processed: payload.data.length };
  },
});
```

## Triggering Tasks

```ts
// Fire and forget
const handle = await tasks.trigger<typeof processData>("process-data", { userId: "123", data: [] });

// Wait for result
const result = await childTask.triggerAndWait({ data: "value" });
if (result.ok) console.log("Output:", result.output);

// Batch
const results = await myTask.batchTriggerAndWait([
  { payload: { data: "item1" } },
  { payload: { data: "item2" } },
]);
```

## Waits

```ts
await wait.for({ seconds: 30 });
await wait.for({ minutes: 5 });
await wait.until({ date: new Date("2024-12-25") });
```

> Waits > 5 seconds are checkpointed — no compute charge during wait.

## Concurrency & Queues

```ts
export const oneAtATime = task({
  id: "sequential-task",
  queue: { concurrencyLimit: 1 },
  run: async (payload) => { /* Only one instance runs at a time */ },
});
```

## Scheduled Tasks (Cron)

```ts
import { schedules } from "@trigger.dev/sdk";

export const dailyTask = schedules.task({
  id: "daily-cleanup",
  cron: "0 0 * * *",
  run: async (payload) => {
    // payload.timestamp, payload.timezone, payload.scheduleId
  },
});
```

## Error Handling

```ts
import { task, retry, AbortTaskRunError } from "@trigger.dev/sdk";

export const resilientTask = task({
  id: "resilient-task",
  retry: { maxAttempts: 10, factor: 1.8, minTimeoutInMs: 500, maxTimeoutInMs: 30_000 },
  catchError: async ({ error }) => {
    if (error.code === "FATAL_ERROR") throw new AbortTaskRunError("Cannot retry");
    return { retryAt: new Date(Date.now() + 60000) };
  },
  run: async (payload) => {
    const result = await retry.onThrow(async () => unstableApiCall(payload), { maxAttempts: 3 });
  },
});
```

## Machine Presets

| Preset | vCPU | RAM |
|--------|------|-----|
| small-1x | 0.5 | 0.5 GB (default) |
| medium-1x | 1 | 2 GB |
| large-1x | 4 | 8 GB |
| large-2x | 8 | 16 GB |

## Best Practices

1. Make tasks idempotent — safe to retry without side effects
2. Use queues to prevent overwhelming external services
3. Configure retries with exponential backoff
4. Track progress with `metadata.set()` for long-running tasks
5. Match machine size to computational requirements
