# 1. The Current System — What Actually Exists Today

*Findings from a direct read of the live Google Drive folder on 2026-08-16.*

## 1.1 The file inventory

Everything lives in one Drive folder. There are three tiers of file, plus a
growing sediment of manual backups.

| File | Size | Role |
|---|---|---|
| `UNNAYAN_CORE_MASTER` | 1.6 MB | The book of record. One row per customer, 110 columns. |
| `Collection_Abstract` | 3.0 MB | The largest file in the system — collection history. |
| `GS_Collection_Workspace` | 350 KB | Field workspace for officer **GS** |
| `RS_Collection_Workspace` | 410 KB | Field workspace for officer **RS** |
| `CS_Collection_Workspace` | 276 KB | Field workspace for officer **CS** |
| `KM_Collection_Workspace` | 270 KB | Field workspace for officer **KM** |
| `SDS_Collection_Workspace` | 254 KB | Field workspace for officer **SDS** |
| `CD_Collection_Workspace` | 229 KB | Field workspace for officer **CD** |
| `MS_Collection_Workspace` | 259 KB | Field workspace for officer **MS** |
| `RG_Collection_Workspace` | 226 KB | Field workspace for officer **RG** |
| `S2_Collection_Workspace` | 261 KB | Field workspace for officer **S2** |
| `S3_Collection_Workspace` | 260 KB | Field workspace for officer **S3** |
| `AG_Daily_Workspace` | 235 KB | Daily workspace, AG Hat area |
| `Whatsapp Messaging API details.txt` | 299 B | WhatsApp notification credentials |

And then these:

| Backup file | Created |
|---|---|
| `Copy of UNNAYAN_CORE_MASTER 060226 backup` | 6 Feb 2026 |
| `Copy of UNNAYAN_CORE_MASTER 0902` | 8 Feb 2026 |
| `Copy of UNNAYAN_CORE_MASTER 1302` | 13 Feb 2026 |
| `Copy of UNNAYAN_CORE_MASTER` | 18 Feb 2026 |
| `Copy of UNNAYAN_CORE_MASTER` | 26 Mar 2026 |
| `Copy of UNNAYAN_CORE_MASTER for DB` | 3 Apr 2026 |

Those six files are the most important thing in the folder, because of what
they mean rather than what they contain. **Manual dated copies are what a
system produces when it has no transaction log and no undo.** You take a
snapshot before a risky merge because if the merge goes wrong there is no
other way back. A core banking system should never need one — every state it
has ever been in should be reconstructible from its ledger.

The last one is named `for DB`. The intent to move to a database is already
there; this plan is the route.

## 1.1a What `Collection_Abstract` actually is

The largest file in the system (3 MB) turns out to hold **eight tabs, and not
one transaction-level row among them.** This matters enormously for migration,
so it is worth being precise.

| Tab | One row = | Coverage |
|---|---|---|
| `Associate Collection` | one source file / associate | daily totals, all of 2026, populated to 15 Aug |
| *(loan register)* | one **loan application** | Sep 2021 – Oct 2022, 116 applications |
| *(M Daily Collection)* | one **customer** | daily `DD`/`EMI` pairs, Jan–May 2026 |
| *(2025 variant)* | one customer | 2025, rendered all zeros |
| *(monthly summary)* | one associate × one month | November 2022 |
| `Data` | one associate | the staff registry — see below |
| *(scratch)* | one member | ad-hoc loan pricing and incentive workings |
| `January Travel SDS` | one day of travel | odometer/fuel log for one officer |

The three big tabs are **matrices, not ledgers**: rows are customers, columns
are days, and the repeating column pair is `DD | EMI` — daily deposit and loan
instalment. The atomic fact is a *cell*, not a row: **(customer × date ×
DD-or-EMI) → amount**. Two payments on the same day are already collapsed into
one figure. Some daily totals are negative (`-47070`, `-61300`), which means
these are **net movements** — collections minus withdrawals — not gross
receipts.

