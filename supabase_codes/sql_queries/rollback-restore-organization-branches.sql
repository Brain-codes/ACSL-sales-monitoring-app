-- ROLLBACK Script: Restore organization_branches table structure
-- Use this script ONLY if you need to rollback the migration
-- Date: October 1, 2025
-- Purpose: Emergency rollback to separate branch table structure

-- WARNING: This script will:
-- 1. Recreate the organization_branches table
-- 2. Migrate data back from organizations.branch to organization_branches
-- 3. Remove the new columns from organizations table
-- Only use this if the migration failed or you need to revert changes

DO $$
BEGIN
  RAISE NOTICE '=== STARTING ROLLBACK PROCESS ===';
  RAISE NOTICE 'This will restore the old organization_branches table structure';
  RAISE WARNING 'Make sure you really want to do this - this will undo all migration changes';
END
$$;

-- Step 1: Recreate organization_branches table
CREATE TABLE IF NOT EXISTS public.organization_branches (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  name TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'Nigeria',
  state TEXT NULL,
  lga TEXT NULL,
  created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
  created_by UUID NOT NULL,
  
  CONSTRAINT organization_branches_pkey PRIMARY KEY (id),
  CONSTRAINT organization_branches_organization_id_fkey 
    FOREIGN KEY (organization_id) 
    REFERENCES public.organizations(id) 
    ON DELETE CASCADE,
  CONSTRAINT organization_branches_created_by_fkey 
    FOREIGN KEY (created_by) 
    REFERENCES auth.users(id) 
    ON DELETE RESTRICT,
  CONSTRAINT organization_branches_name_org_unique 
    UNIQUE (organization_id, name)
);

-- Step 2: Recreate indexes
CREATE INDEX IF NOT EXISTS idx_organization_branches_org_id ON public.organization_branches(organization_id);
CREATE INDEX IF NOT EXISTS idx_organization_branches_country ON public.organization_branches(country);
CREATE INDEX IF NOT EXISTS idx_organization_branches_state ON public.organization_branches(state);
CREATE INDEX IF NOT EXISTS idx_organization_branches_created_at ON public.organization_branches(created_at);

-- Step 3: Recreate update trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_organization_branches_updated_at 
    BEFORE UPDATE ON public.organization_branches 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 4: Enable RLS and recreate policies
ALTER TABLE public.organization_branches ENABLE ROW LEVEL SECURITY;

-- Super admin can do everything
CREATE POLICY "Super admin full access" ON public.organization_branches
  FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role = 'super_admin'
    )
  );

-- Organization admins can manage their organization's branches
CREATE POLICY "Organization admin access" ON public.organization_branches
  FOR ALL 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.organizations o ON p.organization_id = o.id
      WHERE p.id = auth.uid() 
      AND p.role = 'admin'
      AND o.id = organization_branches.organization_id
    )
  );

-- Agents can read their organization's branches
CREATE POLICY "Agent read access" ON public.organization_branches
  FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.organizations o ON p.organization_id = o.id
      WHERE p.id = auth.uid() 
      AND p.role = 'agent'
      AND o.id = organization_branches.organization_id
    )
  );

-- Step 5: Migrate data back from organizations.branch to organization_branches
DO $$
DECLARE
  org_record RECORD;
  branch_names TEXT[];
  branch_name TEXT;
  migrated_count INTEGER := 0;
  created_by_user UUID;
BEGIN
  RAISE NOTICE 'Migrating data back from organizations.branch to organization_branches...';
  
  -- Get a default created_by user (first super admin or first user)
  SELECT id INTO created_by_user 
  FROM public.profiles 
  WHERE role = 'super_admin' 
  LIMIT 1;
  
  IF created_by_user IS NULL THEN
    SELECT id INTO created_by_user 
    FROM auth.users 
    LIMIT 1;
  END IF;
  
  IF created_by_user IS NULL THEN
    RAISE ERROR 'No users found to set as created_by for branches';
  END IF;
  
  FOR org_record IN
    SELECT id, name, branch, state, country
    FROM public.organizations
    WHERE branch IS NOT NULL AND branch != ''
  LOOP
    -- Split branch names by ' | ' separator (in case multiple branches were combined)
    branch_names := string_to_array(org_record.branch, ' | ');
    
    FOREACH branch_name IN ARRAY branch_names
    LOOP
      INSERT INTO public.organization_branches (
        organization_id,
        name,
        country,
        state,
        lga,
        created_by
      ) VALUES (
        org_record.id,
        trim(branch_name),
        COALESCE(org_record.country, 'Nigeria'),
        org_record.state,
        NULL, -- lga not available in organizations table
        created_by_user
      )
      ON CONFLICT (organization_id, name) DO NOTHING; -- Skip duplicates
      
      migrated_count := migrated_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Migrated branches for organization: %', org_record.name;
  END LOOP;
  
  RAISE NOTICE 'Successfully migrated % branch records back to organization_branches', migrated_count;
END
$$;

-- Step 6: Remove the new columns from organizations table
DO $$
BEGIN
  RAISE NOTICE 'Removing new columns from organizations table...';
  
  ALTER TABLE public.organizations DROP COLUMN IF EXISTS branch;
  ALTER TABLE public.organizations DROP COLUMN IF EXISTS contact_person;
  ALTER TABLE public.organizations DROP COLUMN IF EXISTS alternative_phone;
  
  -- Note: We keep contact_phone and state as they might have been useful additions
  -- Uncomment the lines below if you want to remove them too:
  -- ALTER TABLE public.organizations DROP COLUMN IF EXISTS contact_phone;
  -- ALTER TABLE public.organizations DROP COLUMN IF EXISTS state;
  
  RAISE NOTICE 'Removed branch-related columns from organizations table';
END
$$;

-- Step 7: Drop indexes that were added during migration
DROP INDEX IF EXISTS public.idx_organizations_branch;

-- Step 8: Add table comments
COMMENT ON TABLE public.organization_branches IS 'Stores branch information for organizations. Each organization can have multiple branches in different locations.';
COMMENT ON COLUMN public.organization_branches.id IS 'Primary key for the branch';
COMMENT ON COLUMN public.organization_branches.organization_id IS 'Foreign key to organizations table';
COMMENT ON COLUMN public.organization_branches.name IS 'Name of the branch (must be unique within organization)';
COMMENT ON COLUMN public.organization_branches.country IS 'Country where the branch is located (default: Nigeria)';
COMMENT ON COLUMN public.organization_branches.state IS 'State where the branch is located';
COMMENT ON COLUMN public.organization_branches.lga IS 'Local Government Area where the branch is located';
COMMENT ON COLUMN public.organization_branches.created_at IS 'Timestamp when the branch was created';
COMMENT ON COLUMN public.organization_branches.updated_at IS 'Timestamp when the branch was last updated';
COMMENT ON COLUMN public.organization_branches.created_by IS 'User who created the branch';

-- Step 9: Final verification
DO $$
DECLARE
  branch_count INTEGER := 0;
  org_count INTEGER := 0;
BEGIN
  SELECT COUNT(*) INTO branch_count FROM public.organization_branches;
  SELECT COUNT(*) INTO org_count FROM public.organizations;
  
  RAISE NOTICE '=== ROLLBACK COMPLETED ===';
  RAISE NOTICE 'organization_branches table restored with % records', branch_count;
  RAISE NOTICE 'organizations table has % records', org_count;
  RAISE NOTICE '';
  RAISE NOTICE 'The system has been rolled back to use separate branch table structure';
  RAISE NOTICE 'You will need to restore your manage-branches edge function code manually';
  RAISE NOTICE 'Remember to update your application code to use the old structure';
END
$$;
