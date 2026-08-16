-- Unnayan CBS — proposed core schema (draft for review, not yet applied)
--
-- Design rules:
--   * money is NUMERIC(14,2), never float
--   * ledger_entry is append-only; balances are derived, never typed
--   * every amount is positive; `direction` carries the sign
--   * corrections are reversal entries, never UPDATEs

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────── reference ───────────────────────────────

CREATE TYPE account_kind   AS ENUM ('recurring_deposit', 'fixed_deposit', 'loan');
CREATE TYPE account_status AS ENUM ('active', 'matured', 'closed', 'npa', 'written_off');
CREATE TYPE frequency      AS ENUM ('daily', 'weekly', 'fortnightly', 'monthly');
CREATE TYPE direction      AS ENUM ('credit', 'debit');
CREATE TYPE staff_role     AS ENUM ('officer', 'supervisor', 'manager', 'admin', 'auditor');

CREATE TYPE entry_type AS ENUM (
  'opening_balance', 'deposit_instalment', 'deposit_withdrawal',
  'loan_disbursal', 'loan_emi', 'interest_accrual', 'interest_payout',
  'penalty', 'penalty_waiver', 'maturity_payout', 'adjustment', 'reversal'
);

CREATE TABLE place (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name_en     text NOT NULL,
  name_bn     text,
  group_area  text,
  UNIQUE (name_en)
);

