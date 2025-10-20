-- Quick Fix: Add missing email column to organizations table
-- Date: October 2, 2025
-- Purpose: Add the email column that was missing

-- Check current structure
SELECT 'Current organizations table columns:' AS info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'organizations' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Add missing email column
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- If partner_email exists, migrate data to email column
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
    RAISE NOTICE 'partner_email column does not exist, no migration needed';
  END IF;
END
$$;

-- Verify the email column was added
SELECT 'Updated organizations table columns:' AS info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'organizations' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Email column added successfully' AS status;
