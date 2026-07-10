---
name: find-bugs
origin: authored
public: true
description: Find bugs, security vulnerabilities, and code quality issues in local branch changes. Use when asked to review changes, find bugs, security review, or audit code on the current branch. ALWAYS run before committing.
---

# Find Bugs

Review changes on this branch for bugs, security vulnerabilities, and code quality issues.

## Phase 1: Complete Input Gathering

1. Get the FULL diff: `git diff $(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')...HEAD`
2. If output is truncated, read each changed file individually until you have seen every changed line
3. List all files modified in this branch before proceeding

## Phase 2: Attack Surface Mapping

For each changed file, identify and list:

* All user inputs (request params, headers, body, URL components)
* All database queries
* All authentication/authorization checks
* All session/state operations
* All external calls
* All cryptographic operations

## Phase 3: Security Checklist (check EVERY item for EVERY file)

* [ ] **Injection**: SQL, command, template, header injection
* [ ] **XSS**: All outputs in templates properly escaped?
* [ ] **Authentication**: Auth checks on all protected operations?
* [ ] **Authorization/IDOR**: Access control verified, not just auth?
* [ ] **CSRF**: State-changing operations protected?
* [ ] **Race conditions**: TOCTOU in any read-then-write patterns?
* [ ] **Session**: Fixation, expiration, secure flags?
* [ ] **Cryptography**: Secure random, proper algorithms, no secrets in logs?
* [ ] **Information disclosure**: Error messages, logs, timing attacks?
* [ ] **DoS**: Unbounded operations, missing rate limits, resource exhaustion?
* [ ] **Business logic**: Edge cases, state machine violations, numeric overflow?

## Phase 4: Project-Specific Checks

* [ ] **Goal filter**: No `event_type == 'Goal'` — must use `event_variant == 'Shot_Goal'`
* [ ] **No iterrows**: No `.iterrows()` in any Python file
* [ ] **No client-side aggregation**: No `.reduce()` or `.filter().length` for stats in React
* [ ] **No in-memory state**: No global dicts for distributed data
* [ ] **Key format**: entity keys match DP/TM/CL/OR/GM/FE/FS prefixes
* [ ] **No god objects**: No file over 2000 lines

## Phase 5: Verification

For each potential issue:

* Check if it's already handled elsewhere in the changed code
* Search for existing tests covering the scenario
* Read surrounding context to verify the issue is real

## Phase 6: Pre-Conclusion Audit

Before finalizing, you MUST:

1. List every file reviewed and confirm you read it completely
2. List every checklist item — found issues or confirmed clean
3. List any areas you could NOT fully verify and why
4. Only then provide final findings

## Output Format

**Prioritize**: security vulnerabilities > CLAUDE.md violations > bugs > code quality

For each issue:

* **File:Line** — Brief description
* **Severity**: Critical/High/Medium/Low
* **Problem**: What's wrong
* **Evidence**: Why this is real
* **Fix**: Concrete suggestion

If you find nothing significant, say so. Do not invent issues.

Do not make changes — just report findings.

## Judgment weave (see /judgment)

- **Zero findings:** run **`/refute`** on "no bugs found" before trusting it.
- **Familiar bug:** run **`/altitude`** — if you've seen it before, fix the layer that keeps producing it.
