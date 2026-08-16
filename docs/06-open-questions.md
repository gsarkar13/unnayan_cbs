# 6. Open Questions

These need your answers before Phase 1 starts. They are ordered by how much
they change the design.

## Blocking — these change the schema or the plan

**1. Scale and growth.** The master sheet holds ~208 customers. Is that the
whole book, or one branch of a larger operation? Where do you expect to be in
three years? At 200 members almost any design works; at 5,000 with multiple
branches, branch-scoping has to be in the schema from day one rather than
retrofitted.

**2. Multiple concurrent accounts.** Confirm the interpretation: names like
`TARAK KUNDU 1` indicate one person who needed a second row. Should the new
system allow a member to hold several active loans at once, or is one active
loan per member a policy you want enforced? The schema supports many; the
question is what the *rules* should be.

**3. Migration depth.** Opening balances at a cut-off (fast, low risk), or
full transaction history reconstructed from `Collection_Abstract` (complete,
slower, riskier)? See [§4.2](04-migration.md). My recommendation is opening
balances now, back-load history later.

**4. What is `Collection_Abstract`?** It is your largest file at 3 MB. If it
holds clean transaction-level history, it is the key to full history and to
validating the migration. If it is a derived summary, its role is much
smaller. This is the single most valuable thing to clarify.

**5. Interest and penalty rules, written down.** The sheet computes
`Dep Accrued Int`, `Current OD`, `OD Cap`, `OD Discount`, `Grace Days` — but
the *rules* live in formulas and in your head. Before they can be encoded I
need them stated plainly:
   - Deposit interest: what rate, compounded how often, accrued from when?
   - `Dep Accrued Reverse` — what causes an accrual to be reversed?
   - Overdue interest: what rate, from which day, capped at what?
   - When is a discount granted, by whom, and up to what limit?
   - Exactly when does a loan become NPA?

**6. The credit and loan scoring formulas.** Columns 89–96 are a real scoring
model. What are the actual formulas behind `Credit Score`, `Credit Grade`,
`Credit Consistency %` and `Credit OD Ratio`? These should be reimplemented
deliberately, not reverse-engineered from cell references.

## Important — these change scope

**7. Officer roster.** Eleven officer codes appear: GS, CS, RS, MS, KM, CD,
RG, SDS, S2, S3, AG. Which are active people today? `RG`, `MS`, `S2` and `S3`
workspaces have not been modified since May–June 2026 — are those officers
inactive, or is their work simply not reaching master? Also: what do `S2`,
`S3` and `SDS` stand for?

**8. Devices.** What phones do the officers actually carry? Android version
and RAM decide how much the offline PWA can hold locally. If anyone is on a
very low-end device, the round pre-load needs to be leaner.

**9. Receipts.** Do members currently get a paper receipt at the doorstep? If
yes, moving to a digital-only receipt is a change members will notice, and may
need thermal Bluetooth printers — which is the one requirement that could push
the field app from PWA to native.

**10. Passbooks.** Do members hold physical passbooks that officers write in?
If so, the app needs a passbook-print or update flow, and members will expect
it to continue.

**11. Non-member cash.** How are office expenses, bank deposits and
withdrawals, and director transactions recorded today? They are not in the
master sheet. A full cash position needs them, which is why the plan includes
a journal-voucher table.

**12. Accounting integration.** Is there separate accounting software (Tally
or similar) for statutory books? If so, the CBS should export to it rather
than duplicate it, and we should agree the export format early.

## Operational

**13. Who runs this after go-live?** Is there in-house technical capacity, or
should the system be built to be maintained by an external party? This changes
how much operational tooling and documentation is worth building.

**14. Language.** Should the field app default to Bengali with English
available, or the reverse? Given `Cust Name (BN)` is maintained carefully, I
would default the officer-facing app to Bengali.

**15. Statutory thresholds.** Have your auditor or company secretary confirm
the current Nidhi Rules figures — deposit-to-NOF ratio, loan ceilings by
deposit size, the loan interest rate cap relative to deposit rates — in
writing, so they can be encoded as validated configuration.

---

*Back to [README](../README.md)*