**There is no receipt number, transaction ID, timestamp or collector
attribution on any amount cell anywhere in the file.** That is the single
biggest audit gap in the current system, and it is the thing the new ledger
exists to close.

The tab totals do reconcile cleanly, which is a good sign for data quality:
for 01/01/26, `40 + 11,350 = 11,390`; for 02/01/26, `11,870 + 18,110 =
29,980`. The per-customer matrix rolls up exactly to the house totals.

## 1.1b Two findings that change the picture

**There is already an Apps Script doing the merge.** A note preserved in the
abstract reads, verbatim:

> `Note for S5, previously used, before script: Data_fV!j4:j13 has spreadsheet ID of file2, each file for each staff, to accumulate from all staff file2 data to this sheet`

So the accumulation from staff workspaces was originally formula-driven and
has since been scripted. The merge is partly automated already — which means
the migration is not "introduce automation" but "replace a fragile automation
with a system that cannot lose or double-count."

**The whole file set is rebuilt every year.** The `Data` tab carries three
parallel rosters — current, `2025`, and `2024` — each with its own set of
per-staff spreadsheet IDs, 36 distinct files in total, plus `Master Sheet 24`,
`Master Sheet 25` and `Market Sort 24`. Every year the structure is recreated
and the previous year becomes a frozen archive.

This is the clearest possible argument for the migration. A database has no
year boundary; you query a date range. Annual re-creation is pure overhead
that also fragments history across dozens of files, and it stops entirely
once the ledger exists.

## 1.1c The real staff roster

The `Data` tab is the authoritative roster, and it corrects an assumption
worth stating plainly: **there are six active collection officers, not
eleven.**

| Code | Officer | Status |
|---|---|---|
| GS | Gobinda Sarkar | Active |
| MS | Minati Sarkar | Active |
| CS | Chumki Sadhukhan | Active |
| RS | Rajesh Sadhukhan | Active |
| CD | Champa Rani Das | Active |
| KM | Krishna Mondal | Active |
| SDS | Soma Dutta Sikdar | **Closed** |
| RG | Roki Ghosh | **Closed** |
| S2, S3 | — | **Inactive** |
| AG | `AG_Daily_Workspace` | System, not a person |

This explains the stale workspaces noted below: `SDS`, `RG`, `S2` and `S3`
have not been modified in months because those officers have left or their
slots are dormant. The roster also carries per-officer targets
(`Monthly New Account target`, `New loan disburse amount target`) and a list
of eleven previously-closed staff — so officer turnover is a normal event the
new system must handle gracefully, with accounts reassigned and history
retained under the officer who actually collected it.

## 1.1d Inside a staff workspace — and the Apps Script nobody has read

`GS_Collection_Workspace` has eight tabs, and two of them change this project's
risk profile.

| Tab | What it is |
|---|---|
| `GS_Collection` | The officer's working grid — 900 rows × 750 columns |
| `Remark` | Scratch pad (17 `#VALUE!` errors sitting in it) |
| `Regenerate logic` | A loan-restructuring calculator — see §1.1e |
| `Daily_Ledger_Buffer` | The same grid again; the write-back staging layer for the merge |
| `Deposit & Loan Plan` | The product rate card — see §1.1e |
| `Data_fV` | The cross-file reference index |
| `Followup` / `Copy of Followup` | Promise-to-pay tracking — see §1.1e |

The collection grid is **one row per customer, one column per (date ×
product type)** — 366 days of 2026 × 2, columns S to ACA, headers alternating
`DD` and `EMI`. So a cell is *(customer, date, deposit-or-EMI) → amount*. It
cannot hold a time, a receipt number, who accepted the cash, or a payment mode.
Two payments on the same day collapse into one figure.

### The Apps Script is the real system of record for your business rules

`Data_fV` carries an embedded README written by whoever built this. Verbatim,
in part:

