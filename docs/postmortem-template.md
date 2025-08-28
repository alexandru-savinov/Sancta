# Postmortem Template (short & human)

Use this template for incidents requiring analysis. Keep it concise (one page preferred). Link it from the incident log.

Title: Postmortem — <short description>
ID: post-<incident-id> (match the incident entry)
Date: YYYY-MM-DD
Owner: (person responsible for postmortem)

Summary (2–3 lines)
- What happened and the immediate impact.

Timeline (bullet timestamps)
- T+0: event detected — who noticed
- T+5m: initial action
- T+1h: mitigation performed
- T+24h: backfill completed (if applicable)

Root cause (short)
- One-sentence root cause and the evidence that supports it.

Contributing factors
- 2–4 bullets: other conditions that made this worse (process, tooling, communication gaps).

Mitigation & rollforward
- Immediate mitigation taken.
- Long-term fixes planned (owner and ETA).

Detection & monitoring
- How was this detected? What monitoring/metrics missed it or helped detect it?

Undo & recovery steps
- What was done to recover? Include human-readable undo steps and verification evidence.

Lessons learned & action items
- 3–5 concise items with owners and due dates.

Signals to watch
- 3 metrics/logs/alerts to track to ensure the fix holds.

Closure
- Postmortem reviewed by: Owner + Governance Steward + Reviewer
- Date closed: YYYY-MM-DD

Link to incident record: docs/incident-exception-log.md#<id>
