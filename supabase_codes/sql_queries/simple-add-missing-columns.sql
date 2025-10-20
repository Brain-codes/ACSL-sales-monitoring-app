-- Simple fix for missing columns only
-- Date: October 2, 2025
-- Purpose: Add only the missing columns that are causing API errors

-- Check current table structure first
SELECT 'Current organizations table columns:' AS info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'organizations' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Add missing created_by and updated_by columns
SELECT 'Adding missing created_by and updated_by columns...' AS status;

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id);

-- Add missing columns from 8-field structure if they don't exist
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

-- Set default values for required fields that are empty (without referencing non-existent columns)
UPDATE public.organizations 
SET partner_name = 'Default Partner'
WHERE partner_name IS NULL OR partner_name = '';

UPDATE public.organizations 
SET branch = 'Main Branch'
WHERE branch IS NULL OR branch = '';

UPDATE public.organizations 
SET state = 'Default State'
WHERE state IS NULL OR state = '';

-- Make required fields NOT NULL
ALTER TABLE public.organizations 
ALTER COLUMN partner_name SET NOT NULL;

ALTER TABLE public.organizations 
ALTER COLUMN branch SET NOT NULL;

ALTER TABLE public.organizations 
ALTER COLUMN state SET NOT NULL;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_organizations_created_by ON public.organizations(created_by);
CREATE INDEX IF NOT EXISTS idx_organizations_updated_by ON public.organizations(updated_by);
CREATE INDEX IF NOT EXISTS idx_organizations_partner_name ON public.organizations(partner_name);
CREATE INDEX IF NOT EXISTS idx_organizations_branch ON public.organizations(branch);  
CREATE INDEX IF NOT EXISTS idx_organizations_state ON public.organizations(state);

-- Verify the fix
SELECT 'Updated organizations table columns:' AS info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'organizations' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Simple column fix completed successfully!' AS status;
