-- Simple cleanup script - execute these statements one by one
-- Drop organization_branches table and related objects

-- Step 1: Drop RLS policies
DROP POLICY IF EXISTS "Super admin full access" ON public.organization_branches;
DROP POLICY IF EXISTS "Organization admin access" ON public.organization_branches;  
DROP POLICY IF EXISTS "Agent read access" ON public.organization_branches;

-- Step 2: Drop triggers
DROP TRIGGER IF EXISTS update_organization_branches_updated_at ON public.organization_branches;

-- Step 3: Drop indexes
DROP INDEX IF EXISTS public.idx_organization_branches_org_id;
DROP INDEX IF EXISTS public.idx_organization_branches_country;
DROP INDEX IF EXISTS public.idx_organization_branches_state;
DROP INDEX IF EXISTS public.idx_organization_branches_created_at;

-- Step 4: Drop the table
DROP TABLE IF EXISTS public.organization_branches CASCADE;
