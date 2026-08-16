# 2. Target Architecture

## 2.1 The one decision everything else follows from

**Stop storing balances. Start storing events, and derive balances from them.**

Today `Total Dep Bal` is a number in a cell. In the new system there is no
such cell. There is an append-only list of every rupee that ever moved, and
the balance is the sum of that list. If a member asks "why is my balance
₹5,990?", the system answers with the 47 receipts that add up to it.

This single change dissolves most of the five problems in the previous
document at once:

- Merge conflicts stop existing. Two officers posting collections are just two
  *inserts* into a list. Inserts never conflict; only overwrites do.
- The dated backup copies stop being necessary, because nothing is ever
  overwritten and any past state is a query with a date filter.
- Audit becomes free rather than a feature — the log *is* the audit trail.
- Double-posting is preventable, because each entry carries a client-generated
  idempotency key and the second insert of the same key is rejected.

Everything below is in service of this.

## 2.2 System shape

```
┌────────────────────────────────────────────────────────────┐
│  FIELD (Android phones, patchy rural 4G)                   │
│  Collection PWA — installable, works fully offline          │
│  • today's round, sorted by route                          │
│  • collect deposit / loan EMI, print-free digital receipt   │
│  • end-of-day cash denomination + handover                 │
│         │  local queue (IndexedDB), syncs when signal       │
└─────────┼──────────────────────────────────────────────────┘
          │  idempotent POSTs
┌─────────▼──────────────────────────────────────────────────┐
│  API  (Next.js route handlers / server actions)            │
│  • authn + role checks      • posting rules                │
│  • idempotency keys         • event emission               │
└─────────┬──────────────────────────────────────────────────┘
          │
┌─────────▼──────────────────────────────────────────────────┐
│  PostgreSQL                                                │
│  ledger_entry  ← append-only, the book of record           │
│  accounts / customers / products  ← current-state tables   │
│  balances      ← materialised projection, rebuildable      │
│  audit_log     ← who did what, immutable                   │
│  Row-Level Security: officer sees only their own members   │
└─────────┬──────────────────────────────────────────────────┘
          │
┌─────────▼───────────────┐  ┌────────────────────────────────┐
│  OFFICE web app          │  │  Background jobs                │
│  members, accounts,      │  │  • nightly interest accrual     │
│  loan origination,       │  │  • arrears / NPA ageing         │
│  approvals, day-book     │  │  • credit re-scoring            │
│  reconciliation, reports │  │  • WhatsApp due reminders       │
│  NDH / statutory returns │  │  • balance projection rebuild   │
└──────────────────────────┘  └────────────────────────────────┘
```

## 2.3 Why offline-first is non-negotiable

Your officers collect at doorsteps in Khosalpur, Aranghata, Jugolbari,
Narayanpur, Babupara, Shikri and Nimtala. Connectivity there is not a given.

An app that needs signal to record a collection will fail at the exact moment
cash changes hands — and staff will fall back to a paper notebook, which
recreates the merge problem you are trying to escape.

So the collection app must:

- **Pre-load the officer's whole round** each morning while on Wi-Fi at the office
- **Record collections into a local queue** with no network at all
- **Issue the member a receipt immediately**, offline, with a receipt number
  reserved from a block handed out at sync time
- **Sync opportunistically** and survive the phone dying mid-round
- **Never let the officer see a stale balance as if it were live** — show the
  as-of timestamp

The rule that makes this safe: **a collection is only ever an append**. An
officer can add a receipt offline. An officer can never *edit* or *delete* one
offline. Corrections are reversal entries made in the office by a supervisor.
That restriction is what allows conflict-free sync.

## 2.4 Roles

| Role | Can do |
|---|---|
| **Collection Officer** | See only their own assigned members; record collections; end-of-day cash handover; no edits, no deletes, no balances of other officers' members |
| **Supervisor / Cashier** | Verify and accept day-end handover; post reversals with reason; reassign members between officers |
| **Manager** | Member onboarding, loan sanction and disbursal, FD/RD opening and closure, waivers within limits, all reports |
| **Director / Admin** | Product and interest-rate configuration, user management, limits, statutory returns |
| **Auditor** | Read-only across everything, including the full audit trail. Cannot change anything. |