CREATE TABLE app_user (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  officer_code  text UNIQUE,              -- 'GS', 'CS', 'RS', 'KM', 'SDS', ...
  full_name     text NOT NULL,
  mobile        text NOT NULL UNIQUE,
  role          staff_role NOT NULL,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- Products are versioned by date so existing accounts keep their opening terms.
CREATE TABLE product (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code             text NOT NULL,
  name_en          text NOT NULL,
  name_bn          text,
  kind             account_kind NOT NULL,
  interest_rate    numeric(6,3) NOT NULL,
  default_freq     frequency,
  default_tenure   int,
  tenure_unit      text CHECK (tenure_unit IN ('days','months','years')),
  grace_days       int  NOT NULL DEFAULT 0,
  od_rate          numeric(6,3) NOT NULL DEFAULT 0,   -- overdue/penal rate
  od_cap_pct       numeric(6,3),                      -- 'OD Cap'
  min_amount       numeric(14,2),
  max_amount       numeric(14,2),
  npa_arrear_days  int NOT NULL DEFAULT 90,
  effective_from   date NOT NULL,
  effective_to     date,
  UNIQUE (code, effective_from),
  CHECK (effective_to IS NULL OR effective_to > effective_from)
);

-- ─────────────────────────────── customers ───────────────────────────────

CREATE TABLE customer (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_code          text NOT NULL UNIQUE,        -- '1-010123-0001'
  name_en                text NOT NULL,
  name_bn                text,
  place_id               uuid REFERENCES place(id),
  onboard_date           date NOT NULL,
  mobile_primary         text,
  notify_channel         text CHECK (notify_channel IN ('whatsapp','sms','none')),
  aadhaar_enc            bytea,                       -- encrypted at rest
  pan_enc                bytea,
  eid                    text,
  other_doc_type         text,
  other_doc_id           text,
  address                text,
  photo_key              text,                        -- private object storage
  introducer_id          uuid REFERENCES customer(id),
  membership_status      text NOT NULL DEFAULT 'active'
                           CHECK (membership_status IN ('active','dormant','closed')),
  member_since           date,
  share_certificate_no   text,                        -- Nidhi membership
  created_at             timestamptz NOT NULL DEFAULT now(),
  created_by             uuid REFERENCES app_user(id)
);

CREATE INDEX ON customer (place_id);
CREATE INDEX ON customer (name_en);

-- ──────────────────────────────── accounts ───────────────────────────────
-- The table that breaks the one-row-per-customer ceiling.

CREATE TABLE account (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_no              text NOT NULL UNIQUE,       -- '201010123-0001'
  customer_id             uuid NOT NULL REFERENCES customer(id),
  product_id              uuid NOT NULL REFERENCES product(id),
  kind                    account_kind NOT NULL,
  status                  account_status NOT NULL DEFAULT 'active',
  assigned_officer_id     uuid REFERENCES app_user(id),
  opened_date             date NOT NULL,
  first_instalment_date   date,
  maturity_date           date,
  closed_date             date,
  principal_amount        numeric(14,2) NOT NULL CHECK (principal_amount >= 0),
  instalment_amount       numeric(14,2) CHECK (instalment_amount >= 0),
  frequency               frequency,
  collection_weekday      int CHECK (collection_weekday BETWEEN 0 AND 6),
  tenure                  int,
  tenure_unit             text CHECK (tenure_unit IN ('days','months','years')),
  interest_rate_snapshot  numeric(6,3) NOT NULL,      -- rate at opening
  lien_amount             numeric(14,2) NOT NULL DEFAULT 0,
  metadata                jsonb NOT NULL DEFAULT '{}',
  created_at              timestamptz NOT NULL DEFAULT now(),
  CHECK (closed_date IS NULL OR closed_date >= opened_date),
  CHECK (maturity_date IS NULL OR maturity_date >= opened_date)
);

CREATE INDEX ON account (customer_id);
CREATE INDEX ON account (assigned_officer_id, status);
CREATE INDEX ON account (kind, status);

-- ────────────────────────────── the ledger ───────────────────────────────
-- Append-only. This is the book of record.

CREATE TABLE ledger_entry (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id       uuid NOT NULL REFERENCES account(id),
  entry_date       date NOT NULL,
  value_date       date NOT NULL,
  direction        direction NOT NULL,
  amount           numeric(14,2) NOT NULL CHECK (amount > 0),
  entry_type       entry_type NOT NULL,
  receipt_no       text,
  narration        text,
  collected_by     uuid REFERENCES app_user(id),   -- who took the cash
  posted_by        uuid REFERENCES app_user(id),   -- who entered it
  collected_at     timestamptz,                    -- doorstep time (offline ok)
  posted_at        timestamptz NOT NULL DEFAULT now(),
  idempotency_key  text NOT NULL UNIQUE,           -- makes double-post impossible
  reverses_id      uuid REFERENCES ledger_entry(id),
  reversal_reason  text,
  approved_by      uuid REFERENCES app_user(id),   -- required for reversals/waivers
  device_id        text,
  geo_lat          numeric(9,6),
  geo_lng          numeric(9,6),
  CHECK (entry_type <> 'reversal' OR reverses_id IS NOT NULL),
  CHECK (reverses_id IS NULL OR reversal_reason IS NOT NULL)
);

CREATE UNIQUE INDEX ON ledger_entry (receipt_no) WHERE receipt_no IS NOT NULL;
CREATE INDEX ON ledger_entry (account_id, value_date);
CREATE INDEX ON ledger_entry (collected_by, entry_date);
CREATE INDEX ON ledger_entry (entry_date);

-- Append-only enforcement: the ledger can never be rewritten.
CREATE OR REPLACE FUNCTION ledger_is_append_only() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'ledger_entry is append-only; post a reversal instead of %', TG_OP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ledger_no_update BEFORE UPDATE ON ledger_entry
  FOR EACH ROW EXECUTE FUNCTION ledger_is_append_only();
CREATE TRIGGER ledger_no_delete BEFORE DELETE ON ledger_entry
  FOR EACH ROW EXECUTE FUNCTION ledger_is_append_only();

-- A collection can never predate the account it belongs to.
CREATE OR REPLACE FUNCTION ledger_date_sane() RETURNS trigger AS $$
DECLARE opened date;
BEGIN
  SELECT opened_date INTO opened FROM account WHERE id = NEW.account_id;
  IF NEW.value_date < opened THEN
    RAISE EXCEPTION 'value_date % precedes account opening %', NEW.value_date, opened;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ledger_check_date BEFORE INSERT ON ledger_entry
  FOR EACH ROW EXECUTE FUNCTION ledger_date_sane();

-- ─────────────────────── projections (rebuildable) ───────────────────────

CREATE TABLE account_balance (
  account_id             uuid PRIMARY KEY REFERENCES account(id),
  total_credit           numeric(14,2) NOT NULL DEFAULT 0,
  total_debit            numeric(14,2) NOT NULL DEFAULT 0,
  principal_outstanding  numeric(14,2) NOT NULL DEFAULT 0,
  interest_accrued       numeric(14,2) NOT NULL DEFAULT 0,
  penalty_accrued        numeric(14,2) NOT NULL DEFAULT 0,
  instalments_paid       int NOT NULL DEFAULT 0,
  instalments_due        int NOT NULL DEFAULT 0,
  arrear_days            int NOT NULL DEFAULT 0,
  last_payment_date      date,
  as_of                  timestamptz NOT NULL DEFAULT now()
);

-- Truth check: the projection must always agree with the ledger.
CREATE VIEW v_balance_from_ledger AS
SELECT account_id,
       SUM(amount) FILTER (WHERE direction = 'credit') AS total_credit,
       SUM(amount) FILTER (WHERE direction = 'debit')  AS total_debit,
       MAX(value_date) FILTER (
         WHERE entry_type IN ('deposit_instalment','loan_emi')
       ) AS last_payment_date
FROM ledger_entry
GROUP BY account_id;

-- Nightly job compares account_balance against this view and alerts on any drift.

CREATE TABLE customer_score (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id          uuid NOT NULL REFERENCES customer(id),
  computed_on          date NOT NULL,
  credit_score         int,
  credit_grade         text,
  credit_consistency   numeric(6,2),
  credit_od_ratio      numeric(10,4),
  loan_score           int,
  loan_grade           text,
  loan_consistency     numeric(6,2),
  loan_od_ratio        numeric(10,4),
  UNIQUE (customer_id, computed_on)   -- score history, not a mutable cell
);

-- ──────────────────────── cash control (day-book) ────────────────────────

CREATE TABLE day_book (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  officer_id       uuid NOT NULL REFERENCES app_user(id),
  book_date        date NOT NULL,
  expected_amount  numeric(14,2) NOT NULL DEFAULT 0,   -- from ledger
  counted_amount   numeric(14,2),                      -- physical count
  variance         numeric(14,2) GENERATED ALWAYS AS
                     (COALESCE(counted_amount,0) - expected_amount) STORED,
  status           text NOT NULL DEFAULT 'open'
                     CHECK (status IN ('open','submitted','accepted','disputed')),
  submitted_at     timestamptz,
  accepted_by      uuid REFERENCES app_user(id),
  accepted_at      timestamptz,
  notes            text,
  UNIQUE (officer_id, book_date)
);

CREATE TABLE day_book_denomination (
  day_book_id  uuid NOT NULL REFERENCES day_book(id) ON DELETE CASCADE,
  denomination int NOT NULL CHECK (denomination > 0),
  count        int NOT NULL CHECK (count >= 0),
  PRIMARY KEY (day_book_id, denomination)
);

-- Receipt number blocks, allocated to a device so offline receipts stay unique.
CREATE TABLE receipt_block (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  officer_id   uuid NOT NULL REFERENCES app_user(id),
  device_id    text NOT NULL,
  prefix       text NOT NULL,
  range_start  bigint NOT NULL,
  range_end    bigint NOT NULL,
  next_value   bigint NOT NULL,
  allocated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (range_end >= range_start),
  CHECK (next_value BETWEEN range_start AND range_end + 1)
);

-- ──────────────────────────── audit & comms ──────────────────────────────

CREATE TABLE audit_log (
  id          bigserial PRIMARY KEY,
  actor_id    uuid REFERENCES app_user(id),
  actor_role  staff_role,
  action      text NOT NULL,
  table_name  text NOT NULL,
  record_id   text,
  before_json jsonb,
  after_json  jsonb,
  ip_address  inet,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON audit_log (table_name, record_id);
CREATE INDEX ON audit_log (actor_id, occurred_at);

CREATE TABLE notification_log (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id  uuid NOT NULL REFERENCES customer(id),
  channel      text NOT NULL,
  template     text NOT NULL,
  payload      jsonb,
  sent_at      timestamptz NOT NULL DEFAULT now(),
  status       text NOT NULL,
  provider_ref text
);

-- ─────────────────────── row-level security sketch ───────────────────────
-- An officer can only ever see and post against their own assigned accounts.

ALTER TABLE account      ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_entry ENABLE ROW LEVEL SECURITY;

CREATE POLICY officer_sees_own_accounts ON account FOR SELECT
  USING (
    assigned_officer_id = current_setting('app.user_id', true)::uuid
    OR current_setting('app.role', true) IN ('supervisor','manager','admin','auditor')
  );

CREATE POLICY officer_posts_own_accounts ON ledger_entry FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM account a
      WHERE a.id = ledger_entry.account_id
        AND (a.assigned_officer_id = current_setting('app.user_id', true)::uuid
             OR current_setting('app.role', true) IN ('supervisor','manager','admin'))
    )
  );
