# 6. Open Questions

Ordered by how much they change the design. Three questions from the first
draft have since been answered by direct inspection of the files — those are
recorded at the bottom so the reasoning stays visible.

## Blocking — these change the schema or the plan

**1. Retrieve the Apps Script.** *(Highest priority — this is a task, not a
question.)* The `Data_fV` README states that an Apps Script performs your loan
OD calculation, deposit accrued-interest calculation and staff performance
aggregation. That script is the authoritative version of the business rules
and is invisible to every export. Open Extensions → Apps Script in one of the
workspaces, and let me have the code. Almost everything in questions 4 and 5
below may already be answered inside it.

**2. How many members do you actually have?** The master's numbered rows
suggested ~208, but the GS workspace alone carries 604 named customers across
900 rows, and the abstract references member numbers up to 1843. What is the
true active membership, and what do you expect in three years? This decides
whether branch-scoping goes into the schema from day one.

**3. Two customer ID schemes coexist.** The master uses `1-010123-0001`; the
loan register uses `UNB00348` / `UNB01203`; the abstract's scratch tab uses
bare member numbers. Which is authoritative, how do they map to each other,
and should the new system carry one or keep a cross-reference? This has to be
settled before migration, because customer identity is what everything else
hangs from.

**4. The rules behind interest and penalties.** The `Deposit & Loan Plan` rate
card gives the *prices* — RD at 8.25% for one year, 9.25% for two, 6% for
three/five/seven, monthly RD at 6.2% plus a 1% maturity bonus with a six-month
lock, processing fees of 3.50% on daily and group loans and 2% on gold. What
it does not give is the *mechanics*:
   - Deposit interest — accrued from when, compounded how often?
   - What causes `Dep Accrued Reverse` — an accrual to be reversed?
   - Overdue interest — what rate, from which day, capped at what?
   - Who may grant an `OD Discount`, and up to what limit?
   - Exactly when does a loan become NPA?

**5. The credit and loan scoring formulas.** Columns 89–96 implement a real
two-axis scoring model. What are the actual formulas? These should be
reimplemented deliberately rather than reverse-engineered from cell
references.

**6. Gold loans.** The rate card prices gold lending at roughly ₹7,000/gram
with a 2% processing fee, but gold appears nowhere in the master's 110
columns. Is this an active product? If so it needs collateral tracking —
weight, purity, valuation, storage location, release on repayment — which is a
meaningful addition to Phase 3.

**7. Loan regeneration policy.** The `Regenerate logic` tab restructures a
defaulting loan against the member's deposit balance, using a daily rate of
0.002 with arrears and extension interest. Confirm this is the current live
policy, and tell me who is allowed to authorise a restructuring and within
what limits.

## Important — these change scope

**8. Officer sharing.** Customers show `Coll Officer` values like `CS, RS, KM`.
Does that mean joint responsibility, a handover in progress, or a stand-in
arrangement? The schema now supports several officers per account with dated
roles, but the *semantics* need your definition so the roles mean something.

**9. Staff incentives and payroll.** The roster carries per-officer monthly
targets, and the abstract computes commission at 2% of deposits collected,
gated `Payable` / `Not Payable`, with further Bengali notes about collection
thresholds and per-account bonuses. Are officers actually paid on these
figures? If so this is a payroll-grade calculation and must come from the
ledger, not a scratch tab.

**10. Annual file regeneration.** The system is rebuilt every year — there are
2024, 2025 and current generations, 36 spreadsheet IDs in total. Is there
anything the year boundary does that matters *as business logic* (a book
close, an interest crystallisation), or is it purely a technical artefact of
the spreadsheet approach? If the latter, it simply stops.

**11. Devices.** What phones do the officers carry? Android version and RAM
decide how much of the round the offline app can hold locally.

**12. Receipts and passbooks.** Do members currently get a paper receipt or
hold a passbook the officer writes in? Digital-only receipts are a change
members will notice, and paper may require Bluetooth thermal printers — the
one requirement that could push the field app from PWA to native.

**13. Non-member cash.** How are office expenses, bank deposits and
withdrawals, and director transactions recorded? They are not in any sheet I
found. There is also a staff travel and fuel log (`January Travel SDS`) —
should expense tracking be in scope?

**14. Accounting integration.** Is there separate accounting software (Tally
or similar) for statutory books? If so the CBS should export to it rather than
duplicate it, and the format should be agreed early.

## Operational

**15. Who maintains this after go-live?** In-house capacity, or built to be
maintained by an external party? This changes how much operational tooling and
documentation is worth building.

**16. Language default.** Bengali-first with English available, or the
reverse? Given `Cust Name (BN)` is maintained carefully and `Data_fV` lists
English/Bangla/Hindi, I would default the officer-facing app to Bengali.

**17. Statutory thresholds.** Have your auditor or company secretary confirm
in writing the current Nidhi Rules figures — deposit-to-NOF ratio, loan
ceilings by deposit size, and the loan interest cap relative to deposit rates
— so they can be encoded as validated configuration. Note that some products
on the rate card carry effective rates as high as 59.43%; confirm these sit
within the permitted ceiling.

---

## Answered by inspection

**What is `Collection_Abstract`?** *Answered — and it closes off full-history
migration.* Eight tabs, none transaction-level. The three large tabs are
customer × date matrices whose atomic fact is a cell, not a row; daily figures
are net movements (some are negative) and no receipt number, timestamp,
payment mode or collector attribution exists anywhere. The most that could be
recovered is daily per-customer subtotals. See
[§4.2](04-migration.md).

**Which officers are active?** *Answered.* Six: Gobinda Sarkar (GS), Minati
Sarkar (MS), Chumki Sadhukhan (CS), Rajesh Sadhukhan (RS), Champa Rani Das
(CD), Krishna Mondal (KM). Soma Dutta Sikdar (SDS) and Roki Ghosh (RG) are
marked Closed; S2 and S3 are Inactive; `AG` is a system file, not a person.
Eleven further staff are listed as previously closed — so officer turnover is
routine and the system must reassign accounts while keeping history attributed
to whoever actually collected it.

**Is the merge manual?** *Partly answered.* An Apps Script already performs
the accumulation, replacing an earlier IMPORTRANGE approach. So this project
replaces a fragile automation rather than introducing automation — which
raises rather than lowers the bar, because the replacement has to be
demonstrably more correct than what exists.

---

*Back to [README](../README.md)*
