# 5. Roadmap

Sequenced so the highest-risk, highest-value thing — **collections stop being
merged by hand** — happens as early as possible, and nothing is built before
the thing it depends on.

## Phase 0 — Decide and prepare (1–2 weeks)

- Confirm the open questions in [§6](06-open-questions.md).
- Choose cut-off date and opening-balance approach.
- Run the data-quality profile on all 13 live sheets; fix in-sheet what is
  cheaper to fix there.
- Stand up staging Postgres, repo, CI.
- Get the Nidhi compliance thresholds confirmed in writing by your auditor.

**Exit:** decisions written down; profile report reviewed.

## Phase 1 — Foundation (3–4 weeks)

- Schema, constraints, RLS, append-only triggers.
- Auth, roles, users for all 11 officers.
- Products configured with real rates, grace days, OD cap.
- Migration scripts + reconciliation harness, run repeatedly against staging.

**Exit:** staging database reconciles to ₹0.00 against the live sheets.

## Phase 2 — Collection app (4–5 weeks) — *the core of the project*

- Offline-first PWA: today's round, collect, offline receipt, sync queue.
- Receipt-block allocation for offline numbering.
- Day-book: denomination count, variance, supervisor acceptance.
- Bengali/English toggle throughout.
- Pilot with **one officer for two weeks** before widening.

**Exit:** one officer runs a full week doorstep-only on the app, day-book
balancing daily.

## Phase 3 — Office app (4–5 weeks)

- Member onboarding with KYC capture; account opening (RD, FD, loan).
- Loan origination: application → sanction → disbursal, with approval limits.
- Reversal/adjustment workflow with reasons and approval.
- Core reports: day-book, collection sheet, arrears ageing, portfolio, member
  statement, officer performance.
- Statement printing/PDF for members.

**Exit:** all daily office work possible without opening a spreadsheet.

## Phase 4 — Automation (2–3 weeks)

- Nightly interest accrual (deposit and FD), penalty/OD engine.
- Arrears ageing and NPA classification.
- Credit and loan re-scoring, with history.
- WhatsApp reminders wired to due-date events, using existing API.
- Balance-projection rebuild-and-compare alarm.

**Exit:** overnight jobs run unattended for a week with no manual correction.

## Phase 5 — Parallel run and cutover (4–5 weeks)

- All officers on the app; sheets maintained in parallel.
- Daily reconciliation; drive differences to zero.
- Final migration, sign-off, freeze sheets to view-only.

**Exit:** the database is the book of record. No more merges.

## Phase 6 — After go-live (ongoing)

- Statutory returns (NDH-1/2/3) as standing reports.
- Optional back-load of pre-cut-off history from `Collection_Abstract`.
- Member self-service: balance and statement by WhatsApp or a simple portal.
- Bluetooth thermal receipt printers, if members want paper.
- Branch/multi-entity support if you expand.
- Business intelligence: collection efficiency by officer, area and product.

## Timeline

**Roughly 5–7 months** to full cutover with a small team working steadily.
Phases 2 and 3 can overlap if two developers are available; Phase 5 cannot be
compressed, because it is bounded by a real collection cycle rather than by
effort.

## What gets better, and when

| After | You get |
|---|---|
| Phase 2 | No more manual merges. Cash reconciled daily. Real accountability per officer. |
| Phase 3 | No spreadsheet in daily operations. Members get real statements. |
| Phase 4 | Interest, penalties and reminders stop being manual and stop being wrong. |
| Phase 5 | One book of record. Audit-ready continuously rather than annually. |

## Cost shape

The recurring infrastructure cost for a business of ~200 members is small —
managed Postgres and hosting in the tens of US dollars per month at this
scale, plus existing WhatsApp API charges. **The real cost is development
time**, and the real saving is the hours currently spent merging workspaces
and hunting differences, plus the losses that daily cash reconciliation
prevents.

---

*Next: [6. Open Questions](06-open-questions.md)*
