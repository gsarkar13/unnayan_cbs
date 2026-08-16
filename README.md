# Unnayan CBS — Plan to Replace the Spreadsheet System

A plan for converting the Unnayan Nidhi company's Google Sheets operation into
a proper web-based core banking system.

**Status: planning only.** Nothing here has been built. The documents below
are for your review, and [§6](docs/06-open-questions.md) lists what I need
from you before implementation can start.

## The situation

Thirteen live Google Sheets run the business: one `UNNAYAN_CORE_MASTER` with
~208 customers across 110 columns, eleven per-officer collection workspaces,
and a 3 MB `Collection_Abstract`. Officers work in their own file and the data
is merged back to master by hand. Six dated `Copy of UNNAYAN_CORE_MASTER`
files serve as version control.

The domain logic in that master sheet is genuinely good — arrears ageing,
overdue-interest capping with grace days and discounts, NPA classification, a
two-axis credit grade. **None of it is being discarded.** The problem is not
the thinking; it is that a spreadsheet cannot enforce the thinking, cannot
hold more than one loan per member, and cannot tell you who took the cash.

## The core idea

**Stop storing balances. Store every rupee that moves, and derive balances
from that.**

An append-only ledger makes merges impossible-to-need (two officers posting
are two inserts, and inserts never conflict), makes the dated backup copies
unnecessary (no state is ever overwritten), and makes audit a property of the
system rather than a feature bolted onto it.

## The documents

| | |
|---|---|
| [1. Current System](docs/01-current-system.md) | What actually exists today, read from your live Drive folder — the file inventory, all 110 columns, and the five structural problems |
| [2. Target Architecture](docs/02-architecture.md) | System shape, why offline-first is non-negotiable, roles, the day-book cash control, technology choices, compliance posture |
| [3. Data Model](docs/03-data-model.md) | How 110 columns become a normalised, ledger-first schema, and where every derived column goes |
| [4. Migration](docs/04-migration.md) | Getting from sheets to database with zero unexplained differences |
| [5. Roadmap](docs/05-roadmap.md) | Six phases, ~5–7 months, sequenced by risk |
| [6. Open Questions](docs/06-open-questions.md) | **What I need from you to proceed** |
| [`db/schema.sql`](db/schema.sql) | Draft PostgreSQL schema — tables, constraints, append-only triggers, row-level security |

## Biggest changes from today

1. **One customer, many accounts.** `TARAK KUNDU 1` stops being two half-people
   and becomes one member whose total exposure is a single query.
2. **Append-only ledger.** Corrections are reversals, not edits. Nothing is
   ever silently overwritten.
3. **Real logins per officer.** `Coll Officer = "GS"` becomes an accountable
   person, and every receipt records who took the cash, when and where.
4. **Offline-first collection app.** Works with no signal in the field, syncs
   when it can, issues receipts on the spot.
5. **Daily cash reconciliation.** Denomination count against expected
   collection, with variances named rather than absorbed.
6. **Interest, penalties and NPA classified by the system**, from rules held
   as versioned product configuration rather than as formulas.

## Recommended stack

PostgreSQL · Next.js (TypeScript) · offline PWA for field staff · phone-OTP
auth · India-region hosting · existing WhatsApp Business API for notifications.

## What happens next

Read the documents, then answer [§6](docs/06-open-questions.md). The four that
matter most: your growth expectation, what `Collection_Abstract` actually
contains, whether to migrate opening balances or full history, and the written
rules behind the interest, penalty and credit-scoring formulas.
