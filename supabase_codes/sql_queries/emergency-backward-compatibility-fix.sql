-- Emergency fix: Add missing name column temporarily for backward compatibility
-- This will prevent the immediate error while you find and fix the source

-- Add temporary name column that maps to partner_name
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS name VARCHAR(100);

-- Update name column to match partner_name
UPDATE public.organizations 
SET name = partner_name
WHERE name IS NULL;

-- Add temporary partner_email column that maps to email  
ALTER TABLE public.organizations 
ADD COLUMN IF NOT EXISTS partner_email VARCHAR(255);

-- Update partner_email column to match email
UPDATE public.organizations 
SET partner_email = email
WHERE partner_email IS NULL;

-- This is a temporary fix - you should find and update the source code making the REST call