The `Coll Officer` column becomes a real foreign key to a real user account
with a real login — which is what turns "GS" from a two-letter string into an
accountable person.

## 2.5 The day-book: the control that makes cash safe

This does not exist today and is the highest-value operational addition.

At end of day, each officer's app shows: *system says you collected ₹14,350
across 38 receipts.* The officer enters the physical cash by denomination
(₹500 × 21, ₹200 × 8, …). If the two agree, they hand over and the supervisor
accepts. If they differ, the difference is recorded as a named shortage or
excess against that officer on that date — never silently absorbed.

Cash that is counted daily and reconciled to a receipt list is cash that
cannot quietly leak. For a doorstep-collection lender this is the single most
important internal control there is.

## 2.6 Technology recommendation

Chosen for a small team that needs this to run for years at low cost, not for
novelty.

| Layer | Choice | Why |
|---|---|---|
| Database | **PostgreSQL** (managed — Supabase or Neon) | Real constraints, real transactions, row-level security, exact `NUMERIC` money. Nothing about this workload needs anything more exotic. |
| App | **Next.js (TypeScript)** | One codebase serves the office app, the field PWA and the API. One language across the stack for a small team. |
| Field app | **PWA** — installable, service worker, IndexedDB queue | Installs from a link, updates itself, no Play Store review cycle, one codebase for Android and desktop. Revisit native only if you later need hardware Bluetooth receipt printers. |
| Auth | Managed provider with phone-OTP | Staff know OTP login. Passwords in a rural field context get shared and written down. |
| Hosting | Vercel or similar, **India region** | Keep member data resident in India. |
| Money type | `NUMERIC(14,2)` — **never float** | Floating point silently loses paise, and paise across 200 members across years become real reconciliation failures. |
| Reporting | SQL views + server-rendered pages; CSV/PDF export | Directors will still want a spreadsheet — give them export, not a spreadsheet-shaped database. |
| Notifications | Existing WhatsApp Business API | Already working; becomes an event subscriber rather than a manual send. |

## 2.7 Compliance posture (Nidhi Rules, 2014)

The system should make the statutory position visible continuously rather than
discovered annually:

- **Members only.** Deposits and loans are restricted to members. The schema
  enforces membership as a precondition — no account without a member record.
- **Deposit-to-NOF ratio.** Track Net Owned Funds and total deposits; surface
  the ratio on the dashboard with a warning threshold.
- **Loan ceilings by deposit size.** Encode the slab limits as product rules so
  an over-limit sanction is blocked at entry, not caught later.
- **Interest rate ceiling on loans** relative to the highest deposit rate
  offered — validate at product configuration time.
- **NDH-1 / NDH-2 / NDH-3 and annual filings** — build the underlying figures
  as standing reports so filing is an export, not a reconstruction exercise.
- **Retention.** Immutable ledger plus audit log satisfies record-keeping
  requirements far better than dated spreadsheet copies.

> Treat this section as an engineering checklist, not legal advice. Have the
> specific thresholds confirmed by your company secretary or auditor before
> they are hard-coded, and keep them in configuration so they can be updated
> when the Rules are amended.

## 2.8 Security essentials

- Aadhaar and PAN encrypted at rest; masked in all list views; full value
  visible only to Manager+ and every reveal written to the audit log.
- Row-Level Security in the database, not just checks in application code —
  so a bug in a query cannot leak another officer's book.
- The `Whatsapp Messaging API details.txt` credentials currently sitting in
  Drive move to a secret manager and get rotated as part of go-live.
- Daily automated encrypted backups with a **restore drill actually performed**
  before go-live. An untested backup is a hope, not a backup.
- Member photos move from `Photo URL` in Drive to private object storage with
  signed, expiring URLs.

---

*Next: [3. Data Model](03-data-model.md)*
