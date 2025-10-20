-- Fix missing columns in organizations table
-- Date: October 2, 2025
-- Purpose: Add missing created_by and updated_by columns

-- Check current table structure first
SELECT 'Current organizations table columns:' AS info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'organizations' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Add missing columns if they don't exist
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_organizations_created_by ON public.organizations(created_by);
CREATE INDEX IF NOT EXISTS idx_organizations_updated_by ON public.organizations(updated_by);

-- Verify the columns were added
SELECT 'Updated organizations table columns:' AS info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'organizations' AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Missing columns added successfully!' AS status;
