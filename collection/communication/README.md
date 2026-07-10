# Communication

Hand work off cleanly — to the next session or to another agent.

[← Back to the collection index](../../README.md)

### Skills (2)

| Unit | What it does | When to call | Install |
|---|---|---|---|
| `brief` | Generate a copy-paste prompt to brief a non-Claude agent (Codex, Gemini, Ollama, Cursor) on an epic or task | — | `./install.sh --only brief` |
| `handoff` | Context-rot prevention: write a structured handoff document capturing the current session state so you can /clear and continue in a fresh session wit… | Use when: context >70%, session >15 turns, hitting limits, or switching tasks mid-work. Invoke: /handoff [optional-filename] | `./install.sh --only handoff` |

Install the whole category at once: `./install.sh --category communication`