> ```
> README – data_fV (DO NOT MODIFY)
> This sheet is a SYSTEM REFERENCE INDEX.
> • Used by Apps Script for:
>   – Loan OD calculation (cross-year)
>   – Deposit accrued interest calculation
>   – Staff performance aggregation
> • Sheet formulas must NEVER directly depend on data_fV
> • Only Apps Script is allowed to read this sheet
> Any change here can break:
> • OD accuracy  • Accrued interest  • Audit trail  • Historical reconciliation
> ```

This is the most important artefact in the entire system. It means the
overdue-interest and accrued-interest logic — the rules I listed as an open
question — **already exist as code**, in Google Apps Script, and that code is
not visible in any spreadsheet export.

**Retrieving that script is now a prerequisite for Phase 0.** It is the
authoritative statement of your business rules, and reimplementing them from
guesswork when a correct implementation already exists would be both wasteful
and dangerous.

### A reconciliation that is already failing, in your live data

`Data_fV` columns W–Z compare, per customer, the **copied value** against the
**IMPORTRANGE value** of the same 2023 master figures. The grand totals:

| Measure | Copied | IMPORTRANGE | Difference |
|---|---|---|---|
| Loan Recovered | 12,54,171 | 12,53,771 | **₹400** |
| Total Deposit | 23,02,685 | `#VALUE!` | **broken** |

And per-row the drift is much worse — one row reads `6,600` against `27,232`,
another `22,700` against `41,401`, another `0` against `-2,020`. There is also
a `#REF!` in `Data_fV!J19`, the signature of a broken IMPORTRANGE.

This is not a hypothetical risk. Two views of the same historical figures
already disagree, the disagreement is recorded in the file, and nothing
escalates it. It is the strongest possible argument for a single derived
source of truth.

## 1.1e Four things the business does that the master sheet never showed

Reading the workspace surfaced whole features that the 110 columns don't hint
at. All four need to be in scope.

**A product rate card that already exists.** `Deposit & Loan Plan` holds real,
current pricing — recurring deposits at 8.25% (1 yr), 9.25% (2 yr), 6% (3, 5
and 7 yr), a monthly RD at 6.2% plus a 1% maturity bonus with a 6-month lock
and interest only on maturity. On the lending side: group loans over 35 weeks,
daily-loan tables, processing fees of 3.50% on daily and group loans and 2% on
**gold loans at approximately ₹7,000/gram** — and gold lending appears nowhere
in the master's 110 columns. Effective rates on some products run to 59.43%.
This card is the direct input to the `product` table.

**Loan regeneration (restructuring).** The `Regenerate logic` tab is a fully
worked calculator: daily interest rate 0.002, days elapsed, EMIs paid, gap
days as arrears, arrears interest, extension days and extension interest,
adjusted payable, new tenure. It restructures a defaulting loan against the
member's deposit balance. This is a real, recurring business process with a
documented algorithm, and the plan needs a first-class restructuring workflow
rather than treating it as an adjustment.

**Follow-up and promise-to-pay.** The `Followup` tabs mirror the collection
grid but pair `Reason` with `EDate` per day — recording why a member didn't
pay and when they promised to. That is a collections workflow, and it belongs
in the field app so an officer sees the promise on their next visit.

**Route sequencing.** `Visting Order` and `Visting Order 2` (misspelling
verbatim) order each officer's round. The field app must preserve this — it is
how an officer actually walks their day.

## 1.1f Two corrections to earlier assumptions

**The member base is larger than the master suggests.** The GS workspace alone
carries `Sr No` 1–900 with **604 named customers**, and the abstract's scratch
tab references member numbers up to 1843 against a separate `UNB#####` ID
scheme (`UNB00348`, `UNB01203`) that coexists with the `1-010123-0001` scheme.
The ~208 figure from the master's numbered rows is not the true member count,
and the two identifier schemes need reconciling during migration.

**Customers are shared between officers.** `Coll Officer` holds values like
`CS, RS, KM`, `CS, SDS` and `RS, KM` — a single customer collected by several
officers. The data model must therefore support **many officers per account**,
not the single `assigned_officer_id` foreign key sketched in §3. That is
corrected in the data-model document.

