-- Cleanup: Drop organization_branches table and related objects
-- Simplified version without complex PL/pgSQL blocks
-- Date: October 1, 2025
-- Purpose: Clean up old branch table structure

-- WARNING: This script will permanently delete the organization_branches table and all its data

-- Display status
SELECT 'Starting cleanup process...' AS status;

-- Check if table exists
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables 
                 WHERE table_name = 'organization_branches' AND table_schema = 'public')
    THEN 'organization_branches table found, proceeding with cleanup'
    ELSE 'organization_branches table not found, cleanup not needed'
  END AS table_status;

-- Drop RLS policies
DROP POLICY IF EXISTS "Super admin full access" ON public.organization_branches;
DROP POLICY IF EXISTS "Organization admin access" ON public.organization_branches;  
DROP POLICY IF EXISTS "Agent read access" ON public.organization_branches;

SELECT 'RLS policies dropped' AS status;

-- Drop triggers
DROP TRIGGER IF EXISTS update_organization_branches_updated_at ON public.organization_branches;

SELECT 'Triggers dropped' AS status;

-- Drop indexes
DROP INDEX IF EXISTS public.idx_organization_branches_org_id;
DROP INDEX IF EXISTS public.idx_organization_branches_country;
DROP INDEX IF EXISTS public.idx_organization_branches_state;
DROP INDEX IF EXISTS public.idx_organization_branches_created_at;

SELECT 'Indexes dropped' AS status;

-- Drop the table
DROP TABLE IF EXISTS public.organization_branches CASCADE;

SELECT 'organization_branches table dropped successfully' AS status;

-- Final verification
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables 
                 WHERE table_name = 'organization_branches' AND table_schema = 'public')
    THEN 'ERROR: organization_branches table still exists!'
    ELSE 'SUCCESS: Cleanup completed - organization_branches table removed'
  END AS final_status;

SELECT 'Migration complete: Organizations now use branch as a string field' AS summary;
