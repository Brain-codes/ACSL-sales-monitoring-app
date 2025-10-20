-- Migration: Simplify organizations table to 8 fields only
-- Date: October 2, 2025
-- Purpose: Clean up organization structure to only include required 8 fields

-- BACKUP: Create backup of current organizations table
CREATE TABLE organizations_backup_20251002 AS 
SELECT * FROM public.organizations;

-- STEP 0: Check current table structure
SELECT 'Current organizations table structure:' AS info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'organizations' AND table_schema = 'public'
ORDER BY ordinal_position;

-- STEP 1: Add new required columns if they don't exist
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS partner_name TEXT;

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS email TEXT;

-- STEP 2: Migrate existing data to new structure
UPDATE public.organizations 
SET partner_name = COALESCE(name, 'Unknown Partner')
WHERE partner_name IS NULL;

-- Migrate partner_email to email column if partner_email exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_name = 'organizations' 
             AND column_name = 'partner_email' 
             AND table_schema = 'public') THEN
    UPDATE public.organizations 
    SET email = partner_email
    WHERE email IS NULL AND partner_email IS NOT NULL;
    RAISE NOTICE 'Migrated data from partner_email to email column';
  ELSE
    RAISE NOTICE 'partner_email column does not exist, skipping migration';
  END IF;
END
$$;

-- STEP 3: Drop unnecessary columns that are not in the 8-field list
-- Keep only: partner_name, branch, state, contact_person, contact_phone, alternative_phone, email, address

DO $$
BEGIN
  RAISE NOTICE 'Dropping unnecessary columns...';
  
  -- Drop organization-specific fields that are no longer needed
  ALTER TABLE public.organizations DROP COLUMN IF EXISTS name CASCADE;
  ALTER TABLE public.organizations DROP COLUMN IF EXISTS partner_email CASCADE;
  ALTER TABLE public.organizations DROP COLUMN IF EXISTS city CASCADE;
  ALTER TABLE public.organizations DROP COLUMN IF EXISTS country CASCADE;
  ALTER TABLE public.organizations DROP COLUMN IF EXISTS description CASCADE;
  ALTER TABLE public.organizations DROP COLUMN IF EXISTS status CASCADE;
  
  RAISE NOTICE 'Unnecessary columns dropped successfully';
END
$$;

-- STEP 4: Ensure required fields are NOT NULL
ALTER TABLE public.organizations 
ALTER COLUMN partner_name SET NOT NULL;

ALTER TABLE public.organizations 
ALTER COLUMN branch SET NOT NULL;

ALTER TABLE public.organizations 
ALTER COLUMN state SET NOT NULL;

-- STEP 5: Update column constraints and lengths
ALTER TABLE public.organizations 
ALTER COLUMN partner_name TYPE VARCHAR(100);

ALTER TABLE public.organizations 
ALTER COLUMN branch TYPE VARCHAR(100);

ALTER TABLE public.organizations 
ALTER COLUMN state TYPE VARCHAR(100);

-- Optional fields with appropriate lengths
ALTER TABLE public.organizations 
ALTER COLUMN contact_person TYPE VARCHAR(100);

ALTER TABLE public.organizations 
ALTER COLUMN contact_phone TYPE VARCHAR(20);

ALTER TABLE public.organizations 
ALTER COLUMN alternative_phone TYPE VARCHAR(20);

ALTER TABLE public.organizations 
ALTER COLUMN email TYPE VARCHAR(255);

ALTER TABLE public.organizations 
ALTER COLUMN address TYPE TEXT;

-- STEP 6: Add helpful indexes for performance
CREATE INDEX IF NOT EXISTS idx_organizations_partner_name ON public.organizations(partner_name);
CREATE INDEX IF NOT EXISTS idx_organizations_branch ON public.organizations(branch);  
CREATE INDEX IF NOT EXISTS idx_organizations_state ON public.organizations(state);

-- STEP 7: Update RLS policies if needed (they should still work with the simplified structure)

-- STEP 8: Verification - Display final schema
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'organizations' AND table_schema = 'public'
ORDER BY ordinal_position;

-- STEP 9: Display sample data to verify migration
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
    created_at
FROM public.organizations 
LIMIT 5;

SELECT 'Migration completed successfully. Organizations table now has simplified 8-field structure.' AS status;
