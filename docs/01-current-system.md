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
