# 3. Data Model

## 3.1 The reshaping in one picture

```
        TODAY                                  TARGET

  ┌──────────────────────┐            ┌──────────┐
  │ Master row           │            │ customer │ 1 ── n ┌─────────┐
  │ 110 columns          │            └──────────┘         │ account │
  │                      │                                 └────┬────┘
  │ customer  ─┐         │   becomes                            │ 1
  │ deposit    ├ all      │  ═════════>                          │ n
  │ FD         │ crammed  │                              ┌───────▼────────┐
  │ loan       │ into one │                              │ ledger_entry   │
  │ scores    ─┘ row      │                              │ append-only    │
  └──────────────────────┘                               └───────┬────────┘
                                                                 │ derives
   balance = a typed number                            ┌─────────▼────────┐
                                                       │ account_balance  │
                                                       │ (projection)     │
                                                       └──────────────────┘
```

One customer now has **many** accounts. One account has **many** ledger
entries. Balances are the sum of entries, never typed by a human.

## 3.2 Core tables

### `customer` — from master columns 1–18

| Column | Source |
|---|---|
| `id` (uuid) | new |
| `customer_code` | `Cust ID` — keep the existing `1-010123-0001` format |
| `name_en` | `Cust Name` |
| `name_bn` | `Cust Name (BN)` |
| `group_area` | `Group / Area` |
| `place` | `Place` — normalised to a `place` lookup table |
| `onboard_date` | `Onboard Dt` |
| `mobile_primary` | `Mobile No 1` |
| `notify_channel` | `Notify Via` — enum |
| `aadhaar_enc`, `pan_enc` | `Aadhaar`, `PAN` — encrypted at rest |
| `eid`, `other_doc_type`, `other_doc_id` | as-is |
| `address` | `Address` |
| `photo_key` | `Photo URL` → private object storage key |
| `introducer_customer_id` | `Introducer` — FK to `customer` |
| `membership_status` | new — `active` / `dormant` / `closed` |
| `member_since`, `share_certificate_no` | new — Nidhi membership requirement |

Note `Coll Officer` is **not** here. Officer assignment belongs to the account,
not the person — an officer takes over a route, and a customer may have a
deposit collected by one officer and a loan by another. That is exactly what
the live data's `Coll Officer` / `Loan Officer` split already implies.

### `product` — new, and this is where the domain logic goes

Everything currently hard-coded in formulas becomes configuration:

`code`, `kind` (`recurring_deposit` | `fixed_deposit` | `loan`),
`interest_rate`, `compounding`, `default_tenure`, `default_frequency`,
`grace_days`, `od_rate`, `od_cap_pct`, `min_amount`, `max_amount`,
`effective_from`, `effective_to`.

Products are **versioned by date**. When you change the FD rate next year,
existing FDs keep the rate they were opened under. A spreadsheet cannot do
this; it is essential for correctness.

### `account` — the missing table

One row per deposit, FD or loan. This is what breaks the one-row-per-customer
ceiling.

```
id, account_no, customer_id, product_id, kind,
opened_date, closed_date, maturity_date, status,
assigned_officer_id,        -- was `Coll Officer` / `Loan Officer`
principal_amount,           -- Dep Amt / FD Amt / Loan Amt
instalment_amount,          -- EMI Amt
frequency, collection_weekday,
tenure, tenure_unit,
interest_rate_snapshot,     -- rate at opening, not current product rate
lien_amount,                -- Dep Lien
opening_balance,            -- migration carry-forward, see below
metadata jsonb
```

Now `TARAK KUNDU 1` and `TARAK KUNDU 2` become **one customer with two
accounts**, and total exposure per member is a `SUM`, not a guess.

### `ledger_entry` — the book of record

Append-only. No `UPDATE`, no `DELETE`, enforced by trigger and permissions.