The same field also carries at least **40 distinct free-text values** mixing
four different dimensions: officer (`GS`), officer pairs (`SD/CS`), lifecycle
status (`Closed`, `SDS Pause`, `NPA, All`, `SC Close`), and notification
channel (`Mixed GS SMS/CS`, `RS SMS`). `Data_fV` maintains an informal
hand-kept list of them, which is the best available starting point for
splitting that one field into the three or four real dimensions it is doing
the work of.

## 1.2 The master sheet's 110 columns

The `Master` tab carries **~208 customers** across **110 columns**. Grouped by
what they describe:

**Identity and KYC (columns 1–19)**
`Sr No`, `Cust ID`, `Cust Name`, `Cust Name (BN)`, `Group / Area`,
`Onboard Dt`, `Mobile No 1`, `Notify Via`, `Last Notification Dt`, `Aadhaar`,
`PAN`, `EID`, `Other Doc Type`, `Other Doc ID`, `Address`, `Photo URL`,
`Introducer`, `Place`, `Coll Officer`

**Recurring / daily deposit (columns 20–42)**
`Dep Amt`, `Dep Open Dt`, `Dep Freq`, `Dep Weekday`, `Dep Tenure`,
`Dep Maturity Dt`, `P Dep Close Dt`, `Dep Ac No`, `Dep Total Received`,
`Dep Accrued Total`, `Dep Accrued Int`, `Dep Accrued Reverse`, `Dep Lien`,
`Dep Free Bal`, `Total Dep Bal`, `Dep Adj Amt`, `Dep Int Paid`,
`Dep Total Inst`, `Dep Inst Till Dt`, `Dep Inst Rem`, `Dep Inst Paid`,
`Dep Inst Due`, `Dep Due Amt`

**Fixed deposit (columns 43–50)**
`FD Amt`, `FD Ac No`, `Tenure (M)`, `Int`, `FD Open Dt`, `FD Maturity Dt`,
`Maturity Amt`, `FD Close Dt`

**Loan (columns 51–88)**
`Loan Amt`, `EMI Amt`, `Loan Tenure`, `Loan Freq`, `Loan Weekday`,
`Loan Officer`, `Loan Open Dt`, `Loan Inactivity Days`, `Loan First EMI Dt`,
`Loan Maturity Dt`, `Loan Days`, `Loan Last Pay Dt`, `Loan Arrear Days`,
`Loan Status`, `Effective From Dt`, `P loan Close Dt`, `Loan Ac No`,
`Loan Gross Exposure`, `Loan Recovered`, `Loan Adj Amt`,
`Loan Total Recovered`, `Gross Loan OS`, `Gross OS`, `Loan Total EMI`,
`Loan EMI Elapsed`, `Loan EMI Rem Time`, `Loan EMI Paid`,
`Loan EMI Total Rem`, `Loan EMI Due`, `Loan EMI Amt Due`, `Current OD`,
`OD Cap`, `OD Discount`, `Grace Days`, `OD`, `Loan Net Exposure`,
`Net Loan OS`, `Net OS`

**Credit scoring (columns 89–96)**
`Credit Score`, `Credit Grade`, `Credit Consistency %`, `Credit OD Ratio`,
`Loan Score`, `Loan Grade`, `Loan Consistency %`, `Loan OD Ratio`

**Operational tail (columns 97–110)**
`User Email`, `UNB Ref`, `Net P&L`, `D Days`, `Prev Deposit Total till 25`,
`Prev Loan Recovered till 25`, six blank columns, `DD Due Amt (No Limit)`,
`Loan Due Amt (No Limit)`

This is a genuinely sophisticated model. Somebody thought hard about arrears
ageing, overdue-interest capping with discount and grace days, NPA
classification, and a two-axis credit grade. **None of that domain logic is
being thrown away — this plan preserves all of it and moves it somewhere it
can be enforced instead of merely calculated.**

## 1.3 The five structural problems

Not "spreadsheets are unprofessional." These are specific, and each one is
already costing money or risk today.

### Problem 1 — One row per customer cannot hold one customer's real life

