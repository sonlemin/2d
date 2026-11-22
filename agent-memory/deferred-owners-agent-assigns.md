---
name: deferred-owners-agent-assigns
description: Assign deferred-work owners myself (no "(proposed)", never ask sonlm); never leave a ledger item ownerless
metadata:
  type: feedback
---

When deferring anything to `deferred-work.md`, assign the owner myself as `→ **Owner: <story/epic>** — why` (no "(proposed)") and name it in the report; don't ask sonlm to confirm. Never leave a deferred item without an owner.

**Why:** sonlm, 2026-11-13: "no need to ask me to check for owner for defers. Just do it your own. Make sure dont let any ownerless defers." The ledger's 7 "(proposed)" marks were dropped then; project-context's Testing rule was updated to match.

**How to apply:** in gds-code-review / dev-story / quick-dev defers, pick the story whose scope naturally covers the item; run test_deferred_owners before finishing. Related: [[readiness-needs-work]].