```
id, account_id, entry_date, value_date,
direction        -- 'credit' | 'debit'
amount           NUMERIC(14,2) CHECK (amount > 0)
entry_type       -- deposit_instalment | loan_emi | interest_accrual
                 -- | penalty | disbursal | withdrawal | maturity_payout
                 -- | adjustment | reversal | opening_balance
receipt_no       -- unique per branch, from an allocated block
collected_by     -- FK user; who physically took the cash
posted_by        -- FK user; who put it in the system
collected_at     -- doorstep timestamp (may be offline)
posted_at        -- server receipt timestamp
idempotency_key  UNIQUE  -- client-generated; makes double-post impossible
reverses_id      -- FK to the entry this reverses
reversal_reason
device_id, geo_lat, geo_lng   -- optional proof of doorstep collection
```

**Corrections are reversals, never edits.** To fix a ₹250 posted as ₹520 you
post a −₹520 reversal and a +₹250 entry, both linked and both attributed.
The mistake stays visible, which is the point.

### `account_balance` — a projection, not a source

`account_id`, `total_credit`, `total_debit`, `principal_outstanding`,
`interest_accrued`, `penalty_accrued`, `instalments_paid`, `instalments_due`,
`arrear_days`, `last_payment_date`, `as_of`.

Maintained incrementally on insert, and **fully rebuildable from
`ledger_entry` alone**. A nightly job rebuilds and compares; any divergence
raises an alert. That check is the mechanical replacement for the trust you
currently place in a formula.

### `customer_score` — from master columns 89–96

`Credit Score`, `Credit Grade`, `Credit Consistency %`, `Credit OD Ratio`,
`Loan Score`, `Loan Grade`, `Loan Consistency %`, `Loan OD Ratio` — kept, but
computed nightly from ledger history and **stored with the date they were
computed**, so score movement over time becomes visible. Right now a score is
a single mutable cell with no history.

### `day_book` and `day_book_denomination` — new

Per officer per date: `expected_amount`, `counted_amount`, `variance`,
`status` (`open` / `submitted` / `accepted` / `disputed`), `accepted_by`.
Denominations as a child table. This is the cash control from §2.5.

### `audit_log` — new

Every mutation: actor, role, action, table, record, before/after JSON, IP,
timestamp. Append-only. Retained for the full statutory period.

### `account_officer` — corrected: many officers per account

The live data shows `Coll Officer` values like `CS, RS, KM` and `CS, SDS` — a
single customer collected by several officers. A single
`account.assigned_officer_id` cannot represent that, so assignment becomes its
own table:

`account_id`, `officer_id`, `role` (`primary` | `secondary` | `covering`),
`effective_from`, `effective_to`.

Dating the assignment matters as much as allowing several. Officers leave —
the roster lists eleven closed staff — and when they do, **history must stay
attributed to whoever actually collected it** while the *current* assignment
moves on. A dated join table gives you both; a column on the account gives you
neither.

Row-level security then keys off "is there a live `account_officer` row for
me", rather than an equality check on one column.

### `loan_restructure` — the "regeneration" workflow

The `Regenerate logic` tab is a documented algorithm for restructuring a
defaulting loan against the member's deposit balance. It deserves a real
workflow, not an untracked adjustment:

`loan_account_id`, `requested_on`, `regeneration_date`, `old_emi`,
`new_emi`, `old_tenure`, `new_tenure_days`, `gap_days`, `arrears_interest`,
`extension_days`, `extension_interest`, `adjusted_payable`,
`deposit_applied`, `approved_by`, `approved_on`, `status`.

Approval is required, and the resulting change posts as ledger entries — so a
restructuring is visible in the member's history rather than silently
rewriting their schedule.

### `followup` — promise-to-pay

The `Followup` tabs pair a `Reason` with an `EDate` per customer per day. That
is a collections workflow and belongs in the field app, so an officer arrives
already knowing what was promised last time:

`account_id`, `officer_id`, `contact_date`, `reason_code`, `notes`,
`promised_date`, `promised_amount`, `outcome`.

`reason_code` should be a controlled list in Bengali and English — the
free-text version is what produced 40 unmanaged values in `Coll Officer`.