A row has exactly one `Loan Amt`, one `Loan Ac No`, one `Dep Ac No`, one
`FD Ac No`. So the sheet can represent a customer with one loan. It cannot
represent:

- a customer with a second loan while the first is still running
- a customer who closed a daily deposit in 2023 and opened a new one in 2025
- a customer with two FDs of different tenures
- a member who leaves and rejoins

The workarounds are visible in the live data. There is a customer named
`TARAK KUNDU 1` — the trailing `1` is a human being cut in half so a second
account could get its own row. `Prev Deposit Total till 25` and
`Prev Loan Recovered till 25` are columns that exist purely to carry forward
history the row structure cannot otherwise hold.

Every one of these workarounds is a place where a customer's true total
exposure is invisible. For a lender, that is the single most expensive kind of
blindness.

### Problem 2 — Balances are formulas, not facts

`Total Dep Bal`, `Gross Loan OS`, `Loan Total Recovered`, `Current OD` are all
*computed* cells. There is no underlying list of individual payments that they
are computed **from** and that can be independently re-added.

The consequence: if a figure is wrong, you cannot find out why. There is no
"show me the 47 payments that make up this ₹53,373" because the 47 payments
were never stored as 47 things. A wrong number can only be fixed by
overwriting it with a different number — which is exactly the operation that
leaves no trace.

This is also why the dated backup copies exist.

### Problem 3 — Ten workspaces means ten forks and a manual merge

Each officer works in their own file. That is a fork of the data. Bringing it
back to master is a manual merge, and manual merges have three failure modes
that all silently produce wrong balances:

- **Lost update** — two officers' work merged in sequence, second overwrites first
- **Double-post** — a merge run twice, a collection counted twice
- **Drift** — a workspace that quietly stops matching master and nobody notices for weeks

Notice the modification timestamps: on 16 Aug 2026, six workspaces were
touched between 19:31 and 19:42 while master was last touched at 18:39. At
that moment master was **stale against six different files simultaneously**.
That is the normal operating state of this system, not an anomaly. And the
`RG`, `MS`, `S2`, `S3` workspaces were last modified in May–June 2026 — either
those officers are inactive, or their work has not reached master in months.

### Problem 4 — No identity, so no accountability

There is a `User Email` column. That is not authentication. Anyone with the
Drive link edits as themselves, and Sheets version history tells you a cell
changed but not that *a collection of ₹250 from customer 1-110622-0003 was
accepted by officer GS at 10:47 on the doorstep*.

For a Nidhi company handling public money from members, the audit question is
not "what does the balance say" but "who accepted this cash, when, and what
did they hand the member as proof". The current system cannot answer it.

### Problem 5 — Field data quality has no gate

The live data shows the `Coll Officer` field carrying values like `RS, NPA`,
`GS.`, `CD, CS`, `MS Close`, `KG Close`, `GS.` — status flags, trailing
periods, and multiple officers crammed into a field meant to hold one officer.
Because nothing validates on entry, meaning drifts into free text, and every
report built on that column has to guess.

## 1.4 What is genuinely good and must be carried forward

- **The customer ID scheme.** `1-010123-0001` encodes type, onboarding date
  and sequence. It is meaningful, sortable and already known to staff. Keep it.
- **The account number scheme.** `201010123-0001` for deposits,
  `501221222-0003` for loans — a product prefix plus date plus customer
  sequence. Keep it.
- **Bengali names.** `Cust Name (BN)` holding `রুমা মোদক` alongside the Latin
  name is correct and respectful of the member base. The web app must be
  bilingual, not English-only with a Bengali column.
- **The arrears and overdue model.** `Loan Arrear Days`, `Current OD`,
  `OD Cap`, `OD Discount`, `Grace Days` is a real collections policy. Encode
  it as product configuration.
- **The credit grading.** Two independent scores with consistency percentages
  is more than most small lenders do.
- **WhatsApp notification.** Already live. Becomes an event subscriber.

---

*Next: [2. Target Architecture](02-architecture.md)*
