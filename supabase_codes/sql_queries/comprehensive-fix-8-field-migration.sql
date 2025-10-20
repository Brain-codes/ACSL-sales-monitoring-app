-- Comprehensive fix for 8-field migration database issues
-- Date: October 2, 2025
-- Purpose: Fix all column and table issues after 8-field simplification

-- ==================================================
-- STEP 1: Add missing created_by and updated_by columns
-- ==================================================

SELECT 'STEP 1: Adding missing columns to organizations table...' AS status;

-- Add missing columns if they don't exist
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_organizations_created_by ON public.organizations(created_by);
CREATE INDEX IF NOT EXISTS idx_organizations_updated_by ON public.organizations(updated_by);

-- ==================================================
-- STEP 2: Ensure all required 8-field columns exist
-- ==================================================

SELECT 'STEP 2: Ensuring all 8-field columns exist...' AS status;

-- Add the 8 main columns if they don't exist
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS partner_name VARCHAR(100);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS branch VARCHAR(100);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS state VARCHAR(100);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS contact_person VARCHAR(100);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(20);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS alternative_phone VARCHAR(20);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS email VARCHAR(255);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS address TEXT;

-- ==================================================
-- STEP 3: Remove organization_branches table if it exists
-- ==================================================

SELECT 'STEP 3: Removing organization_branches table...' AS status;

-- Drop the organization_branches table since it's no longer needed
DROP TABLE IF EXISTS public.organization_branches CASCADE;

-- ==================================================
-- STEP 4: Migrate data from old columns to new columns
-- ==================================================

SELECT 'STEP 4: Migrating data from old columns...' AS status;

-- Migrate name to partner_name if partner_name is null (only if name column exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'organizations' 
             AND column_name = 'name' 
             AND table_schema = 'public') THEN
    UPDATE public.organizations 
    SET partner_name = COALESCE(name, 'Unknown Partner')
    WHERE partner_name IS NULL OR partner_name = '';
    RAISE NOTICE 'Migrated data from name to partner_name column';
  ELSE
    -- Set default values for partner_name if no name column exists
    UPDATE public.organizations 
    SET partner_name = 'Unknown Partner'
    WHERE partner_name IS NULL OR partner_name = '';
    RAISE NOTICE 'Set default values for partner_name (no name column found)';
  END IF;
END
$$;

-- Migrate partner_email to email if email is null
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'organizations' 
             AND column_name = 'partner_email' 
             AND table_schema = 'public') THEN
    UPDATE public.organizations 
    SET email = partner_email
    WHERE (email IS NULL OR email = '') AND partner_email IS NOT NULL AND partner_email != '';
    RAISE NOTICE 'Migrated data from partner_email to email column';
  ELSE
    RAISE NOTICE 'partner_email column does not exist, skipping migration';
  END IF;
END
$$;

-- Set default values for required fields if they're empty
UPDATE public.organizations 
SET branch = 'Main Branch'
WHERE branch IS NULL OR branch = '';

UPDATE public.organizations 
SET state = 'Unknown State'
WHERE state IS NULL OR state = '';

-- ==================================================
-- STEP 5: Drop old columns that are no longer needed
-- ==================================================

SELECT 'STEP 5: Dropping old columns...' AS status;

-- Drop old columns that are not part of the 8-field structure
ALTER TABLE public.organizations DROP COLUMN IF EXISTS name CASCADE;
ALTER TABLE public.organizations DROP COLUMN IF EXISTS partner_email CASCADE;
ALTER TABLE public.organizations DROP COLUMN IF EXISTS organization_name CASCADE;
ALTER TABLE public.organizations DROP COLUMN IF EXISTS city CASCADE;
ALTER TABLE public.organizations DROP COLUMN IF EXISTS country CASCADE;
ALTER TABLE public.organizations DROP COLUMN IF EXISTS description CASCADE;
ALTER TABLE public.organizations DROP COLUMN IF EXISTS status CASCADE;

-- ==================================================
-- STEP 6: Set proper constraints
-- ==================================================

SELECT 'STEP 6: Setting proper constraints...' AS status;

-- Make required fields NOT NULL
ALTER TABLE public.organizations 
ALTER COLUMN partner_name SET NOT NULL;

ALTER TABLE public.organizations 
ALTER COLUMN branch SET NOT NULL;

ALTER TABLE public.organizations 
ALTER COLUMN state SET NOT NULL;

-- ==================================================
-- STEP 7: Add performance indexes
-- ==================================================

SELECT 'STEP 7: Adding performance indexes...' AS status;

CREATE INDEX IF NOT EXISTS idx_organizations_partner_name ON public.organizations(partner_name);
CREATE INDEX IF NOT EXISTS idx_organizations_branch ON public.organizations(branch);  
CREATE INDEX IF NOT EXISTS idx_organizations_state ON public.organizations(state);
CREATE INDEX IF NOT EXISTS idx_organizations_email ON public.organizations(email);

-- ==================================================
-- VERIFICATION
-- ==================================================

SELECT 'VERIFICATION: Current organizations table structure:' AS info;
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'organizations' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Show sample data
SELECT 'VERIFICATION: Sample data from organizations table:' AS info;
SELECT 
    id,
    partner_name,
    branch,
    state,
    contact_person,
    contact_phone,
    alternative_phone,
    email,
    address,
    created_by,
    updated_by,
    created_at,
    updated_at
FROM public.organizations 
LIMIT 3;

-- Check for any remaining issues
SELECT 'VERIFICATION: Checking for rows with NULL required fields:' AS info;
SELECT 
    COUNT(*) as total_rows,
    COUNT(partner_name) as partner_name_count,
    COUNT(branch) as branch_count,
    COUNT(state) as state_count
FROM public.organizations;

SELECT 'Database migration completed successfully!' AS status;