### `visit_route` — the officer's round

`Visting Order` and `Visting Order 2` sequence each officer's day. Preserve
them as `account_officer.visit_order` plus an optional alternate sequence, and
sort the field app's round by it. This is how officers actually walk their
route; losing it would make the app slower than the spreadsheet.

### `staff_target` and `staff_incentive`

The roster carries `Monthly New Account target` and `New loan disburse amount
target` per officer, and the abstract computes commission at 2% of deposits
collected, gated `Payable` / `Not Payable`, alongside Bengali incentive notes
about collection thresholds and per-account bonuses. If officers are paid on
these numbers, the numbers must come from the ledger rather than a scratch
tab — otherwise payroll depends on a spreadsheet nobody reconciles.

### `loan_application` — the origination pipeline

The abstract's loan register already tracks one row per application with
`App. Date`, `Disb. Date`, `Disburse amount`, `Denied amount`,
`Rejected Amount`, `Committment Date`, `Doc Clr Dt`, `Doc clr by` and
`Verif. Date`, keyed by application numbers like `USLAPP00822`. That is a real
origination pipeline with document verification, and it maps directly onto the
Phase 3 sanction workflow. Keep the application-number scheme.

### Supporting tables

`app_user` (staff, roles, officer codes GS/CS/RS/MS/KM/CD/RG/SDS/S2/S3/AG),
`place`, `receipt_block` (allocated ranges for offline receipt numbering),
`notification_log` (replaces `Last Notification Dt`),
`journal_voucher` for non-member cash movements (expenses, bank transfers).

## 3.3 Where the derived columns go

The ~40 computed columns in master do not become table columns. They become
**SQL views**, so they can never disagree with the ledger:

| Master column(s) | Becomes |
|---|---|
| `Dep Total Received`, `Total Dep Bal`, `Dep Free Bal` | `SUM` over `ledger_entry`, less `lien_amount` |
| `Dep Inst Paid` / `Rem` / `Due`, `Dep Due Amt` | schedule view vs. entries |
| `Loan Recovered`, `Gross Loan OS`, `Net Loan OS` | disbursal minus recovery |
| `Loan EMI Elapsed` / `Paid` / `Due`, `Loan EMI Amt Due` | amortisation schedule vs. entries |
| `Loan Arrear Days`, `Loan Status`, NPA flag | ageing view with configurable NPA threshold |
| `Current OD`, `OD`, `OD Cap`, `OD Discount` | penalty engine using product `grace_days`, `od_rate`, `od_cap_pct` |
| `Net P&L`, `D Days`, `Gross OS`, `Net OS` | portfolio views |

`OD Cap` and `OD Discount` stay writable — but as an **explicit, approved,
audited waiver record** against the account, not an untracked cell edit. Who
granted a discount, when, and why becomes answerable.

## 3.4 The columns that disappear

- `Sr No` — row position is not data.
- `Prev Deposit Total till 25`, `Prev Loan Recovered till 25` — become
  `opening_balance` ledger entries dated at migration cut-off. History stops
  being a special column and becomes ordinary ledger data.
- The six blank columns — artefacts.
- `DD Due Amt (No Limit)`, `Loan Due Amt (No Limit)` — report parameters, not
  stored fields.
- `User Email` — replaced by real authenticated identity on every entry.

## 3.5 Invariants the database enforces

Things that are currently a matter of care, and become impossible:

1. `amount > 0` always — direction carries the sign.
2. No `UPDATE` or `DELETE` on `ledger_entry`, enforced by trigger.
3. `idempotency_key` unique — the same receipt can never post twice.
4. `receipt_no` unique per branch, gapless within an allocated block.
5. A loan account cannot exist for a non-member.
6. Collection date cannot precede account opening date.
7. A reversal must reference an existing entry and cannot exceed it.
8. An officer can only insert entries for accounts assigned to them (RLS).
9. Sum of `account_balance` must equal sum of `ledger_entry` — checked nightly.

---

*Next: [4. Migration](04-migration.md)*
