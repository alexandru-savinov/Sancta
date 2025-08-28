## Sancta Governance Compact (concise)

Purpose
- A short, human-readable contract that makes trade-offs explicit: who decides, when, and what observable guarantees are required. This compact guides governance choices before any technical enforcement.

Scope
- Applies to governance decisions, exception handling, and emergency actions across the Sancta home and its Rooms model (`Porch`, `Foyer`, `Study`, `Vault`). Does not replace detailed runbooks or IaC pledges; it sets the normative defaults that those artifacts follow.

Principles (brief)
- Owner agency first: the Owner has final, contextual authority inside their home.
- Systemic assurance: changes must be reviewable, auditable, and reversible by default.
- Proportionality: controls and scrutiny scale with the Room sensitivity.
- Consent and legibility: actions must be explained plainly and reversible where possible.

Roles & Decision Rights
- Owner: ultimate decision authority for personal data, Vault actions, and exemptions that materially alter privacy or control.
- Delegated Trustee: appointed by Owner for emergency or succession; acts only with an explicit delegation record.
- Reviewer(s): human reviewers required by the IaC pledge for non-trivial changes (default: ≥1). Reviewers verify safety, rollback plans, and evidence requirements.
- Emergency Actor: the person(s) authorized to fast-merge or act outside normal review when availability or safety is at risk; must backfill IaC and audit within 24h.

Rooms → Default Automation Envelope
- Porch (public): automation-friendly. Defaults: automated updates and sync; lightweight audit.
- Foyer (shared): cautious automation. Defaults: scheduled automation with named owners; explicit timeboxes for sharing.
- Study (private): interactive-by-default. Defaults: no external sync without fresh consent; automation allowed for non-sensitive maintenance with receipts.
- Vault (intimate): interactive-only unless explicit, timeboxed exception. Defaults: air-gapped behavior, encrypted local logs, strong human gates.

Exception Process (human-first)
- Any deviation from defaults requires an Exception record containing: reason, scope, mitigations, expiry date, owner, and visible approval by Owner or delegated authority.
- Exceptions auto-expire and must be actively renewed; expired exceptions revert to defaults automatically.

Emergency Path (availability/security)
- Emergency Actor may act immediately to restore availability/security.
- Mandatory follow-up within 24 hours: open incident record, backfill IaC, publish a short retrospective and verification evidence, and set time-limited access where applicable.

Consent Ritual (how "yes" is asked and remembered)
- Sensitive actions must present: Purpose, Scope, Duration, Who Benefits, and a clear undo path.
- Owner consent should be recorded in a human-readable receipt and stored with the action's audit entry.

Audit & Evidence (what "safe" looks like)
- Every sensitive change produces a receipt with: timestamp, actor, inputs, result, undo instruction, evidence of verification, and mode (DryRun/Safe/Standard/Comprehensive).
- Vault-area receipts are encrypted and local by default; visible to Owner and authorized delegates only.

Tripwires & Mandatory Human Gates
- Automatic pause and human review if: irreversible operations are requested, secrets/keys change, new external dependencies touch Vault data, or cross-room lateral access is requested.

Failure Modes & Postmortem
- For any incident: record what happened, root cause, monitoring gaps, rollback steps taken, and remedial action. Postmortems must be short, factual, and linked to the incident record.

Governance Review Cadence
- Quarterly review of major policies and exception log by Owner + at least one independent reviewer. Emergency and high-risk exceptions receive expedited review.

Quick Operational Rules (practical guardrails)
- Mode selection mandatory in PRs and actions: state DryRun/Safe/Standard/Comprehensive.
- No lasting click-ops without codification within 24h.
- All grants must include expiry by default.

Next steps (non-technical)
- Share this compact with stakeholders for sign-off.
- After sign-off, update PR template to include Mode and Exception fields (technical follow-up).
- Establish a simple incident/exception log (human process) and assign an initial Governance Steward.

Owner & Steward
- Owner: [@alexandru-savinov]
- Initial Governance Steward: [@alexandru-savinov]

End of compact — keep short, human, and actionable.
