-- Cleanup: Drop organization_branches table and related objects
-- This script should be run AFTER the migration script and AFTER verifying data migration was successful
-- Date: October 1, 2025
-- Purpose: Clean up old branch table structure

-- WARNING: This script will permanently delete the organization_branches table and all its data
-- Make sure you have:
-- 1. Run the migration script successfully
-- 2. Verified that all data has been migrated to organizations.branch
-- 3. Updated all application code to use the new structure
-- 4. Tested the application thoroughly

DO $$
BEGIN
  RAISE NOTICE '=== STARTING CLEANUP PROCESS ===';
  RAISE NOTICE 'This will permanently delete organization_branches table and related objects';
END
$$;

-- Step 1: Check if organization_branches table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables 
             WHERE table_name = 'organization_branches' AND table_schema = 'public') THEN
    RAISE NOTICE 'Found organization_branches table, proceeding with cleanup...';
  ELSE
    RAISE NOTICE 'organization_branches table not found, cleanup not needed';
    RETURN;
  END IF;
END
$$;

-- Step 2: Display current data count for confirmation
DO $$
DECLARE
  branch_count INTEGER := 0;
  org_with_branches INTEGER := 0;
BEGIN
  -- Count branches
  SELECT COUNT(*) INTO branch_count FROM public.organization_branches;
  
  -- Count organizations with branches
  SELECT COUNT(DISTINCT organization_id) INTO org_with_branches 
  FROM public.organization_branches;
  
  RAISE NOTICE 'Current organization_branches table contains:';
  RAISE NOTICE '- % branch records', branch_count;
  RAISE NOTICE '- % organizations with branches', org_with_branches;
  RAISE NOTICE '';
END
$$;

-- Step 3: Verify migration was successful
DO $$
DECLARE
  orgs_with_branch_data INTEGER := 0;
  orgs_without_branch_data INTEGER := 0;
BEGIN
  -- Count organizations with branch data
  SELECT COUNT(*) INTO orgs_with_branch_data 
  FROM public.organizations 
  WHERE branch IS NOT NULL AND branch != '';
  
  -- Count organizations without branch data
  SELECT COUNT(*) INTO orgs_without_branch_data 
  FROM public.organizations 
  WHERE branch IS NULL OR branch = '';
  
  RAISE NOTICE 'Migration verification:';
  RAISE NOTICE '- % organizations have branch data', orgs_with_branch_data;
  RAISE NOTICE '- % organizations missing branch data', orgs_without_branch_data;
  
  IF orgs_without_branch_data > 0 THEN
    RAISE WARNING 'Some organizations are missing branch data! Review before proceeding.';
  END IF;
END
$$;

-- Step 4: Remove foreign key constraints that reference organization_branches
DO $$
DECLARE
  constraint_record RECORD;
BEGIN
  RAISE NOTICE 'Checking for foreign key constraints referencing organization_branches...';
  
  -- Find all foreign key constraints that reference organization_branches
  FOR constraint_record IN
    SELECT 
      tc.constraint_name,
      tc.table_name,
      kcu.column_name,
      ccu.table_name AS foreign_table_name,
      ccu.column_name AS foreign_column_name
    FROM information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND ccu.table_name = 'organization_branches'
  LOOP
    RAISE NOTICE 'Dropping foreign key constraint: %.% references organization_branches.%',
      constraint_record.table_name, 
      constraint_record.column_name,
      constraint_record.foreign_column_name;
    
    EXECUTE format('ALTER TABLE %I DROP CONSTRAINT IF EXISTS %I',
      constraint_record.table_name,
      constraint_record.constraint_name);
  END LOOP;
END
$$;

-- Step 5: Drop RLS policies on organization_branches
DO $$
BEGIN
  RAISE NOTICE 'Dropping RLS policies on organization_branches table...';
  
  DROP POLICY IF EXISTS "Super admin full access" ON public.organization_branches;
  DROP POLICY IF EXISTS "Organization admin access" ON public.organization_branches;
  DROP POLICY IF EXISTS "Agent read access" ON public.organization_branches;
  
  RAISE NOTICE 'RLS policies dropped successfully';
END
$$;

-- Step 6: Drop triggers on organization_branches
DO $$
BEGIN
  RAISE NOTICE 'Dropping triggers on organization_branches table...';
  
  DROP TRIGGER IF EXISTS update_organization_branches_updated_at ON public.organization_branches;
  
  RAISE NOTICE 'Triggers dropped successfully';
END
$$;

-- Step 7: Drop indexes on organization_branches
DO $$
BEGIN
  RAISE NOTICE 'Dropping indexes on organization_branches table...';
  
  DROP INDEX IF EXISTS public.idx_organization_branches_org_id;
  DROP INDEX IF EXISTS public.idx_organization_branches_country;
  DROP INDEX IF EXISTS public.idx_organization_branches_state;
  DROP INDEX IF EXISTS public.idx_organization_branches_created_at;
  
  RAISE NOTICE 'Indexes dropped successfully';
END
$$;

-- Step 8: Drop the organization_branches table
DO $$
BEGIN
  RAISE NOTICE 'Dropping organization_branches table...';
  
  DROP TABLE IF EXISTS public.organization_branches CASCADE;
  
  RAISE NOTICE 'organization_branches table dropped successfully';
END
$$;

-- Step 9: Drop the update trigger function if it's no longer used
DO $$
BEGIN
  -- Check if the function is used by any other tables
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers 
    WHERE trigger_name LIKE '%updated_at%' 
    AND event_object_table != 'organization_branches'
  ) THEN
    RAISE NOTICE 'Dropping update_updated_at_column function (no longer used)...';
    DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;
    RAISE NOTICE 'Function dropped successfully';
  ELSE
    RAISE NOTICE 'Keeping update_updated_at_column function (still used by other tables)';
  END IF;
END
$$;

-- Step 10: Final verification
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables 
             WHERE table_name = 'organization_branches' AND table_schema = 'public') THEN
    RAISE ERROR 'organization_branches table still exists! Cleanup failed.';
  ELSE
    RAISE NOTICE '=== CLEANUP COMPLETED SUCCESSFULLY ===';
    RAISE NOTICE 'organization_branches table and all related objects have been removed';
    RAISE NOTICE '';
    RAISE NOTICE 'Migration summary:';
    RAISE NOTICE '✅ organization_branches table dropped';
    RAISE NOTICE '✅ Foreign key constraints removed';
    RAISE NOTICE '✅ RLS policies dropped';
    RAISE NOTICE '✅ Triggers dropped';
    RAISE NOTICE '✅ Indexes dropped';
    RAISE NOTICE '';
    RAISE NOTICE 'Organizations now use branch as a string field';
    RAISE NOTICE 'Update your application code to use organizations.branch instead of organization_branches table';
  END IF;
END
$$;
