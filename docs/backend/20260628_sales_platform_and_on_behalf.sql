-- ============================================================================
-- Migration: add platform + "sold on behalf of" attribution to sales
-- Target DB: ACSL sales monitoring (Supabase / Postgres)
-- Run in: Supabase SQL editor (or as a migration in frontend-transactions)
-- Date: 2026-06-28
-- ============================================================================
--
-- WHY
--  1) PLATFORM: every sale must record where it originated ('web' | 'mobile')
--     so reporting can compare channel performance. Existing rows are backfilled
--     to 'web' (all historical sales pre-date the mobile create flow).
--  2) ON-BEHALF ATTRIBUTION: a sale can now be CREATED by one user (e.g. super
--     admin or an acsl_agent_manager) but ATTRIBUTED to the agent it was sold
--     for. `created_by` stays the actual creator (audit trail); the new
--     `sold_on_behalf_of` is the agent the sale belongs to. When a user sells
--     for themselves, `sold_on_behalf_of = created_by`.
--
-- SAFE / IDEMPOTENT: uses IF NOT EXISTS so it can be re-run.
-- ============================================================================

-- 1) Platform / channel of origin -------------------------------------------
ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS platform text NOT NULL DEFAULT 'web';

-- Constrain to known channels.
ALTER TABLE public.sales
  DROP CONSTRAINT IF EXISTS sales_platform_check;
ALTER TABLE public.sales
  ADD CONSTRAINT sales_platform_check
  CHECK (platform IN ('web', 'mobile'));

-- Backfill: everything that exists today came from the web app.
UPDATE public.sales SET platform = 'web' WHERE platform IS NULL;

COMMENT ON COLUMN public.sales.platform IS
  'Origin channel of the sale: web | mobile. Set by the create-sale edge function from the request payload.';

-- 2) Sold-on-behalf-of attribution ------------------------------------------
-- The agent the sale is attributed to (may differ from created_by).
ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS sold_on_behalf_of uuid REFERENCES public.profiles(id);

-- Backfill: historical sales were sold for whoever created them.
UPDATE public.sales
  SET sold_on_behalf_of = created_by
  WHERE sold_on_behalf_of IS NULL;

CREATE INDEX IF NOT EXISTS idx_sales_sold_on_behalf_of
  ON public.sales (sold_on_behalf_of);

COMMENT ON COLUMN public.sales.sold_on_behalf_of IS
  'Agent (profiles.id) the sale is attributed to. Differs from created_by when a super admin or acsl_agent_manager sells on behalf of an agent. Equals created_by for self-sales.';

-- ============================================================================
-- Verify
--   SELECT platform, count(*) FROM public.sales GROUP BY platform;
--   SELECT count(*) FROM public.sales WHERE sold_on_behalf_of IS NULL; -- expect 0
-- ============================================================================
