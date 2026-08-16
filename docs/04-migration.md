# 4. Migration

The riskiest part of the whole project. A migration that silently changes one
member's balance destroys trust that took years to build, and in a
doorstep-collection business trust *is* the business.

## 4.1 The governing principle

**Migrate to a reconciled zero.** Not "load the data and start using it" —
load the data, then prove every single member's balance in the new system
equals their balance in the sheet, member by member, before anyone relies on
it. Zero unexplained differences. Not "close enough."

## 4.2 Opening balances vs. full history

You have two options and should take the first.

**Option A — opening balance at a cut-off date (recommended).**
Pick a cut-off. For each account, write one `opening_balance` ledger entry
carrying the balance as at that date. All collections from the cut-off forward
are real, individually-recorded entries.

- Fast, low-risk, and reconciliation is a single number per account.
- Cost: you cannot drill into a payment made *before* the cut-off. The
  spreadsheets remain the archive for that, frozen read-only.

**Option B — reconstruct full transaction history** from `Collection_Abstract`
and the workspace files.

**This option is now closed, and it is important to be clear about why.**
Direct inspection of `Collection_Abstract` and of `GS_Collection_Workspace`
found **no transaction-level rows anywhere in the system**. Both are matrices:
rows are customers, columns are days, and each cell holds one amount for
*(customer, date, deposit-or-EMI)*. Two payments on the same day are already
collapsed into a single figure. No receipt number, timestamp, payment mode or
collector attribution exists on any amount cell in any file.

So the most that could ever be recovered is **daily per-customer subtotals** —
not transactions. The actor, the time and the mode were never recorded, and no
amount of migration effort can retrieve information that was never captured.

**Recommendation: Option A, and treat the daily subtotals as an archive.**
Migrate opening balances at the cut-off. Separately, load the Jan–May 2026
per-customer daily matrix and the 2026 house totals into a read-only
`historical_daily_collection` table — useful for trend reporting and for
validating the migration, but explicitly *not* part of the ledger, because
they are not transactions and should never be mistaken for them.

## 4.2a Prerequisite: retrieve the Apps Script

Before any of this, extract and read the Google Apps Script attached to the
workspaces. Its own README states it performs **loan OD calculation
(cross-year)**, **deposit accrued interest calculation** and **staff
performance aggregation**.

That script is the authoritative statement of your business rules. It is not
visible in any spreadsheet export, so it must be pulled from the Apps Script
editor (Extensions → Apps Script) and committed to this repository. Until it
has been read:

- the interest and penalty rules cannot be correctly reimplemented;
- the migration cannot be validated, because the figures it produced are the
  figures being migrated;
- nobody knows what else it does.

This is the highest-value single task in Phase 0.

## 4.2b A reconciliation that is already failing

`Data_fV` in the staff workspace compares copied values against IMPORTRANGE
values of the same 2023 master figures, and they disagree: loan recovered
totals of 12,54,171 against 12,53,771 — **₹400 apart** — with the deposit
total returning `#VALUE!`, individual rows differing by tens of thousands, and
a `#REF!` sitting in `Data_fV!J19`.

Investigate this **before** migrating, not after. Either the copied figures or
the imported ones are wrong, and the same divergence may be embedded in the
opening balances you are about to carry forward. Resolving it is part of
earning the zero.

## 4.3 The pipeline

```
Sheets ──► extract ──► profile ──► clean ──► map ──► load ──► reconcile
                          │          │                          │
                          ▼          ▼                          ▼
                    data-quality  decision                 must be
                      report        log                   ZERO diffs
```

Every step is a **re-runnable script in this repository**, never a hand edit.
The migration must be repeatable, because you will run it many times against a
staging database before the one time it counts.

### Extract
Pull each sheet to CSV, committed as immutable snapshots with a timestamp.

### Profile
Before cleaning anything, produce a data-quality report. From what is already
visible in the live data, expect at minimum:

- **`Coll Officer` contamination** — values like `RS, NPA`, `GS.`, `CD, CS`,
  `MS Close`, `KG Close`. One field holding officer + status + punctuation.
  Needs splitting into `assigned_officer` and `status`, with a human decision
  on each distinct bad value.
- **Split customers** — `TARAK KUNDU 1` and similar suffixed names that are one
  person with two accounts. Needs manual identification; this is the change
  that most improves the data, and the one most likely to be got wrong.
- **Date format consistency** — `dd/mm/yy` throughout; must not be parsed as
  US `mm/dd/yy`. A misparse turns 01/12/25 into January. Assert on it.
- **Number formatting** — Indian-style grouping (`53,373`, `1,05,002`) and
  negative values shown as `-165`, `-4,300`. Parse deliberately; never let a
  locale default decide.
- **Missing mobile numbers** and blank KYC — list them for follow-up rather
  than inventing placeholders.
- **Duplicate `Cust ID` or account numbers** — must be resolved before load.

The report is a deliverable in its own right. Some of what it finds is worth
fixing in the spreadsheet *before* migrating.

### Clean and map
Each cleaning decision is recorded in a decision log — value found, value
used, who decided, why. When someone asks in a year why a balance changed at
migration, the answer exists.

### Load
Into a staging database first. Load order: places → products → users →
customers → accounts → opening-balance entries.

### Reconcile — the gate
Automated comparison, per account and in total:

| Check | Tolerance |
|---|---|
| Deposit balance per account, sheet vs. system | ₹0.00 |
| Loan outstanding per account | ₹0.00 |
| Total deposit book | ₹0.00 |
| Total loan book | ₹0.00 |
| Customer count | exact |
| Active account count by product | exact |
| Arrear days per loan | ±1 day (rounding conventions may differ) |

Any non-zero difference is investigated individually until it is either fixed
or consciously signed off with a written reason. **This report is signed by
you before go-live.** It is the moment the new system becomes the book of
record.

## 4.4 Parallel run

Run both systems for **one full collection cycle** — a month, since the daily
and weekly frequencies both need to complete a cycle.

- Officers record in the app; the spreadsheet continues as it does today.
- Compare daily totals each evening; investigate every difference same-day.
- Differences should trend to zero within the first week. If they do not, the
  cause is usually a genuine bug worth finding before cutover.

Parallel running is double work for a month. It is the cheapest insurance
available and should not be skipped.

## 4.5 Cutover

1. Announce a freeze time; last collections posted to sheets.
2. Final delta migration for anything moved after the main load.
3. Final reconciliation run — must be zero.
4. **Set every spreadsheet to view-only.** Not deleted — frozen, kept as
   archive. Read-only is what stops the old habit reasserting itself.
5. Officers' phones sync the new day's round.
6. First week: daily reconciliation, someone available to field questions.

Have a written rollback plan for the first two weeks: because the sheets are
frozen rather than deleted, rolling back means un-freezing them and replaying
the app's ledger entries, which the append-only log makes mechanical.

---

*Next: [5. Roadmap](05-roadmap.md)*
